import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../storage/local_storage.dart';

class AutoBackupEntry {
  final String key;
  final String dateStr;
  final DateTime timestamp;
  final int watchedCount;
  final int watchlistCount;
  final String username;

  AutoBackupEntry({
    required this.key,
    required this.dateStr,
    required this.timestamp,
    required this.watchedCount,
    required this.watchlistCount,
    required this.username,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'dateStr': dateStr,
        'timestamp': timestamp.toIso8601String(),
        'watchedCount': watchedCount,
        'watchlistCount': watchlistCount,
        'username': username,
      };

  factory AutoBackupEntry.fromJson(Map<String, dynamic> json) => AutoBackupEntry(
        key: json['key'] ?? '',
        dateStr: json['dateStr'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        watchedCount: json['watchedCount'] ?? 0,
        watchlistCount: json['watchlistCount'] ?? 0,
        username: json['username'] ?? 'Cinefilo',
      );
}

class BackupService {
  static const String _indexKey = 'auto_backup_index';
  static const int maxRetentionDays = 7;

  /// Esegue un auto-backup intelligente se ci sono dati e mantiene una rotazione a 7 giorni
  static Future<bool> performAutoBackupIfNeeded() async {
    try {
      final cachedMovies = LocalStorageService.getCachedMovies();
      // Non effettua backup se l'app è completamente vuota
      if (cachedMovies.isEmpty) return false;

      final now = DateTime.now();
      final dayKey =
          'auto_backup_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';

      final box = LocalStorageService.backupBox;
      final existingToday = box.get(dayKey);

      // Se oggi è già presente un backup recente (meno di 12 ore fa), possiamo saltare o aggiornarlo
      if (existingToday != null) {
        final existingData = jsonDecode(existingToday as String);
        final existingTime = DateTime.tryParse(existingData['created_at'] ?? '');
        if (existingTime != null && now.difference(existingTime).inHours < 8) {
          return false;
        }
      }

      final backupData = LocalStorageService.exportAllDataToJson(backupType: 'auto');
      final backupJson = jsonEncode(backupData);
      await box.put(dayKey, backupJson);

      final watchlist = LocalStorageService.getLocalWatchlistMovies();
      final username = LocalStorageService.getActiveUsername() ?? 'Cinefilo';

      // Aggiorna l'indice dei backup
      List<AutoBackupEntry> index = getAvailableAutoBackups();
      index.removeWhere((e) => e.key == dayKey);
      index.insert(
        0,
        AutoBackupEntry(
          key: dayKey,
          dateStr: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
          timestamp: now,
          watchedCount: cachedMovies.length,
          watchlistCount: watchlist.length,
          username: username,
        ),
      );

      // Ordina dal più recente al più vecchio
      index.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // ROTAZIONE ROTATIVA A 7 GIORNI: elimina i backup più vecchi di 7 giorni
      if (index.length > maxRetentionDays) {
        final toRemove = index.sublist(maxRetentionDays);
        for (final old in toRemove) {
          await box.delete(old.key);
        }
        index = index.sublist(0, maxRetentionDays);
      }

      await box.put(_indexKey, jsonEncode(index.map((e) => e.toJson()).toList()));
      debugPrint('Auto-backup completato con successo: $dayKey (Conservati ${index.length}/$maxRetentionDays)');
      return true;
    } catch (e) {
      debugPrint('Errore durante performAutoBackupIfNeeded: $e');
      return false;
    }
  }

  /// Restituisce la lista degli auto-backup disponibili (fino a 7 giorni)
  static List<AutoBackupEntry> getAvailableAutoBackups() {
    try {
      final box = LocalStorageService.backupBox;
      final raw = box.get(_indexKey);
      if (raw != null && raw is String) {
        final list = jsonDecode(raw) as List;
        return list
            .map((item) => AutoBackupEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('Errore lettura indice auto-backup: $e');
    }
    return [];
  }

  /// Restituisce i dati JSON dell'ultimo auto-backup disponibile
  static Map<String, dynamic>? getLatestAutoBackupData() {
    final list = getAvailableAutoBackups();
    if (list.isEmpty) return null;
    final box = LocalStorageService.backupBox;
    final raw = box.get(list.first.key);
    if (raw != null && raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return null;
  }

  /// Ripristina l'ultimo auto-backup
  static Future<bool> restoreLatestAutoBackup() async {
    final data = getLatestAutoBackupData();
    if (data == null) return false;
    return await LocalStorageService.restoreAllDataFromJson(data);
  }

  /// Ripristina uno snapshot specifico dato il suo key
  static Future<bool> restoreAutoBackupByKey(String key) async {
    try {
      final box = LocalStorageService.backupBox;
      final raw = box.get(key);
      if (raw != null && raw is String) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return await LocalStorageService.restoreAllDataFromJson(data);
      }
    } catch (e) {
      debugPrint('Errore ripristino snapshot $key: $e');
    }
    return false;
  }

  /// Genera un file JSON esportabile e apre il menu di condivisione del dispositivo
  static Future<bool> exportManualBackup() async {
    try {
      final data = LocalStorageService.exportAllDataToJson(backupType: 'manual');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename =
          'cinepulse_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(jsonStr);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Backup CinePulse',
      );
      return true;
    } catch (e) {
      debugPrint('Errore esportazione backup manuale: $e');
      return false;
    }
  }

  /// Apre il file picker per selezionare un file di backup JSON manuale e ne legge i dati
  static Future<Map<String, dynamic>?> pickBackupFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) return null;

      final file = files.first;
      String jsonString;
      if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        jsonString = await file.xFile.readAsString();
      }

      if (jsonString.trim().isEmpty) return null;

      final parsed = jsonDecode(jsonString);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('watched_movies') || parsed.containsKey('taste_profile')) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('Errore selezione/lettura file di backup: $e');
    }
    return null;
  }
}
