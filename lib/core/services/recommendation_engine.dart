import 'dart:math';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/letterboxd_movie.dart';
import '../models/taste_profile.dart';
import '../models/tmdb_movie.dart';
import '../network/tmdb_client.dart';
import '../storage/local_storage.dart';

class RecommendationEngine {
  final TmdbClient _tmdbClient;

  RecommendationEngine(this._tmdbClient);

  /// Calcola il profilo statistico dell'utente a partire dai film sincronizzati da Letterboxd
  Future<TasteProfile> buildTasteProfile(
    String username,
    List<LetterboxdMovie> userMovies,
  ) async {
    final Map<String, int> genreCounts = {};
    final Map<String, double> genreWeightedScore = {};
    final Map<String, int> directorCounts = {};

    int totalWatched = 0;
    int totalRated = 0;
    int totalInWatchlist = 0;
    double ratingSum = 0.0;

    // Analizziamo i film
    // Calcolo metriche globali su tutta la collezione
    for (final movie in userMovies) {
      if (movie.isInWatchlist) {
        totalInWatchlist++;
      } else {
        totalWatched++;
      }

      if (movie.rating != null && movie.rating! > 0) {
        totalRated++;
        ratingSum += movie.rating!;
      }
    }

    // Seleziona un campione altamente informativo (fino a 45 film) per l'analisi generi e registi
    final ratedOrLiked = userMovies
        .where((m) => (m.rating != null && m.rating! >= 3.5) || m.isLiked)
        .take(30)
        .toList();

    final recentOthers = userMovies
        .where((m) => !ratedOrLiked.contains(m) && !m.isInWatchlist)
        .take(15)
        .toList();

    final sampleMovies = [...ratedOrLiked, ...recentOthers];

    await Future.wait(
      sampleMovies.map((movie) async {
        double multiplier = 1.0;
        if (movie.rating != null) {
          if (movie.rating! >= 4.0) {
            multiplier = 2.0;
          } else if (movie.rating! >= 3.0) {
            multiplier = 1.2;
          } else {
            multiplier = 0.3;
          }
        }
        if (movie.isLiked) {
          multiplier += 0.5;
        }

        var tmdbInfo = await _tmdbClient.searchMovie(movie.title, year: movie.year);
        tmdbInfo ??= await _tmdbClient.searchMovie(movie.title);

        if (tmdbInfo != null) {
          for (final gId in tmdbInfo.genreIds) {
            final gName = AppConfig.genreMap[gId] ?? 'Altro';
            genreCounts[gName] = (genreCounts[gName] ?? 0) + 1;
            genreWeightedScore[gName] = (genreWeightedScore[gName] ?? 0.0) + multiplier;
          }

          if (tmdbInfo.director != null && tmdbInfo.director!.isNotEmpty) {
            directorCounts[tmdbInfo.director!] =
                (directorCounts[tmdbInfo.director!] ?? 0) + 1;
          }
        }
      }),
    );

    // Calcolo delle percentuali di frequenza generi
    final int totalGenreHits = genreCounts.values.fold(0, (a, b) => a + b);
    final Map<String, double> genrePercentages = {};
    if (totalGenreHits > 0) {
      genreCounts.forEach((genre, count) {
        genrePercentages[genre] = (count / totalGenreHits) * 100.0;
      });
    } else {
      // Fallback predefinito se la rete era offline durante l'importazione
      genrePercentages['Drammatico'] = 28.0;
      genrePercentages['Thriller'] = 22.0;
      genrePercentages['Fantascienza'] = 18.0;
      genrePercentages['Commedia'] = 14.0;
      genrePercentages['Azione'] = 10.0;
      genrePercentages['Avventura'] = 8.0;
    }

    // Top registi ordinati per frequenza
    final sortedDirectors = directorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDirectors = sortedDirectors.take(5).map((e) => e.key).toList();

    final avgRating = totalRated > 0 ? (ratingSum / totalRated) : 0.0;

    final profile = TasteProfile(
      username: username,
      totalWatched: totalWatched,
      totalRated: totalRated,
      totalInWatchlist: totalInWatchlist,
      genreCounts: genreCounts,
      genrePercentages: genrePercentages,
      topDirectors: topDirectors,
      averageRating: double.parse(avgRating.toStringAsFixed(1)),
      lastSync: DateTime.now(),
    );

    await LocalStorageService.saveTasteProfile(profile);
    return profile;
  }

