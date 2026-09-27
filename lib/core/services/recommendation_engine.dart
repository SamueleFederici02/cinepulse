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

  /// Calcola il profilo statistico profondo dell'utente a partire dai film di Letterboxd
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

    // 1. Calcolo metriche globali su tutta la collezione
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

    // 2. Suddividiamo la libreria per livelli di apprezzamento
    final fiveStars = userMovies.where((m) => m.rating != null && m.rating! >= 4.75).toList();
    final fourHalfStars = userMovies.where((m) => m.rating != null && m.rating! >= 4.25 && m.rating! < 4.75).toList();
    final fourStars = userMovies.where((m) => m.rating != null && m.rating! >= 3.75 && m.rating! < 4.25).toList();
    final threeHalfStars = userMovies.where((m) => m.rating != null && m.rating! >= 3.25 && m.rating! < 3.75).toList();
    final likedOthers = userMovies.where((m) => m.isLiked && (m.rating == null || m.rating! < 3.75)).toList();
    final recentWatched = userMovies.where((m) => !m.isInWatchlist && m.rating == null && !m.isLiked).toList();

    // Campione bilanciato che riflette autenticamente cosa l'utente AMA e guarda
    final List<LetterboxdMovie> sampleMovies = [];
    sampleMovies.addAll(fiveStars.take(18));
    sampleMovies.addAll(fourHalfStars.take(12));
    sampleMovies.addAll(likedOthers.take(8));
    sampleMovies.addAll(fourStars.take(8));
    sampleMovies.addAll(threeHalfStars.take(4));
    if (sampleMovies.length < 35) {
      sampleMovies.addAll(recentWatched.take(35 - sampleMovies.length));
    }

    // I primi film migliori (5★ e 4.5★) estraggono anche i registi tramite getMovieDetails
    final topFavoriteSlugs = {...fiveStars.take(12), ...fourHalfStars.take(6)}.map((m) => m.slug).toSet();

    // 3. Processamento in batch per non saturare la connessione o il rate-limit TMDb
    const int batchSize = 6;
    for (int i = 0; i < sampleMovies.length; i += batchSize) {
      final batch = sampleMovies.sublist(i, min(i + batchSize, sampleMovies.length));

      await Future.wait(
        batch.map((movie) async {
          try {
            // Peso esponenziale basato sul voto dato dall'utente
            double weight = 1.0;
            if (movie.rating != null) {
              if (movie.rating! >= 4.75) {
                weight = 3.5;
              } else if (movie.rating! >= 4.25) {
                weight = 2.8;
              } else if (movie.rating! >= 3.75) {
                weight = 2.0;
              } else if (movie.rating! >= 3.25) {
                weight = 1.3;
              } else {
                weight = 0.5;
              }
            }
            if (movie.isLiked) {
              weight += 1.0;
            }

            // Ricerca TMDb
            var tmdbInfo = await _tmdbClient.searchMovie(movie.title, year: movie.year);
            tmdbInfo ??= await _tmdbClient.searchMovie(movie.title);

            if (tmdbInfo != null) {
              // Se è uno dei preferiti assoluti, recuperiamo anche il regista tramite getMovieDetails
              if (topFavoriteSlugs.contains(movie.slug)) {
                try {
                  final details = await _tmdbClient.getMovieDetails(tmdbInfo.id);
                  if (details?.director != null && details!.director!.isNotEmpty) {
                    directorCounts[details.director!] = (directorCounts[details.director!] ?? 0) + 1;
                  }
                } catch (_) {}
              }

              // Generi
              for (final gId in tmdbInfo.genreIds) {
                final gName = AppConfig.genreMap[gId] ?? 'Altro';
                genreCounts[gName] = (genreCounts[gName] ?? 0) + 1;
                genreWeightedScore[gName] = (genreWeightedScore[gName] ?? 0.0) + weight;
              }
            }
          } catch (e) {
            debugPrint('Errore analisi film ${movie.title}: $e');
          }
        }),
      );

      // Micro delay di cortesia per TMDb
      await Future.delayed(const Duration(milliseconds: 30));
    }

    // 4. Calcolo delle percentuali di frequenza generi pesate
    final double totalWeightedScore = genreWeightedScore.values.fold(0.0, (a, b) => a + b);
    final Map<String, double> genrePercentages = {};

    if (totalWeightedScore > 0) {
      genreWeightedScore.forEach((genre, score) {
        final pct = (score / totalWeightedScore) * 100.0;
        genrePercentages[genre] = double.parse(pct.toStringAsFixed(1));
      });
    } else {
      // Fallback cinefilo bilanciato se l'utente era offline durante la prima importazione
      genrePercentages['Drammatico'] = 26.0;
      genrePercentages['Thriller'] = 20.0;
      genrePercentages['Fantascienza'] = 18.0;
      genrePercentages['Commedia'] = 14.0;
      genrePercentages['Azione'] = 12.0;
      genrePercentages['Animazione'] = 10.0;
    }

    // 5. Top registi ricorrenti
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
    // 1. Set dei titoli già visti per esclusione assoluta
    final Set<String> watchedTitles = userMovies
        .where((m) => !m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Set<String> watchlistTitles = userMovies
        .where((m) => m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Map<int, TmdbMovie> candidates = {};
    final Map<int, String> candidateSeedReason = {};

    // 2. CANALE 1: Raccomandazioni dai film più amati dell'utente (5★, 4.5★, cuori)
    final topSeeds = userMovies
        .where((m) => (m.rating != null && m.rating! >= 4.0) || m.isLiked)
        .toList();

    // Prendiamo fino a 6 film seme per diversificare
    final seedMovies = topSeeds.isNotEmpty
        ? topSeeds.take(6).toList()
        : userMovies.where((m) => !m.isInWatchlist).take(4).toList();

    for (final seed in seedMovies) {
      try {
        final searchResult = await _tmdbClient.searchMovie(seed.title, year: seed.year);
        if (searchResult != null) {
          // Recupero raccomandazioni e film simili da TMDb
          final recs = await _tmdbClient.getRecommendations(searchResult.id);
          final similar = await _tmdbClient.getSimilarMovies(searchResult.id);

          for (final m in [...recs, ...similar]) {
            if (!_isMovieExcluded(m, watchedTitles)) {
              candidates[m.id] = m;
              candidateSeedReason[m.id] = '✦ Ispirato dal tuo gradimento per "${seed.title}"';
            }
          }
        }
      } catch (e) {
        debugPrint('Errore recupero recs per ${seed.title}: $e');
      }
    }

    // 3. CANALE 2: Priorità ai film nella Watchlist di Letterboxd dell'utente
    final watchlistCandidates = userMovies.where((m) => m.isInWatchlist).take(8).toList();
    for (final w in watchlistCandidates) {
      try {
        final wInfo = await _tmdbClient.searchMovie(w.title, year: w.year);
        if (wInfo != null && !_isMovieExcluded(wInfo, watchedTitles)) {
          candidates[wInfo.id] = wInfo.copyWith(isInUserWatchlist: true);
          candidateSeedReason[wInfo.id] = '✦ Dalla tua Watchlist di Letterboxd!';
        }
      } catch (_) {}
    }

    // 4. CANALE 3: Discover di capolavori nei Top 2 Generi dell'utente
    final sortedGenres = tasteProfile.genrePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedGenres.take(2)) {
      final gId = AppConfig.getGenreIdByName(entry.key);
      if (gId != null) {
        try {
          final discovered = await _tmdbClient.discoverMovies(
            withGenres: [gId],
            minVote: 7.2,
            minVoteCount: 200,
          );
          for (final m in discovered) {
            if (!_isMovieExcluded(m, watchedTitles)) {
              candidates[m.id] = m;
              candidateSeedReason.putIfAbsent(
                m.id,
                () => '✦ Corrisponde alla tua passione per il genere ${entry.key} (${entry.value}%)',
              );
            }
          }
        } catch (_) {}
      }
    }

    // 5. CANALE 4: Se abbiamo ancora pochi candidati, aggiungi film di qualità acclamati
    if (candidates.length < 15) {
      final topRated = await _tmdbClient.getTopRatedMovies();
      for (final m in topRated) {
        if (!_isMovieExcluded(m, watchedTitles)) {
          candidates[m.id] = m;
          candidateSeedReason.putIfAbsent(m.id, () => '✦ Tra i capolavori più votati della storia del cinema');
        }
      }
    }

    // 6. DETTAGLI COMPLETI, PROVIDER E SCORING
    final candidateList = candidates.values.take(35).toList();
    final List<TmdbMovie> detailedCandidates = [];

    // Fetch dettagli in batch controllati
    const int detailBatchSize = 6;
    for (int i = 0; i < candidateList.length; i += detailBatchSize) {
      final batch = candidateList.sublist(i, min(i + detailBatchSize, candidateList.length));
      final batchResults = await Future.wait(
        batch.map((cand) async {
          try {
            return await _tmdbClient.getMovieDetails(cand.id, countryCode: countryCode) ?? cand;
          } catch (_) {
            return cand;
          }
        }),
      );
      detailedCandidates.addAll(batchResults);
      await Future.delayed(const Duration(milliseconds: 25));
    }

    final List<TmdbMovie> scoredList = [];

    for (final full in detailedCandidates) {
      final availableFlatrate = full
          .flatrateProviders(countryCode)
          .map((p) => p.providerName.toLowerCase())
          .toList();

      // Filtro streaming: se l'utente ha impostato piattaforme, verifica la disponibilità
      if (requiredProviders.isNotEmpty) {
        final hasMatch = requiredProviders.any((req) =>
            availableFlatrate.any((avail) => avail.contains(req.toLowerCase())));

        if (!hasMatch) {
          continue; // Salta se non presente negli abbonamenti dell'utente
        }
      }

      // CALCOLO DELLO SCORE DI AFFINITÀ PERSONALIZZATO (0 - 100%)
      double score = 0.0;
      final List<String> reasons = [];

      // Reason seme o discover originaria
      if (candidateSeedReason.containsKey(full.id)) {
        reasons.add(candidateSeedReason[full.id]!);
      }

      // A. Match Generi (fino a 40 punti)
      double genrePoints = 0.0;
      for (final gId in full.genreIds) {
        final gName = AppConfig.genreMap[gId];
        if (gName != null && tasteProfile.genrePercentages.containsKey(gName)) {
          final pct = tasteProfile.genrePercentages[gName]!;
          genrePoints += (pct * 0.40);
        }
      }
      genrePoints = min(40.0, genrePoints);
      score += genrePoints;

      // B. Regista ricorrente preferito (bonus 15 punti)
      if (full.director != null && tasteProfile.topDirectors.contains(full.director)) {
        score += 15.0;
        reasons.add('✦ Diretto da ${full.director}, uno dei tuoi registi preferiti');
      }

      // C. Voto critico TMDb e Rotten Tomatoes (fino a 18 punti)
      final votePoints = (full.voteAverage / 10.0) * 14.0;
      score += votePoints;

      if (full.rottenTomatoesScore != null) {
        final rt = int.tryParse(full.rottenTomatoesScore!.replaceAll('%', ''));
        if (rt != null && rt >= 80) {
          score += 4.0;
          reasons.add('✦ Certificato Fresh su Rotten Tomatoes (${full.rottenTomatoesScore})');
        }
      }

      // D. Presenza in Watchlist (+20 punti)
      final isWatchlist = watchlistTitles.contains(_normalizeTitle(full.title)) ||
          full.isInUserWatchlist;
      if (isWatchlist) {
        score += 20.0;
      }

      // E. Disponibilità su provider attivo (+8 punti)
      if (availableFlatrate.isNotEmpty) {
        score += 8.0;
        final names = full.flatrateProviders(countryCode).take(2).map((p) => p.providerName).join(', ');
        reasons.add('✦ Disponibile con il tuo abbonamento su $names');
      }

      // Normalizzazione finale cinematografica tra 75% e 99%
      final finalScore = min(99.0, max(75.0, score));

      scoredList.add(
        full.copyWith(
          matchScore: double.parse(finalScore.toStringAsFixed(1)),
          matchReasons: reasons.toSet().toList(), // Evita duplicati
          isInUserWatchlist: isWatchlist,
        ),
      );
    }

    // Ordina dal punteggio di affinità più alto al più basso
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
