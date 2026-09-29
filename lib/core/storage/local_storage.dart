import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/letterboxd_movie.dart';
import '../models/taste_profile.dart';
import '../models/tmdb_movie.dart';
import '../models/tv_series.dart';

class LocalStorageService {
  static const String _prefsKeyUsername = 'active_letterboxd_username';
  static const String _prefsKeyCountry = 'streaming_country_code';
  static const String _prefsKeyProviders = 'active_streaming_providers';

  static const String _boxMovies = 'letterboxd_movies_box';
  static const String _boxTaste = 'taste_profile_box';
  static const String _boxDismissed = 'dismissed_movie_ids_box';
  static const String _boxFavorites = 'local_favorites_box';
  static const String _boxPosters = 'movie_posters_box';
  static const String _boxSwipeLearning = 'swipe_learning_box';
  static const String _boxBackups = 'cinepulse_backups_box';
  static const String _boxTvSeries = 'tv_series_box';

  static late Box _moviesBox;
  static late Box _tasteBox;
  static late Box _dismissedBox;
  static late Box _favoritesBox;
  static late Box _posterBox;
  static late Box _swipeBox;
  static late Box _backupBox;
  static late Box _tvSeriesBox;
  static late SharedPreferences _prefs;

  static Box get backupBox => _backupBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _moviesBox = await Hive.openBox(_boxMovies);
    _tasteBox = await Hive.openBox(_boxTaste);
    _dismissedBox = await Hive.openBox(_boxDismissed);
    _favoritesBox = await Hive.openBox(_boxFavorites);
    _posterBox = await Hive.openBox(_boxPosters);
    _swipeBox = await Hive.openBox(_boxSwipeLearning);
    _backupBox = await Hive.openBox(_boxBackups);
    _tvSeriesBox = await Hive.openBox(_boxTvSeries);
    _prefs = await SharedPreferences.getInstance();

    // Pulizia automatica immediata di eventuali liste importate erroneamente
    await cleanInvalidCustomListEntries();
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

  static Future<void> addWatchedMovie(LetterboxdMovie movie) async {
    await _moviesBox.put(movie.slug, jsonEncode(movie.toJson()));
  }

  static bool _isCustomListSlug(String slug) {
    final s = slug.toLowerCase();
    return s.contains('/list/') ||
        s.contains('/lists/') ||
        s.startsWith('list-') ||
        s.contains('-list-') ||
        s == 'la-mia-infanzia' ||
        s == 'infanzia';
  }

  static Future<void> cleanInvalidCustomListEntries() async {
    try {
      final keysToRemove = <dynamic>[];
      for (final key in _moviesBox.keys) {
        final keyStr = key.toString();
        if (_isCustomListSlug(keyStr)) {
          keysToRemove.add(key);
          continue;
        }
        final val = _moviesBox.get(key);
        if (val is String && val.contains('{')) {
          try {
            final map = jsonDecode(val);
            final slug = (map['slug'] ?? '').toString().toLowerCase();
            final title = (map['title'] ?? '').toString().toLowerCase();
            if (_isCustomListSlug(slug) || title == 'la mia infanzia') {
              keysToRemove.add(key);
            }
          } catch (_) {}
        }
      }
      for (final k in keysToRemove) {
        await _moviesBox.delete(k);
      }
    } catch (e) {
      debugPrint('Errore durante la pulizia liste personalizzate: $e');
    }
  }

  static List<LetterboxdMovie> getCachedMovies() {
    try {
      final List<LetterboxdMovie> list = [];
      for (final raw in _moviesBox.values) {
        if (raw is String) {
          final m = LetterboxdMovie.fromJson(jsonDecode(raw));
          if (!_isCustomListSlug(m.slug) && m.title.toLowerCase() != 'la mia infanzia') {
            list.add(m);
          }
        }
      }
      return list;
    } catch (e) {
      debugPrint('Errore nel recupero film da Hive: $e');
      return [];
    }
  }