  /// Genera le raccomandazioni cinematografiche intelligenti on-device
  Future<List<TmdbMovie>> generateRecommendations({
    required List<LetterboxdMovie> userMovies,
    required TasteProfile tasteProfile,
    required String countryCode,
    List<String> requiredProviders = const [],
    int maxResults = 25,
  }) async {
    // 1. Creiamo un set dei titoli già visti per esclusione assoluta
    final Set<String> watchedTitles = userMovies
        .where((m) => !m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Set<String> watchlistTitles = userMovies
        .where((m) => m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Map<int, TmdbMovie> candidates = {};

    // 2. Troviamo i film più amati o recenti per interrogare le recommendations di TMDb
    final favoriteOrRecent = userMovies
        .where((m) => (m.rating != null && m.rating! >= 4.0) || m.isLiked)
        .take(4)
        .toList();

    // Se non ha voti alti, prendi i primi film visti
    final seedMovies = favoriteOrRecent.isNotEmpty
        ? favoriteOrRecent
        : userMovies.where((m) => !m.isInWatchlist).take(4).toList();

    for (final seed in seedMovies) {
      final searchResult = await _tmdbClient.searchMovie(seed.title, year: seed.year);
      if (searchResult != null) {
        final recs = await _tmdbClient.getRecommendations(searchResult.id);
        for (final r in recs) {
          if (!_isMovieExcluded(r, watchedTitles)) {
            candidates[r.id] = r;
          }
        }
      }
    }

    // 3. Troviamo i Top 2 generi per affinità e facciamo una Discover TMDb mirata
    final sortedGenres = tasteProfile.genrePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<int> targetGenreIds = [];
    for (final g in sortedGenres.take(2)) {
      final id = AppConfig.getGenreIdByName(g.key);
      if (id != null) targetGenreIds.add(id);
    }

    if (targetGenreIds.isNotEmpty) {
      final discovered = await _tmdbClient.discoverMovies(
        withGenres: targetGenreIds,
        minVote: 7.0,
        minVoteCount: 150,
      );
      for (final m in discovered) {
        if (!_isMovieExcluded(m, watchedTitles)) {
          candidates[m.id] = m;
        }
      }
    }

    // 4. Analizziamo i film in Watchlist (priorità speciale)
    for (final w in userMovies.where((m) => m.isInWatchlist).take(5)) {
      final wInfo = await _tmdbClient.searchMovie(w.title, year: w.year);
      if (wInfo != null && !_isMovieExcluded(wInfo, watchedTitles)) {
        candidates[wInfo.id] = wInfo.copyWith(isInUserWatchlist: true);
      }
    }

    // Se abbiamo pochi candidati, arricchiamo con Trending della settimana di qualità
    if (candidates.length < 10) {
      final trending = await _tmdbClient.getTrending();
      for (final t in trending) {
        if (!_isMovieExcluded(t, watchedTitles)) {
          candidates[t.id] = t;
        }
      }
    }

    // 5. Scoring & Dettagli dei Candidati in parallelo
    final List<TmdbMovie> scoredList = [];
    final candidateList = candidates.values.take(25).toList();

    final detailedCandidates = await Future.wait(
      candidateList.map((cand) async {
        try {
          return await _tmdbClient.getMovieDetails(cand.id, countryCode: countryCode) ?? cand;
        } catch (_) {
          return cand;
        }
      }),
    );

    for (final full in detailedCandidates) {
      // Verifica filtri provider se specificati dall'utente
      if (requiredProviders.isNotEmpty) {
        final availableFlatrate = full
            .flatrateProviders(countryCode)
            .map((p) => p.providerName.toLowerCase())
            .toList();

        final hasMatch = requiredProviders.any((req) =>
            availableFlatrate.any((avail) => avail.contains(req.toLowerCase())));

        if (!hasMatch) {
          continue; // Salta se non presente negli abbonamenti dell'utente
        }
      }

      // CALCOLO DELLO SCORE DI AFFINITÀ (0 - 100%)
      double score = 0.0;
      final List<String> reasons = [];

      // A. Match Generi (fino a 45 punti)
      double genrePoints = 0.0;
      for (final gId in full.genreIds) {
        final gName = AppConfig.genreMap[gId];
        if (gName != null && tasteProfile.genrePercentages.containsKey(gName)) {
          final pct = tasteProfile.genrePercentages[gName]!;
          genrePoints += (pct * 0.45);
        }
      }
      genrePoints = min(45.0, genrePoints);
      score += genrePoints;

      if (sortedGenres.isNotEmpty && full.genreIds.contains(AppConfig.getGenreIdByName(sortedGenres.first.key))) {
        reasons.add('✦ Altissima affinità col tuo genere preferito (${sortedGenres.first.key})');
      }

      // B. Regista preferito ricorrente (bonus 20 punti)
      if (full.director != null && tasteProfile.topDirectors.contains(full.director)) {
        score += 20.0;
        reasons.add('✦ Diretto da ${full.director}, uno dei tuoi registi ricorrenti');
      }

      // C. Voto critico TMDb (fino a 20 punti)
      // Normalizziamo il voto TMDb (es. 8.0/10 -> 16 punti)
      final votePoints = (full.voteAverage / 10.0) * 20.0;
      score += votePoints;

      // D. Bonus Watchlist (15 punti se è già nei tuoi piani)
      final isWatchlist = watchlistTitles.contains(_normalizeTitle(full.title)) ||
          full.isInUserWatchlist;
      if (isWatchlist) {
        score += 15.0;
        reasons.add('✦ È già presente nella tua Watchlist di Letterboxd!');
      }

      // Controllo disponibilità streaming
      final providers = full.flatrateProviders(countryCode);
      if (providers.isNotEmpty) {
        final names = providers.take(2).map((p) => p.providerName).join(', ');
        reasons.add('✦ Disponibile in streaming su $names (${AppConfig.supportedCountries[countryCode] ?? countryCode})');
      }

      // Normalizzazione finale dello score tra 70% e 99% per dare un feeling cinematografico gratificante
      final finalScore = min(99.0, max(72.0, score));

      scoredList.add(
        full.copyWith(
          matchScore: double.parse(finalScore.toStringAsFixed(1)),
          matchReasons: reasons,
          isInUserWatchlist: isWatchlist,
        ),
      );
    }

    // Ordina dal match più alto al più basso
    scoredList.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return scoredList.take(maxResults).toList();
  }

  /// Restituisce film popolari e acclamati come fallback se l'utente non ha ancora importato nulla
  Future<List<TmdbMovie>> getTrendingFallbackMovies({
    String countryCode = 'IT',
    int count = 20,
  }) async {
    final raw = await _tmdbClient.getPopularMovies();
    if (raw.isEmpty) return [];

    final futures = raw.take(count).map((m) async {
      try {
        final details = await _tmdbClient.getMovieDetails(m.id, countryCode: countryCode);
        return (details ?? m).copyWith(
          matchScore: 92.0,
          matchReasons: ['✦ Tra i film più acclamati e visti del momento'],
        );
      } catch (_) {
        return m.copyWith(
          matchScore: 90.0,
          matchReasons: ['✦ Film di tendenza globale'],
        );
      }
    });

    final list = await Future.wait(futures);
    return list.where((m) => !LocalStorageService.isMovieDismissed(m.id)).toList();
  }

  bool _isMovieExcluded(TmdbMovie movie, Set<String> watchedTitles) {
    if (LocalStorageService.isMovieDismissed(movie.id)) return true;
    final normalized = _normalizeTitle(movie.title);
    if (watchedTitles.contains(normalized)) return true;
    if (movie.originalTitle != null &&
        watchedTitles.contains(_normalizeTitle(movie.originalTitle!))) {
      return true;
    }
    return false;
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}
