import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/letterboxd_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../movie_detail/screens/movie_detail_sheet.dart';
import '../../onboarding/screens/sync_profile_screen.dart';

class TasteProfileScreen extends ConsumerWidget {
  const TasteProfileScreen({super.key});

  Future<void> _handleFileImport(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'csv'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final fileName = file.name.toLowerCase();
      final isZip = fileName.endsWith('.zip');

      HapticFeedback.lightImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isZip
                  ? 'Decompressione archivio .ZIP Letterboxd in corso...'
                  : 'Lettura file CSV Letterboxd in corso...',
            ),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final letterboxdService = ref.read(letterboxdServiceProvider);
      final recommendationEngine = ref.read(recommendationEngineProvider);

      List<LetterboxdMovie> movies = [];
      if (isZip) {
        List<int> bytes;
        if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          bytes = await file.xFile.readAsBytes();
        }
        movies = letterboxdService.parseLetterboxdZip(bytes);
      } else {
        String? content;
        if (file.path != null) {
          content = await File(file.path!).readAsString();
        } else {
          content = await file.xFile.readAsString();
        }
        if (content.isNotEmpty) {
          movies = letterboxdService.parseLetterboxdCsv(content);
        }
      }

      if (movies.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nessun film riconosciuto nel file. Seleziona lo .zip scaricato da Letterboxd o un CSV valido (ratings.csv / watched.csv).',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      String username = ref.read(activeUserProvider) ?? '';
      if ((username.isEmpty || username == 'Ospite') && fileName.contains('letterboxd-')) {
        final parts = fileName.split('-');
        if (parts.length >= 2) username = parts[1];
      }
      if (username.isEmpty || username == 'Ospite') username = 'LetterboxdUser';

      await LocalStorageService.setActiveUsername(username);
      await LocalStorageService.saveLetterboxdMovies(movies);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analisi profonda dei gusti su ${movies.length} film di @$username in corso...'),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final profile = await recommendationEngine.buildTasteProfile(username, movies);

      ref.read(activeUserProvider.notifier).setUsername(username);
      ref.read(userLetterboxdMoviesProvider.notifier).setMovies(movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);
      ref.read(recommendationsProvider.notifier).loadRecommendations(forceRefresh: true);

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Importati con successo ${movies.length} film di @$username!'),
            backgroundColor: AppColors.primaryOrange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore importazione: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRecalculateTaste(BuildContext context, WidgetRef ref) async {
    final movies = ref.read(userLetterboxdMoviesProvider);
    if (movies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun film sincronizzato. Importa prima il file .ZIP di Letterboxd!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ricalcolo profondo dell\'algoritmo su ${movies.length} film in corso...'),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 3),
      ),
    );

    final username = ref.read(activeUserProvider) ?? 'Cinefilo';
    final recommendationEngine = ref.read(recommendationEngineProvider);

    try {
      final newProfile = await recommendationEngine.buildTasteProfile(username, movies);
      ref.read(tasteProfileProvider.notifier).setProfile(newProfile);
      ref.read(recommendationsProvider.notifier).loadRecommendations(forceRefresh: true);

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Profilo gusti e raccomandazioni aggiornati con successo!'),
            backgroundColor: AppColors.primaryOrange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore ricalcolo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openSubscriptionsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String countryCode,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionsModalSheet(countryCode: countryCode),
    );
  }

  void _openWatchedHistory(
    BuildContext context,
    List<LetterboxdMovie> userMovies,
    String countryCode,
  ) {
    HapticFeedback.lightImpact();
    final watchedList = userMovies.where((m) => !m.isInWatchlist).toList();
    watchedList.sort((a, b) {
      if (a.watchedDate != null && b.watchedDate != null) {
        return b.watchedDate!.compareTo(a.watchedDate!);
      }
      if (a.watchedDate != null) return -1;
      if (b.watchedDate != null) return 1;
      final ya = a.year ?? 0;
      final yb = b.year ?? 0;
      return yb.compareTo(ya);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WatchedHistorySheet(
        movies: watchedList,
        countryCode: countryCode,
      ),
    );
  }

  Future<void> _applyRestoredData(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) async {
    final success = await LocalStorageService.restoreAllDataFromJson(data);
    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: formato backup non valido o non supportato.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final username = LocalStorageService.getActiveUsername() ?? 'Cinefilo';
    final movies = LocalStorageService.getCachedMovies();
    final profile = LocalStorageService.getTasteProfile();
    final country = LocalStorageService.getSelectedCountry();
    final providers = LocalStorageService.getSelectedStreamingProviders();

    ref.read(activeUserProvider.notifier).setUsername(username);
    ref.read(userLetterboxdMoviesProvider.notifier).setMovies(movies);
    ref.read(tasteProfileProvider.notifier).setProfile(profile);
    ref.read(selectedCountryProvider.notifier).setCountry(country);
    ref.read(activeProvidersFilterProvider.notifier).setProviders(providers);
    ref.invalidate(watchlistProvider);
    ref.read(recommendationsProvider.notifier).loadRecommendations(forceRefresh: true);

    if (context.mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Backup ripristinato con successo! (${movies.length} film)'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );
    }
  }

  void _showBackupManagementSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BackupManagementSheet(
        onRestoreData: (data) => _applyRestoredData(context, ref, data),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasteProfile = ref.watch(tasteProfileProvider);
    final userMovies = ref.watch(userLetterboxdMoviesProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final activeFilters = ref.watch(activeProvidersFilterProvider);
    final username = ref.watch(activeUserProvider) ?? 'Cinefilo';
    final bottomInset = MediaQuery.of(context).padding.bottom + 110;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          username == 'Ospite' ? 'Profilo Ospite' : '@$username',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.electricCyan),
            tooltip: 'Backup & Ripristino Dati (7 giorni)',
            onPressed: () => _showBackupManagementSheet(context, ref),
          ),
          if (tasteProfile != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primaryOrange),
              tooltip: 'Ricalcola gusti e raccomandazioni',
              onPressed: () => _handleRecalculateTaste(context, ref),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SE NON HA ANCORA COLLEGATO LETTERBOXD (GUEST MODE)
            if (tasteProfile == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.primaryOrange.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primaryOrange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Collega il tuo Letterboxd',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Stai usando CinePulse in modalità ospite. Importa il tuo file .zip esportato da Letterboxd per visualizzare le tue statistiche e sbloccare le raccomandazioni su misura per te!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.folder_zip_rounded, size: 20),
                        label: const Text(
                          'Importa archivio .ZIP Letterboxd',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        onPressed: () => _handleFileImport(context, ref),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SyncProfileScreen()),
                          );
                        },
                        child: const Text(
                          'Oppure sincronizza tramite username',
                          style: TextStyle(color: AppColors.amberFlame, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
            ] else ...[
              // BENTO GRID STATS OVERVIEW
              Row(
                children: [
                  Expanded(
                    child: _BentoStatCard(
                      title: 'FILM VISTI',
                      value: '${tasteProfile.totalWatched}',
                      icon: Icons.movie_filter_rounded,
                      accentColor: AppColors.primaryOrange,
                      subtitle: 'Tocca per cronologia',
                      onTap: () => _openWatchedHistory(context, userMovies, selectedCountry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BentoStatCard(
                      title: 'VOTATI',
                      value: '${tasteProfile.totalRated}',
                      icon: Icons.star_half_rounded,
                      accentColor: AppColors.amberFlame,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BentoStatCard(
                      title: 'MEDIA VOTO',
                      value: tasteProfile.averageRating > 0
                          ? '★ ${tasteProfile.averageRating}'
                          : 'N/A',
                      icon: Icons.auto_awesome,
                      accentColor: AppColors.electricCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BentoStatCard(
                      title: 'IN WATCHLIST',
                      value: '${tasteProfile.totalInWatchlist}',
                      icon: Icons.bookmark_added_rounded,
                      accentColor: AppColors.velvetPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tasti Azione Rapida: Ricalcola Gusti & Reimporta ZIP
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.8), width: 1.4),
                        backgroundColor: AppColors.primaryOrange.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 18),
                      label: const Text(
                        'Ricalcola gusti',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _handleRecalculateTaste(context, ref),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.folder_zip_outlined, color: AppColors.textSecondary, size: 18),
                      label: const Text(
                        'Reimporta .ZIP',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _handleFileImport(context, ref),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
            ],

            // SELEZIONE NAZIONE STREAMING
            const _Header(
              title: 'Nazione Streaming (JustWatch)',
              subtitle: 'I provider e i prezzi mostrati si adatteranno a questo paese',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCountry,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryOrange),
                  items: AppConfig.supportedCountries.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          Text(
                            entry.key == 'IT'
                                ? '🇮🇹 '
                                : entry.key == 'US'
                                    ? '🇺🇸 '
                                    : entry.key == 'GB'
                                        ? '🇬🇧 '
                                        : '🌍 ',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      LocalStorageService.setSelectedCountry(val);
                      ref.read(selectedCountryProvider.notifier).setCountry(val);
                      ref.invalidate(countryProvidersListProvider);
                      ref.invalidate(nowPlayingMoviesProvider);
                      ref.invalidate(topRatedMoviesProvider);
                      ref.read(recommendationsProvider.notifier).loadRecommendations();
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // POPUP MODALE: I TUOI ABBONAMENTI STREAMING
            _SubscriptionsLauncherCard(
              countryCode: selectedCountry,
              activeFilters: activeFilters,
              onTap: () => _openSubscriptionsBottomSheet(context, ref, selectedCountry),
            ),

            if (tasteProfile != null) ...[
              const SizedBox(height: 30),

              // GUSTO CINEMATOGRAFICO (BARRE % GENERI)
              const _Header(
                title: 'Gusto Cinematografico',
                subtitle: 'Distribuzione statistica pesata dei generi che ami di più',
              ),
              const SizedBox(height: 14),

              ...(tasteProfile.genrePercentages.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(6)
                  .map((entry) {
                  final pct = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (pct / 100.0).clamp(0.05, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryOrange,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 30),

              // COMBINAZIONI MULTI-GENERE
              if (tasteProfile.topMultiGenres.isNotEmpty) ...[
                const _Header(
                  title: 'Combinazioni Multi-Genere',
                  subtitle: 'Gli incroci di generi che apprezzi di più nei film',
                ),
                const SizedBox(height: 12),
                ...tasteProfile.topMultiGenres.map((multi) {
                  final pct = tasteProfile.multiGenrePercentages[multi] ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              multi,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                            if (pct > 0)
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.electricCyan,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (pct / 100.0).clamp(0.05, 1.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.electricCyan,
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 28),
              ],

              // SOTTOGENERI & MICRO-TEMI
              if (tasteProfile.topSubgenres.isNotEmpty) ...[
                const _Header(
                  title: 'Sottogeneri & Temi Ricorrenti',
                  subtitle: 'Tendenze e micro-filoni rilevati dai tuoi film preferiti',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tasteProfile.topSubgenres.map((sub) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.velvetPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.velvetPurple.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.style_rounded, size: 14, color: AppColors.velvetPurple),
                          const SizedBox(width: 6),
                          Text(
                            sub,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
              ],

              // CLASSIFICA REGISTI RICORRENTI (Ordinata per numero di film visti)
              if (tasteProfile.topDirectors.isNotEmpty) ...[
                const _Header(
                  title: 'Classifica Registi Ricorrenti',
                  subtitle: 'Ordinati dal regista di cui hai visto più film (almeno 2)',
                ),
                const SizedBox(height: 14),
                ...tasteProfile.topDirectors.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final director = entry.value;
                  final count = tasteProfile.directorFilmCounts[director];
                  final isTop3 = rank <= 3;
                  final rankColor = rank == 1
                      ? const Color(0xFFFFD700)
                      : rank == 2
                          ? const Color(0xFFC0C0C0)
                          : rank == 3
                              ? const Color(0xFFCD7F32)
                              : Colors.white38;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTop3
                            ? rankColor.withValues(alpha: 0.4)
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                color: rankColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            director,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (count != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count film',
                              style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 30),
              ],

              // SCHEDA GESTIONE BACKUP & AUTO-BACKUP (7 GIORNI)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.electricCyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.electricCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.cloud_sync_rounded,
                            color: AppColors.electricCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Backup & Ripristino Dati',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '7gg auto',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Auto-backup giornaliero attivo: i tuoi dati vengono protetti e conservati per 7 giorni. Puoi ripristinare uno snapshot o esportare un backup manuale JSON.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.electricCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                        label: const Text(
                          'Gestisci Backup & Ripristino',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: () => _showBackupManagementSheet(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],

            // DISCLAIMER DI CONFORMITÀ LEGALE E ATTRIBUZIONI TMDb / LETTERBOXD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Note Legali & Attribuzioni',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Questo prodotto utilizza le API di TMDb ma non è approvato o certificato da TMDb.\n'
                    '• I dati di streaming sono aggregati tramite JustWatch / TMDb.\n'
                    '• CinePulse è un\'applicazione autonoma indipendente, non affiliata, sponsorizzata o approvata da Letterboxd Limited.\n'
                    '• Tutti i marchi, loghi e locandine appartengono ai rispettivi legittimi proprietari.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // DISCONNETTI ACCOUNT O CAMBIA USERNAME
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                label: Text(
                  username == 'Ospite' ? 'Torna alla schermata di sincronizzazione' : 'Cambia account Letterboxd',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceElevated,
                      title: const Text('Disconnetti profilo?'),
                      content: const Text(
                        'Vuoi rimuovere i dati memorizzati e cambiare account o sincronizzazione?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Annulla'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Disconnetti',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await LocalStorageService.clearUser();
                    ref.read(activeUserProvider.notifier).setUsername(null);
                    ref.read(tasteProfileProvider.notifier).setProfile(null);
                    ref.read(userLetterboxdMoviesProvider.notifier).setMovies([]);
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SyncProfileScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Card compatta che lancia la schermata/popup degli abbonamenti
class _SubscriptionsLauncherCard extends StatelessWidget {
  final String countryCode;
  final List<String> activeFilters;
  final VoidCallback onTap;

  const _SubscriptionsLauncherCard({
    required this.countryCode,
    required this.activeFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFilters = activeFilters.isNotEmpty;
    final countryName = AppConfig.supportedCountries[countryCode] ?? countryCode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFilters ? AppColors.primaryOrange.withOpacity(0.6) : AppColors.borderSubtle,
            width: hasFilters ? 1.5 : 1.0,
          ),
          boxShadow: hasFilters
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.subscriptions_rounded, color: AppColors.primaryOrange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'I Tuoi Abbonamenti Streaming',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasFilters
                            ? '${activeFilters.length} piattaforme attive in $countryName'
                            : 'Nessun filtro attivo • Mostra tutti i film',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasFilters ? AppColors.primaryOrange : AppColors.textSecondary,
                          fontWeight: hasFilters ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFilters ? AppColors.primaryOrange : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasFilters ? 'Modifica' : 'Seleziona',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasFilters ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: hasFilters ? Colors.black : Colors.white70,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activeFilters.take(5).map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal BottomSheet per gestire gli abbonamenti streaming in modo pulito e performante
class _SubscriptionsModalSheet extends ConsumerStatefulWidget {
  final String countryCode;

  const _SubscriptionsModalSheet({required this.countryCode});

  @override
  ConsumerState<_SubscriptionsModalSheet> createState() => _SubscriptionsModalSheetState();
}

class _SubscriptionsModalSheetState extends ConsumerState<_SubscriptionsModalSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = ref.watch(activeProvidersFilterProvider);
    final countryProvidersAsync = ref.watch(countryProvidersListProvider);
    final countryName = AppConfig.supportedCountries[widget.countryCode] ?? widget.countryCode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abbonamenti Streaming',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Piattaforme attive per $countryName',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (activeFilters.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      LocalStorageService.setSelectedStreamingProviders([]);
                      ref.read(activeProvidersFilterProvider.notifier).setProviders([]);
                      ref.read(recommendationsProvider.notifier).loadRecommendations();
                    },
                    child: const Text(
                      'Deseleziona tutti',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Barra di ricerca rapida
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Cerca piattaforma (es. Disney, RaiPlay, Prime...)',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryOrange, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryOrange),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Lista / Grid scrollabile dei provider
          Expanded(
            child: countryProvidersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              ),
              error: (_, __) => _buildProvidersGrid(
                AppConfig.getKnownProvidersForCountry(widget.countryCode),
                activeFilters,
              ),
              data: (providers) {
                final filtered = _searchQuery.isEmpty
                    ? providers
                    : providers.where((p) {
                        final name = (p['name'] ?? '').toLowerCase();
                        return name.contains(_searchQuery);
                      }).toList();

                return _buildProvidersGrid(filtered, activeFilters);
              },
            ),
          ),

          // Tasto Conferma sticky
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Text(
                  activeFilters.isEmpty
                      ? 'Mostra film su qualsiasi piattaforma'
                      : 'Applica filtri (${activeFilters.length} selezionate)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersGrid(
    List<Map<String, String>> providers,
    List<String> activeFilters,
  ) {
    if (providers.isEmpty) {
      return const Center(
        child: Text(
          'Nessuna piattaforma trovata.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final p = providers[index];
        final name = p['name'] ?? '';
        final logo = p['logo'] ?? '';
        final isSelected = activeFilters.any((f) => f.toLowerCase() == name.toLowerCase());

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              final updated = List<String>.from(activeFilters);
              if (isSelected) {
                updated.removeWhere((f) => f.toLowerCase() == name.toLowerCase());
              } else {
                updated.add(name);
              }
              LocalStorageService.setSelectedStreamingProviders(updated);
              ref.read(activeProvidersFilterProvider.notifier).setProviders(updated);
              ref.read(recommendationsProvider.notifier).loadRecommendations();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryOrange.withOpacity(0.14)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primaryOrange : AppColors.borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: logo,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 32, height: 32, color: Colors.white10),
                      errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 20, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primaryOrange,
                    checkColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      final updated = List<String>.from(activeFilters);
                      if (val == true) {
                        if (!isSelected) updated.add(name);
                      } else {
                        updated.removeWhere((f) => f.toLowerCase() == name.toLowerCase());
                      }
                      LocalStorageService.setSelectedStreamingProviders(updated);
                      ref.read(activeProvidersFilterProvider.notifier).setProviders(updated);
                      ref.read(recommendationsProvider.notifier).loadRecommendations();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? subtitle;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: onTap != null ? accentColor.withValues(alpha: 0.45) : AppColors.borderSubtle,
          ),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: accentColor),
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accentColor),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WatchedHistorySheet extends StatefulWidget {
  final List<LetterboxdMovie> movies;
  final String countryCode;

  const _WatchedHistorySheet({
    required this.movies,
    required this.countryCode,
  });

  @override
  State<_WatchedHistorySheet> createState() => _WatchedHistorySheetState();
}

class _WatchedHistorySheetState extends State<_WatchedHistorySheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatWatchedDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildPosterPlaceholder(String title) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.movies.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF14171C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.primaryOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cronologia Film Visti',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.movies.length} film visti in ordine decrescente',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Cerca tra i film visti...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryOrange, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryOrange),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.movie_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Nessun film trovato per "$_searchQuery"'
                                : 'Nessun film visto nella cronologia',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movie = filtered[index];
                      final dateStr = _formatWatchedDate(movie.watchedDate);

                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final tmdb = ProviderScope.containerOf(context).read(tmdbClientProvider);
                          final res = await tmdb.searchMovie(
                            movie.title,
                            year: movie.year,
                            slug: movie.slug,
                          );
                          if (res != null && context.mounted) {
                            final full = await tmdb.getMovieDetails(res.id, countryCode: widget.countryCode) ?? res;
                            if (context.mounted) {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierDismissible: true,
                                  pageBuilder: (context, _, __) => MovieDetailSheet(
                                    movie: full,
                                    countryCode: widget.countryCode,
                                    onWatchlistToggle: () {},
                                    onMarkAsWatched: () {},
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              // Locandina
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 50,
                                  height: 75,
                                  child: (movie.posterUrl != null && movie.posterUrl!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: movie.posterUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _buildPosterPlaceholder(movie.title),
                                        )
                                      : _buildPosterPlaceholder(movie.title),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      movie.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (movie.year != null) ...[
                                          Text(
                                            '${movie.year}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty)
                                            const Text(
                                              ' • ',
                                              style: TextStyle(color: Colors.white24, fontSize: 12),
                                            ),
                                        ],
                                        if (dateStr.isNotEmpty)
                                          Text(
                                            'Visto: $dateStr',
                                            style: const TextStyle(
                                              color: AppColors.primaryOrange,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (movie.rating != null && movie.rating! > 0) ...[
                                          const Icon(Icons.star_rounded, size: 14, color: AppColors.amberFlame),
                                          const SizedBox(width: 3),
                                          Text(
                                            movie.rating!.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        if (movie.isLiked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.favorite, size: 11, color: Colors.redAccent),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Preferito',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white30,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BackupManagementSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onRestoreData;

  const _BackupManagementSheet({required this.onRestoreData});

  @override
  State<_BackupManagementSheet> createState() => _BackupManagementSheetState();
}

class _BackupManagementSheetState extends State<_BackupManagementSheet> {
  List<AutoBackupEntry> _autoBackups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  void _loadBackups() {
    setState(() {
      _autoBackups = BackupService.getAvailableAutoBackups();
    });
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min';
  }

  Future<void> _confirmAndRestoreLatest() async {
    final latestData = BackupService.getLatestAutoBackupData();
    if (latestData == null || _autoBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun auto-backup disponibile al momento.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final latest = _autoBackups.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF191F28),
        title: const Text('Ripristinare ultimo backup?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Snapshot del ${_formatDateTime(latest.timestamp)}\n\n• Film visti: ${latest.watchedCount}\n• In Watchlist: ${latest.watchlistCount}\n• Utente: @${latest.username}\n\nI dati attuali verranno sostituiti con questo snapshot.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ripristina Ora'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(); // Chiude la bottom sheet
      await widget.onRestoreData(latestData);
    }
  }

  Future<void> _showHistoryDialog() async {
    if (_autoBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuno snapshot storico salvato finora.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.70,
          decoration: const BoxDecoration(
            color: Color(0xFF14171C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: AppColors.electricCyan, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Storico Auto-Backup (7 Giorni)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _autoBackups.length,
                  itemBuilder: (c, idx) {
                    final b = _autoBackups[idx];
                    final isLatest = idx == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isLatest ? AppColors.electricCyan.withValues(alpha: 0.4) : AppColors.borderSubtle),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLatest
                              ? AppColors.electricCyan.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          child: Icon(
                            isLatest ? Icons.star_rounded : Icons.backup_rounded,
                            color: isLatest ? AppColors.electricCyan : Colors.white60,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              b.dateStr,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            if (isLatest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.electricCyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Ultimo',
                                  style: TextStyle(color: AppColors.electricCyan, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${_formatDateTime(b.timestamp)} • ${b.watchedCount} film visti',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.restore_rounded, color: AppColors.primaryOrange, size: 22),
                        onTap: () async {
                          final box = LocalStorageService.backupBox;
                          final raw = box.get(b.key);
                          if (raw != null && raw is String) {
                            final data = jsonDecode(raw) as Map<String, dynamic>;
                            Navigator.of(ctx).pop();
                            Navigator.of(context).pop();
                            await widget.onRestoreData(data);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleExportManual() async {
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    final ok = await BackupService.exportManualBackup();
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📤 File di backup JSON generato con successo!'),
            backgroundColor: AppColors.primaryOrange,
          ),
        );
      }
    }
  }

  Future<void> _handleImportFile() async {
    setState(() => _isLoading = true);
    final data = await BackupService.pickBackupFile();
    setState(() => _isLoading = false);

    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun file selezionato o file JSON non compatibile.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final username = data['username'] ?? 'Cinefilo';
    final watched = (data['watched_movies'] as List?)?.length ?? 0;
    final watchlist = (data['watchlist_movies'] as List?)?.length ?? 0;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF191F28),
        title: const Text('Importare backup JSON?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Rilevato backup valido per @$username\n\n• Film visti: $watched\n• Film in watchlist: $watchlist\n\nVuoi ripristinare questo stato nell\'applicazione?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Conferma e Ripristina'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      await widget.onRestoreData(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hasBackups = _autoBackups.isNotEmpty;
    final latestBackup = hasBackups ? _autoBackups.first : null;

    return Container(
      height: screenHeight * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF14171C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.electricCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppColors.electricCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Backup & Ripristino Dati',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Auto-backup 7 giorni & file JSON manuale',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.divider),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CARD STATO AUTO-BACKUP
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surfaceElevated,
                          AppColors.electricCyan.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.electricCyan.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Auto-Backup Attivo (Rotazione 7 Giorni)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'CinePulse crea automaticamente uno snapshot giornaliero locale dei tuoi film visti, voti, watchlist, preferenze e apprendimento swipe. I backup vengono conservati per 7 giorni e poi sovrascritti.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ultimo salvataggio:',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    latestBackup != null
                                        ? _formatDateTime(latestBackup.timestamp)
                                        : 'Nessun backup recente',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.electricCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_autoBackups.length}/7 salvati',
                                  style: const TextStyle(
                                    color: AppColors.electricCyan,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // AZIONI RIPRISTINO AUTO-BACKUP
                  const Text(
                    'Ripristino Snapshot Automatico',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.restore_page_rounded, size: 18),
                          label: const Text('Ripristina Ultimo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          onPressed: hasBackups ? _confirmAndRestoreLatest : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderSubtle),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.electricCyan),
                          label: const Text('Storico 7 Giorni', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          onPressed: hasBackups ? _showHistoryDialog : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // AZIONI BACKUP MANUALE JSON
                  const Text(
                    'Backup Manuale File JSON',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Esporta un file .json sul tuo telefono o su Drive/WhatsApp per portarlo su un altro dispositivo o conservarlo per sempre.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryOrange.withValues(alpha: 0.6)),
                            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.08),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.primaryOrange),
                          label: const Text('Esporta JSON', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          onPressed: _isLoading ? null : _handleExportManual,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderSubtle),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.file_open_rounded, size: 18, color: AppColors.amberFlame),
                          label: const Text('Importa JSON', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          onPressed: _isLoading ? null : _handleImportFile,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