  // --- RECENTLY RECOMMENDED ROTATION (PER TE FRESCHI E VARI) ---
  static List<int> getRecentlyRecommendedMovieIds() {
    try {
      final raw = _tasteBox.get('recently_recommended_ids');
      if (raw != null && raw is String) {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => (e as num).toInt()).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveRecentlyRecommendedMovieIds(List<int> ids) async {
    try {
      final current = getRecentlyRecommendedMovieIds();
      final combined = [...ids, ...current].toSet().take(60).toList();
      await _tasteBox.put('recently_recommended_ids', jsonEncode(combined));
    } catch (_) {}
  }

  // --- TV SERIES QUEUE (STILE QUEUE APP) ---
  static Future<void> saveTvSeries(TvSeries series) async {
    await _tvSeriesBox.put(series.id.toString(), jsonEncode(series.toJson()));
  }

  static Future<void> removeTvSeries(int id) async {
    await _tvSeriesBox.delete(id.toString());
  }

  static TvSeries? getTvSeries(int id) {
    try {
      final raw = _tvSeriesBox.get(id.toString());
      if (raw != null && raw is String) {
        return TvSeries.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    return null;
  }

  static List<TvSeries> getTvSeriesList() {
    try {
      final List<TvSeries> list = [];
      for (final raw in _tvSeriesBox.values) {
        if (raw is String) {
          list.add(TvSeries.fromJson(jsonDecode(raw)));
        }
      }
      list.sort((a, b) {
        final dateA = a.lastWatchedAt ?? a.addedAt;
        final dateB = b.lastWatchedAt ?? b.addedAt;
        return dateB.compareTo(dateA);
      });
      return list;
    } catch (e) {
      debugPrint('Errore recupero serie TV da Hive: $e');
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

  static Set<int> getDismissedMovieIds() {
    try {
      return _dismissedBox.keys
          .map((k) => int.tryParse(k.toString()))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static bool isMovieFavorited(int tmdbId) {
    return _favoritesBox.containsKey(tmdbId.toString());
  }

  static Future<void> toggleFavoriteMovie(int tmdbId, [TmdbMovie? movie]) async {
    final key = tmdbId.toString();
    if (_favoritesBox.containsKey(key)) {
      await _favoritesBox.delete(key);
    } else {
      if (movie != null) {
        await _favoritesBox.put(key, jsonEncode(movie.toJson()));
      } else {
        await _favoritesBox.put(key, true);
      }
    }
  }

  static Future<void> saveWatchlistMovie(TmdbMovie movie) async {
    final key = movie.id.toString();
    final normTitle = movie.title.toLowerCase().trim();
    for (final existingKey in _favoritesBox.keys.toList()) {
      if (existingKey.toString() != key) {
        final val = _favoritesBox.get(existingKey);
        if (val is String && val.startsWith('{')) {
          try {
            final old = TmdbMovie.fromJson(jsonDecode(val));
            if (old.title.toLowerCase().trim() == normTitle) {
              await _favoritesBox.delete(existingKey);
            }
          } catch (_) {}
        }
      }
    }
    await _favoritesBox.put(key, jsonEncode(movie.toJson()));
  }

  static Future<void> removeWatchlistMovie(int tmdbId) async {
    await _favoritesBox.delete(tmdbId.toString());
  }

  static List<TmdbMovie> getLocalWatchlistMovies() {
    final List<TmdbMovie> list = [];
    final Set<String> seen = {};
    for (final val in _favoritesBox.values) {
      if (val is String && val.startsWith('{')) {
        try {
          final m = TmdbMovie.fromJson(jsonDecode(val));
          final norm = m.title.toLowerCase().trim();
          if (!seen.contains('${m.id}') && !seen.contains(norm)) {
            seen.add('${m.id}');
            seen.add(norm);
            list.add(m);
          }
        } catch (_) {}
      }
    }
    return list;
  }

  // --- PERSISTENT POSTER CACHE ---
  static String? getCachedPoster(String title) {
    try {
      final key = title.toLowerCase().trim();
      final val = _posterBox.get(key);
      return val is String ? val : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedPoster(String title, String posterUrl) async {
    try {
      final key = title.toLowerCase().trim();
      await _posterBox.put(key, posterUrl);
    } catch (_) {}
  }

  // --- APPRENDIMENTO ADATTIVO DAGLI SWIPE (DESTRO / SINISTRO) ---
  static Future<void> recordSwipeFeedback({
    required List<int> genreIds,
    String? director,
    required bool isLike,
  }) async {
    try {
      // 1. Pesi generi appresi (accumulo permanente)
      final rawGenres = _swipeBox.get('learned_genres');
      final Map<String, double> genreScores = rawGenres != null
          ? Map<String, double>.from(
              (jsonDecode(rawGenres) as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : {};

      for (final gId in genreIds) {
        final key = gId.toString();
        final current = genreScores[key] ?? 0.0;
        final delta = isLike ? 2.5 : -1.5;
        genreScores[key] = (current + delta).clamp(-15.0, 30.0);
      }
      await _swipeBox.put('learned_genres', jsonEncode(genreScores));

      // 2. Pesi registi appresi (se presente)
      if (director != null && director.trim().isNotEmpty) {
        final cleanDirector = director.trim();
        final rawDirectors = _swipeBox.get('learned_directors');
        final Map<String, double> directorScores = rawDirectors != null
            ? Map<String, double>.from(
                (jsonDecode(rawDirectors) as Map).map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
                ),
              )
            : {};
        final current = directorScores[cleanDirector] ?? 0.0;
        final delta = isLike ? 4.0 : -3.0;
        directorScores[cleanDirector] = (current + delta).clamp(-20.0, 40.0);
        await _swipeBox.put('learned_directors', jsonEncode(directorScores));
      }

      // 3. Contatori swipe
      final countKey = isLike ? 'swipe_right_count' : 'swipe_left_count';
      final count = (_swipeBox.get(countKey) as int? ?? 0) + 1;
      await _swipeBox.put(countKey, count);
    } catch (e) {
      debugPrint('Errore salvataggio swipe learning: $e');
    }
  }

  static Map<int, double> getLearnedGenreScores() {
    try {
      final raw = _swipeBox.get('learned_genres');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
      }
    } catch (_) {}
    return {};
  }

  static Map<String, double> getLearnedDirectorScores() {
    try {
      final raw = _swipeBox.get('learned_directors');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    } catch (_) {}
    return {};
  }

  static Map<String, int> getSwipeStats() {
    return {
      'swipesRight': (_swipeBox.get('swipe_right_count') as int? ?? 0),
      'swipesLeft': (_swipeBox.get('swipe_left_count') as int? ?? 0),
    };
  }

  // --- ESPORTAZIONE E RIPRISTINO BACKUP COMPLETO JSON ---
  static Map<String, dynamic> exportAllDataToJson({String backupType = 'auto'}) {
    final cachedMovies = getCachedMovies();
    final watchlistMovies = getLocalWatchlistMovies();
    final tasteProfile = getTasteProfile();
    final dismissedIds = getDismissedMovieIds().toList();
    final learnedGenres = getLearnedGenreScores();
    final learnedDirectors = getLearnedDirectorScores();
    final tvSeriesList = getTvSeriesList();
    final swipeStats = getSwipeStats();

    return {
      'cinepulse_backup_version': 2,
      'app_version': '1.0.2',
      'backup_type': backupType,
      'created_at': DateTime.now().toIso8601String(),
      'username': getActiveUsername() ?? 'Cinefilo',
      'streaming_country': getSelectedCountry(),
      'streaming_providers': getSelectedStreamingProviders(),
      'watched_movies': cachedMovies.map((m) => m.toJson()).toList(),
      'watchlist_movies': watchlistMovies.map((m) => m.toJson()).toList(),
      'tv_series': tvSeriesList.map((s) => s.toJson()).toList(),
      'taste_profile': tasteProfile?.toJson(),
      'dismissed_movie_ids': dismissedIds,
      'learned_genres': learnedGenres.map((k, v) => MapEntry(k.toString(), v)),
      'learned_directors': learnedDirectors,
      'swipe_stats': swipeStats,
    };
  }

  static Future<bool> restoreAllDataFromJson(Map<String, dynamic> data) async {
    try {
      if (!data.containsKey('watched_movies') && !data.containsKey('taste_profile')) {
        return false;
      }

      // 1. Username
      if (data['username'] != null && data['username'].toString().isNotEmpty) {
        await setActiveUsername(data['username'].toString());
      }

      // 2. Impostazioni streaming
      if (data['streaming_country'] != null) {
        await setSelectedCountry(data['streaming_country'].toString());
      }
      if (data['streaming_providers'] is List) {
        await setSelectedStreamingProviders(List<String>.from(data['streaming_providers']));
      }

      // 3. Film visti
      if (data['watched_movies'] is List) {
        final List<LetterboxdMovie> movies = (data['watched_movies'] as List)
            .map((m) => LetterboxdMovie.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        await saveLetterboxdMovies(movies);
      }

      // 4. Watchlist
      if (data['watchlist_movies'] is List) {
        for (final mRaw in (data['watchlist_movies'] as List)) {
          final m = TmdbMovie.fromJson(Map<String, dynamic>.from(mRaw));
          await saveWatchlistMovie(m);
        }
      }

      // 4.1 Serie TV
      if (data['tv_series'] is List) {
        for (final sRaw in (data['tv_series'] as List)) {
          final s = TvSeries.fromJson(Map<String, dynamic>.from(sRaw));
          await saveTvSeries(s);
        }
      }

      // 5. Profilo di Gusto
      if (data['taste_profile'] is Map) {
        final profile = TasteProfile.fromJson(Map<String, dynamic>.from(data['taste_profile']));
        await saveTasteProfile(profile);
      }

      // 6. Film scartati
      if (data['dismissed_movie_ids'] is List) {
        for (final id in (data['dismissed_movie_ids'] as List)) {
          final intId = (id as num).toInt();
          await dismissMovie(intId);
        }
      }

      // 7. Apprendimento swipe
      if (data['learned_genres'] is Map) {
        await _swipeBox.put('learned_genres', jsonEncode(data['learned_genres']));
      }
      if (data['learned_directors'] is Map) {
        await _swipeBox.put('learned_directors', jsonEncode(data['learned_directors']));
      }
      if (data['swipe_stats'] is Map) {
        final stats = data['swipe_stats'] as Map;
        await _swipeBox.put('swipe_right_count', stats['swipesRight'] ?? 0);
        await _swipeBox.put('swipe_left_count', stats['swipesLeft'] ?? 0);
      }

      return true;
    } catch (e) {
      debugPrint('Errore ripristino dati backup: $e');
      return false;
    }
  }
}
