import 'package:flutter/foundation.dart';
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

class UserLetterboxdMoviesNotifier extends Notifier<List<LetterboxdMovie>> {
  @override
  List<LetterboxdMovie> build() => LocalStorageService.getCachedMovies();

  void setMovies(List<LetterboxdMovie> movies) => state = movies;

  Future<void> addWatchedMovie(LetterboxdMovie movie) async {
    await LocalStorageService.addWatchedMovie(movie);
    state = [...state.where((m) => m.slug != movie.slug), movie];
  }

  /// Sincronizzazione rapida via RSS e watchlist con Letterboxd
  Future<int> syncRecentFromLetterboxd(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty || clean == 'ospite') return 0;

    try {
      final service = ref.read(letterboxdServiceProvider);
      final results = await Future.wait([
        service.fetchRecentWatchedRss(clean),
        service.fetchCurrentWatchlist(clean),
      ]);

      final recentWatched = results[0];
      final currentWatchlist = results[1];

      if (recentWatched.isEmpty && currentWatchlist.isEmpty) {
        return 0;
      }

      int modifiedCount = 0;
      final currentList = [...state];
      final Map<String, LetterboxdMovie> mapByTitle = {};

      for (final m in currentList) {
        mapByTitle[m.title.toLowerCase().trim()] = m;
      }

      // 1. Processa i film visti di recente estratti da Letterboxd
      final localWatchlist = LocalStorageService.getLocalWatchlistMovies();
      final watchlistNotifier = ref.read(watchlistProvider.notifier);

      for (final watched in recentWatched) {
        final normTitle = watched.title.toLowerCase().trim();
        final existing = mapByTitle[normTitle];

        // Se era marcato come in watchlist o è un nuovo film visto
        if (existing == null || existing.isInWatchlist) {
          modifiedCount++;
        }

        final updated = LetterboxdMovie(
          slug: watched.slug.isNotEmpty ? watched.slug : (existing?.slug ?? normTitle.replaceAll(' ', '-')),
          title: watched.title,
          year: watched.year ?? existing?.year,
          rating: watched.rating ?? existing?.rating,
          watchedDate: watched.watchedDate ?? existing?.watchedDate ?? DateTime.now(),
          isLiked: existing?.isLiked ?? false,
          isInWatchlist: false, // Rimosso dalla watchlist perché è visto!
          posterUrl: watched.posterUrl ?? existing?.posterUrl,
        );

        mapByTitle[normTitle] = updated;

        // Se era presente nella watchlist locale CinePulse, rimuovilo!
        final localMatch = localWatchlist.where((m) => m.title.toLowerCase().trim() == normTitle).firstOrNull;
        if (localMatch != null) {
          watchlistNotifier.removeMovie(localMatch.id);
          modifiedCount++;
        }
      }

      // 2. Se abbiamo la watchlist aggiornata da Letterboxd, aggiungi nuovi film o aggiorna lo stato
      if (currentWatchlist.isNotEmpty) {

        // Assicuriamoci che tutti i film attuali in watchlist ci siano e siano marcati isInWatchlist: true
        for (final w in currentWatchlist) {
          final normTitle = w.title.toLowerCase().trim();
          if (!mapByTitle.containsKey(normTitle)) {
            mapByTitle[normTitle] = w;
            modifiedCount++;
          } else {
            final ex = mapByTitle[normTitle]!;
            if (!ex.isInWatchlist) {
              mapByTitle[normTitle] = LetterboxdMovie(
                slug: ex.slug,
                title: ex.title,
                year: ex.year ?? w.year,
                rating: ex.rating,
                watchedDate: ex.watchedDate,
                isLiked: ex.isLiked,
                isInWatchlist: true,
                posterUrl: ex.posterUrl ?? w.posterUrl,
              );
              modifiedCount++;
            }
          }
        }
      }

      final updatedList = mapByTitle.values.toList();
      await LocalStorageService.saveLetterboxdMovies(updatedList);
      state = updatedList;

      // Se ci sono stati aggiornamenti, ricalcola profilo di gusto per i consigli
      if (modifiedCount > 0) {
        final engine = ref.read(recommendationEngineProvider);
        final newProfile = await engine.buildTasteProfile(clean, updatedList);
        ref.read(tasteProfileProvider.notifier).setProfile(newProfile);
      }

      return modifiedCount;
    } catch (e) {
      debugPrint('Errore sync recente Letterboxd: $e');
      return 0;
    }
  }
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

  Future<void> markMovieAsWatched(TmdbMovie movie) async {
    final lm = LetterboxdMovie(
      slug: movie.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      title: movie.title,
      year: int.tryParse(movie.releaseYear),
      watchedDate: DateTime.now(),
      posterUrl: movie.posterUrl,
    );

    // 1. Salva nei film visti CinePulse
    await ref.read(userLetterboxdMoviesProvider.notifier).addWatchedMovie(lm);

    // 2. Rimuovi dalla watchlist se c'era
    ref.read(watchlistProvider.notifier).removeMovie(movie.id);

    // 3. Rimuovi dai consigli correnti
    await dismissMovie(movie.id);

    // 4. Ricalcola profilo di gusto e preferenze generi
    final allMovies = ref.read(userLetterboxdMoviesProvider);
    final engine = ref.read(recommendationEngineProvider);
    final user = ref.read(activeUserProvider) ?? 'CinePulse';
    final newProfile = await engine.buildTasteProfile(user, allMovies);
    ref.read(tasteProfileProvider.notifier).setProfile(newProfile);
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
