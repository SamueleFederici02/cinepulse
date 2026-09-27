import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/letterboxd_movie.dart';
import '../models/taste_profile.dart';

class LocalStorageService {
  static const String _prefsKeyUsername = 'active_letterboxd_username';
  static const String _prefsKeyCountry = 'streaming_country_code';
  static const String _prefsKeyProviders = 'active_streaming_providers';

  static const String _boxMovies = 'letterboxd_movies_box';
  static const String _boxTaste = 'taste_profile_box';
  static const String _boxDismissed = 'dismissed_movie_ids_box';
  static const String _boxFavorites = 'local_favorites_box';

  static late Box _moviesBox;
  static late Box _tasteBox;
  static late Box _dismissedBox;
  static late Box _favoritesBox;
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    await Hive.initFlutter();
    _moviesBox = await Hive.openBox(_boxMovies);
    _tasteBox = await Hive.openBox(_boxTaste);
    _dismissedBox = await Hive.openBox(_boxDismissed);
    _favoritesBox = await Hive.openBox(_boxFavorites);
    _prefs = await SharedPreferences.getInstance();
  }

  // --- USERNAME ---
  static String? getActiveUsername() {
    return _prefs.getString(_prefsKeyUsername);
  }

  static Future<void> setActiveUsername(String username) async {
    await _prefs.setString(_prefsKeyUsername, username);
  }

  static Future<void> clearUser() async {
    await _prefs.remove(_prefsKeyUsername);
    await _moviesBox.clear();
    await _tasteBox.clear();
    await _dismissedBox.clear();
  }

  // --- STREAMING SETTINGS ---
  static String getSelectedCountry() {
    return _prefs.getString(_prefsKeyCountry) ?? 'IT';
  }

  static Future<void> setSelectedCountry(String countryCode) async {
    await _prefs.setString(_prefsKeyCountry, countryCode.toUpperCase());
  }

  static List<String> getSelectedStreamingProviders() {
    return _prefs.getStringList(_prefsKeyProviders) ?? [];
  }

  static Future<void> setSelectedStreamingProviders(List<String> providers) async {
    await _prefs.setStringList(_prefsKeyProviders, providers);
  }

  // --- MOVIES CACHE ---
  static Future<void> saveLetterboxdMovies(List<LetterboxdMovie> movies) async {
    await _moviesBox.clear();
    final Map<String, String> data = {};
    for (final m in movies) {
      data[m.slug] = jsonEncode(m.toJson());
    }
    await _moviesBox.putAll(data);
  }

  static List<LetterboxdMovie> getCachedMovies() {
    try {
      final List<LetterboxdMovie> list = [];
      for (final raw in _moviesBox.values) {
        if (raw is String) {
          list.add(LetterboxdMovie.fromJson(jsonDecode(raw)));
        }
      }
      return list;
    } catch (e) {
      debugPrint('Errore nel recupero film da Hive: $e');
      return [];
    }
  }

  // --- TASTE PROFILE ---
  static Future<void> saveTasteProfile(TasteProfile profile) async {
    await _tasteBox.put('current_profile', jsonEncode(profile.toJson()));
  }

  static TasteProfile? getTasteProfile() {
    try {
      final raw = _tasteBox.get('current_profile');
      if (raw != null && raw is String) {
        return TasteProfile.fromJson(jsonDecode(raw));
      }
      return null;
    } catch (e) {
      debugPrint('Errore nel recupero TasteProfile: $e');
      return null;
    }
  }

  // --- DISMISSED & FAVORITES ---
  static bool isMovieDismissed(int tmdbId) {
    return _dismissedBox.containsKey(tmdbId.toString());
  }

  static Future<void> dismissMovie(int tmdbId) async {
    await _dismissedBox.put(tmdbId.toString(), true);
  }

  static bool isMovieFavorited(int tmdbId) {
    return _favoritesBox.containsKey(tmdbId.toString());
  }

  static Future<void> toggleFavoriteMovie(int tmdbId) async {
    final key = tmdbId.toString();
    if (_favoritesBox.containsKey(key)) {
      await _favoritesBox.delete(key);
    } else {
      await _favoritesBox.put(key, true);
    }
  }
}
