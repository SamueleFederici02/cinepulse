import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/letterboxd_movie.dart';
import '../models/taste_profile.dart';
import '../models/tmdb_movie.dart';
import '../network/tmdb_client.dart';
import '../services/letterboxd_service.dart';
import '../services/recommendation_engine.dart';
import '../storage/local_storage.dart';

// Services
final tmdbClientProvider = Provider<TmdbClient>((ref) => TmdbClient());

final letterboxdServiceProvider = Provider<LetterboxdService>((ref) => LetterboxdService());

final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  final tmdb = ref.watch(tmdbClientProvider);
  return RecommendationEngine(tmdb);
});

// --- NOTIFIERS PER RIVERPOD 3 ---

// Tab di navigazione attivo
class NavTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final navTabProvider = NotifierProvider<NavTabNotifier, int>(
  () => NavTabNotifier(),
);

// Username attivo
class ActiveUserNotifier extends Notifier<String?> {
  @override
  String? build() => LocalStorageService.getActiveUsername();

  void setUsername(String? username) => state = username;
}

final activeUserProvider = NotifierProvider<ActiveUserNotifier, String?>(
  () => ActiveUserNotifier(),
);

// Nazione streaming selezionata
class SelectedCountryNotifier extends Notifier<String> {
  @override
  String build() => LocalStorageService.getSelectedCountry();

  void setCountry(String country) => state = country;
}

final selectedCountryProvider = NotifierProvider<SelectedCountryNotifier, String>(
  () => SelectedCountryNotifier(),
);

// Filtro provider streaming attivi
class ActiveProvidersFilterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => LocalStorageService.getSelectedStreamingProviders();

  void setProviders(List<String> providers) => state = providers;
}

final activeProvidersFilterProvider =
    NotifierProvider<ActiveProvidersFilterNotifier, List<String>>(
  () => ActiveProvidersFilterNotifier(),
);

// Film di Letterboxd salvati in locale
class UserLetterboxdMoviesNotifier extends Notifier<List<LetterboxdMovie>> {
  @override
  List<LetterboxdMovie> build() => LocalStorageService.getCachedMovies();

  void setMovies(List<LetterboxdMovie> movies) => state = movies;
}

final userLetterboxdMoviesProvider =
    NotifierProvider<UserLetterboxdMoviesNotifier, List<LetterboxdMovie>>(
  () => UserLetterboxdMoviesNotifier(),
);

// Taste Profile
class TasteProfileNotifier extends Notifier<TasteProfile?> {
  @override
  TasteProfile? build() => LocalStorageService.getTasteProfile();

  void setProfile(TasteProfile? profile) => state = profile;
}

final tasteProfileProvider = NotifierProvider<TasteProfileNotifier, TasteProfile?>(
  () => TasteProfileNotifier(),
);

// Raccomandazioni personalizzate (AsyncNotifier con Scroll Infinito e Apprendimento Real-time)
class RecommendationsAsyncNotifier extends AsyncNotifier<List<TmdbMovie>> {
  int _currentPage = 1;
  bool _isLoadingMore = false;
  final Set<int> _recommendedIds = {};
  final Map<int, double> _realtimeGenreBoost = {};
  final Map<int, double> _realtimeGenrePenalty = {};

  @override
  Future<List<TmdbMovie>> build() async {
    return _fetchRecommendations();
  }

  Future<List<TmdbMovie>> _fetchRecommendations({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _currentPage = 1;
      _recommendedIds.clear();
      _realtimeGenreBoost.clear();
      _realtimeGenrePenalty.clear();
    }

    final movies = ref.watch(userLetterboxdMoviesProvider);
    var profile = ref.watch(tasteProfileProvider);
    final country = ref.watch(selectedCountryProvider);
    final filters = ref.watch(activeProvidersFilterProvider);
    final engine = ref.watch(recommendationEngineProvider);
    final username = ref.watch(activeUserProvider);

    if (movies.isEmpty) {
      final list = await engine.getTrendingFallbackMovies(countryCode: country);
      _recommendedIds.addAll(list.map((m) => m.id));
      return list;
    }

    if (profile == null || forceRefresh) {
      profile = await engine.buildTasteProfile(username ?? 'Cinefilo', movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);
    }

    final initialList = await engine.generateRecommendations(
      userMovies: movies,
      tasteProfile: profile,
      countryCode: country,
      requiredProviders: filters,
    );
    _recommendedIds.addAll(initialList.map((m) => m.id));
    return initialList;
  }

  Future<void> loadRecommendations({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRecommendations(forceRefresh: forceRefresh));
  }

  /// Apprendimento in tempo reale quando l'utente mette Dislike (Swipe Sinistra / Pollice in giù)
  Future<void> recordDislike(TmdbMovie movie) async {
    await LocalStorageService.dismissMovie(movie.id);

    // Applica penalità real-time ai generi di questo film per non riproporli continuamente
    for (final gId in movie.genreIds) {
      _realtimeGenrePenalty[gId] = (_realtimeGenrePenalty[gId] ?? 0.0) + 1.2;
    }

    state.whenData((list) {
      state = AsyncValue.data(list.where((m) => m.id != movie.id).toList());
    });
  }

