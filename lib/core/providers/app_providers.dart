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

// Raccomandazioni personalizzate (AsyncNotifier)
class RecommendationsAsyncNotifier extends AsyncNotifier<List<TmdbMovie>> {
  @override
  Future<List<TmdbMovie>> build() async {
    return _fetchRecommendations();
  }

  Future<List<TmdbMovie>> _fetchRecommendations({bool forceRefresh = false}) async {
    final movies = ref.watch(userLetterboxdMoviesProvider);
    var profile = ref.watch(tasteProfileProvider);
    final country = ref.watch(selectedCountryProvider);
    final filters = ref.watch(activeProvidersFilterProvider);
    final engine = ref.watch(recommendationEngineProvider);
    final username = ref.watch(activeUserProvider);

    if (movies.isEmpty) {
      // Se l'utente non ha ancora importato nulla, mostra i film di tendenza mondiali
      return engine.getTrendingFallbackMovies(countryCode: country);
    }

    if (profile == null || forceRefresh) {
      profile = await engine.buildTasteProfile(username ?? 'Cinefilo', movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);
    }

    return engine.generateRecommendations(
      userMovies: movies,
      tasteProfile: profile,
      countryCode: country,
      requiredProviders: filters,
    );
  }

  Future<void> loadRecommendations({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRecommendations(forceRefresh: forceRefresh));
  }

  Future<void> dismissMovie(int tmdbId) async {
    await LocalStorageService.dismissMovie(tmdbId);
    state.whenData((list) {
      state = AsyncValue.data(list.where((m) => m.id != tmdbId).toList());
    });
  }

  Future<void> toggleFavorite(int tmdbId) async {
    await LocalStorageService.toggleFavoriteMovie(tmdbId);
  }
}

final recommendationsProvider =
    AsyncNotifierProvider<RecommendationsAsyncNotifier, List<TmdbMovie>>(
  () => RecommendationsAsyncNotifier(),
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