  /// Apprendimento in tempo reale quando l'utente aggiunge in Watchlist (Swipe Destra / Bookmark)
  Future<void> recordWatchlist(TmdbMovie movie) async {
    await LocalStorageService.saveWatchlistMovie(movie);
    ref.read(watchlistProvider.notifier).addMovie(movie);

    // Applica boost real-time ai generi di questo film
    for (final gId in movie.genreIds) {
      _realtimeGenreBoost[gId] = (_realtimeGenreBoost[gId] ?? 0.0) + 2.0;
    }
  }

  /// Carica la pagina successiva di raccomandazioni (Infinite Scroll)
  Future<void> loadMoreRecommendations() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    _currentPage++;

    try {
      final movies = ref.read(userLetterboxdMoviesProvider);
      final profile = ref.read(tasteProfileProvider);
      final country = ref.read(selectedCountryProvider);
      final filters = ref.read(activeProvidersFilterProvider);
      final engine = ref.read(recommendationEngineProvider);

      if (profile != null) {
        final nextBatch = await engine.generateNextPageRecommendations(
          userMovies: movies,
          tasteProfile: profile,
          countryCode: country,
          page: _currentPage,
          alreadyRecommendedIds: _recommendedIds,
          realtimeGenreBoost: _realtimeGenreBoost,
          realtimeGenrePenalty: _realtimeGenrePenalty,
          requiredProviders: filters,
        );

        if (nextBatch.isNotEmpty) {
          _recommendedIds.addAll(nextBatch.map((m) => m.id));
          state.whenData((currentList) {
            final existingIds = currentList.map((m) => m.id).toSet();
            final uniqueNew = nextBatch.where((m) => !existingIds.contains(m.id)).toList();
            state = AsyncValue.data([...currentList, ...uniqueNew]);
          });
        }
      }
    } catch (e) {
      // Ignora silente errori durante infinite scroll per non interrompere la UI
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> dismissMovie(int tmdbId) async {
    await LocalStorageService.dismissMovie(tmdbId);
    state.whenData((list) {
      state = AsyncValue.data(list.where((m) => m.id != tmdbId).toList());
    });
  }

  Future<void> toggleFavorite(int tmdbId, [TmdbMovie? movie]) async {
    await LocalStorageService.toggleFavoriteMovie(tmdbId, movie);
    if (movie != null) {
      ref.read(watchlistProvider.notifier).addMovie(movie);
    }
  }
}

final recommendationsProvider =
    AsyncNotifierProvider<RecommendationsAsyncNotifier, List<TmdbMovie>>(
  () => RecommendationsAsyncNotifier(),
);

// Notifier per la gestione reattiva della Watchlist (CinePulse + Letterboxd)
class WatchlistNotifier extends Notifier<List<TmdbMovie>> {
  @override
  List<TmdbMovie> build() {
    return LocalStorageService.getLocalWatchlistMovies();
  }

  void addMovie(TmdbMovie movie) {
    LocalStorageService.saveWatchlistMovie(movie);
    final current = state.where((m) => m.id != movie.id).toList();
    state = [movie.copyWith(isInUserWatchlist: true), ...current];
  }

  void removeMovie(int tmdbId) {
    LocalStorageService.removeWatchlistMovie(tmdbId);
    state = state.where((m) => m.id != tmdbId).toList();
  }

  void refresh() {
    state = LocalStorageService.getLocalWatchlistMovies();
  }
}

final watchlistProvider = NotifierProvider<WatchlistNotifier, List<TmdbMovie>>(
  () => WatchlistNotifier(),
);

// Film ultimi usciti (Now Playing) con dettagli e watch providers in parallelo
final nowPlayingMoviesProvider = FutureProvider<List<TmdbMovie>>((ref) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final country = ref.watch(selectedCountryProvider);
  final raw = await tmdb.getNowPlayingMovies();
  if (raw.isEmpty) return [];

  final futures = raw.take(20).map((m) async {
    try {
      final details = await tmdb.getMovieDetails(m.id, countryCode: country);
      return details ?? m;
    } catch (_) {
      return m;
    }
  });

  return Future.wait(futures);
});

// Film più votati di sempre (Top Rated) con dettagli e watch providers in parallelo
final topRatedMoviesProvider = FutureProvider<List<TmdbMovie>>((ref) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final country = ref.watch(selectedCountryProvider);
  final raw = await tmdb.getTopRatedMovies();
  if (raw.isEmpty) return [];

  final futures = raw.take(20).map((m) async {
    try {
      final details = await tmdb.getMovieDetails(m.id, countryCode: country);
      return details ?? m;
    } catch (_) {
      return m;
    }
  });

  return Future.wait(futures);
});

// Catalogo completo di tutti i provider streaming per la nazione attiva (con loghi e A-Z)
final countryProvidersListProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final country = ref.watch(selectedCountryProvider);
  return tmdb.getWatchProvidersForCountry(country);
});
