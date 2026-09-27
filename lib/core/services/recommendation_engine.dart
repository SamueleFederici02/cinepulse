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

  // Mappatura cinefila istantanea per registi iconici dai titoli classici
  static final Map<String, String> _knownAuteurMap = {
    'pulp-fiction': 'Quentin Tarantino',
    'django-unchained': 'Quentin Tarantino',
    'inglourious-basterds': 'Quentin Tarantino',
    'kill-bill-vol-1': 'Quentin Tarantino',
    'kill-bill-vol-2': 'Quentin Tarantino',
    'reservoir-dogs': 'Quentin Tarantino',
    'the-hateful-eight': 'Quentin Tarantino',
    'once-upon-a-time-in-hollywood': 'Quentin Tarantino',
    'jackie-brown': 'Quentin Tarantino',
    'death-proof': 'Quentin Tarantino',
    '2001-a-space-odyssey': 'Stanley Kubrick',
    'the-shining': 'Stanley Kubrick',
    'a-clockwork-orange': 'Stanley Kubrick',
    'full-metal-jacket': 'Stanley Kubrick',
    'eyes-wide-shut': 'Stanley Kubrick',
    'barry-lyndon': 'Stanley Kubrick',
    'dr-strangelove': 'Stanley Kubrick',
    'paths-of-glory': 'Stanley Kubrick',
    'spartacus': 'Stanley Kubrick',
    'lolita': 'Stanley Kubrick',
    'oppenheimer': 'Christopher Nolan',
    'interstellar': 'Christopher Nolan',
    'inception': 'Christopher Nolan',
    'the-dark-knight': 'Christopher Nolan',
    'memento': 'Christopher Nolan',
    'the-prestige': 'Christopher Nolan',
    'dunkirk': 'Christopher Nolan',
    'tenet': 'Christopher Nolan',
    'dune-part-two': 'Denis Villeneuve',
    'dune': 'Denis Villeneuve',
    'blade-runner-2049': 'Denis Villeneuve',
    'arrival': 'Denis Villeneuve',
    'sicario': 'Denis Villeneuve',
    'prisoners': 'Denis Villeneuve',
    'incendies': 'Denis Villeneuve',
    'taxi-driver': 'Martin Scorsese',
    'goodfellas': 'Martin Scorsese',
    'the-departed': 'Martin Scorsese',
    'the-wolf-of-wall-street': 'Martin Scorsese',
    'shutter-island': 'Martin Scorsese',
    'casino': 'Martin Scorsese',
    'raging-bull': 'Martin Scorsese',
    'killers-of-the-flower-moon': 'Martin Scorsese',
    'fight-club': 'David Fincher',
    'se7en': 'David Fincher',
    'zodiac': 'David Fincher',
    'the-social-network': 'David Fincher',
    'gone-girl': 'David Fincher',
    'parasite': 'Bong Joon-ho',
    'memories-of-murder': 'Bong Joon-ho',
    'snowpiercer': 'Bong Joon-ho',
    'spirited-away': 'Hayao Miyazaki',
    'princess-mononoke': 'Hayao Miyazaki',
    'howls-moving-castle': 'Hayao Miyazaki',
  };

  /// Calcola il moltiplicatore temporale per premiare i trend recenti rispetto al passato
  double _calculateRecencyMultiplier(DateTime? date, int index, int total) {
    if (date != null) {
      final daysAgo = DateTime.now().difference(date).inDays;
      if (daysAgo <= 90) return 2.6; // Ultimi 3 mesi (trend recentissimo)
      if (daysAgo <= 180) return 2.0; // Ultimi 6 mesi
      if (daysAgo <= 365) return 1.5; // Ultimo anno
      if (daysAgo <= 730) return 1.0; // Ultimi 2 anni
      return 0.55; // Visto più di 2 anni fa (decadimento temporale)
    }

    // Se la data manca, stimiamo dalla posizione nell'elenco (i primi sono i più recenti)
    final relPos = index / max(1, total);
    if (relPos < 0.20) return 2.0;
    if (relPos < 0.50) return 1.3;
    return 0.65;
  }

  /// Calcola il profilo statistico profondo dell'utente ponderando cronologia e preferenze
  Future<TasteProfile> buildTasteProfile(
    String username,
    List<LetterboxdMovie> userMovies,
  ) async {
    final Map<String, int> genreCounts = {};
    final Map<String, double> genreWeightedScore = {};
    final Map<String, double> directorScores = {};

    int totalWatched = 0;
    int totalRated = 0;
    int totalInWatchlist = 0;
    double ratingSum = 0.0;

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

      // Check immediato di registi iconici dai titoli per non perdere autori amati (Tarantino, Kubrick, ecc.)
      final normSlug = movie.slug.toLowerCase().replaceAll(RegExp(r'-\d{4}$'), '');
      if (_knownAuteurMap.containsKey(normSlug)) {
        final director = _knownAuteurMap[normSlug]!;
        double dWeight = (movie.rating ?? 3.5) / 5.0 * 2.0;
        if (movie.isLiked) dWeight += 1.0;
        directorScores[director] = (directorScores[director] ?? 0.0) + dWeight;
      }
    }

    // Ordiniamo i film per data di visione (più recenti prima) per catturare il trend reale
    final sortedByDate = List<LetterboxdMovie>.from(userMovies)
      ..sort((a, b) {
        if (a.watchedDate != null && b.watchedDate != null) {
          return b.watchedDate!.compareTo(a.watchedDate!);
        }
        if (a.watchedDate != null) return -1;
        if (b.watchedDate != null) return 1;
        return 0;
      });

    // Selezioniamo un campione intelligente che include:
    // A) Film visti di recente (trend attuale)
    // B) Film con i voti più alti (5★ e 4.5★)
    // C) Film a cui ha messo il cuoricino
    final recentWatched = sortedByDate.where((m) => !m.isInWatchlist).take(20).toList();
    final topRated = userMovies.where((m) => (m.rating != null && m.rating! >= 4.0) || m.isLiked).toList();

    final Set<String> addedSlugs = {};
    final List<LetterboxdMovie> sampleMovies = [];

    for (final m in [...recentWatched, ...topRated]) {
      if (!addedSlugs.contains(m.slug)) {
        addedSlugs.add(m.slug);
        sampleMovies.add(m);
        if (sampleMovies.length >= 45) break;
      }
    }

    // Processamento a blocchi controllati su TMDb
    const int batchSize = 6;
    for (int i = 0; i < sampleMovies.length; i += batchSize) {
      final batch = sampleMovies.sublist(i, min(i + batchSize, sampleMovies.length));

      await Future.wait(
        batch.map((movie) async {
          try {
            // Moltiplicatore di voto base
            double baseMultiplier = 1.0;
            if (movie.rating != null) {
              if (movie.rating! >= 4.75) {
                baseMultiplier = 3.5;
              } else if (movie.rating! >= 4.25) {
                baseMultiplier = 2.8;
              } else if (movie.rating! >= 3.75) {
                baseMultiplier = 2.0;
              } else if (movie.rating! >= 3.25) {
                baseMultiplier = 1.3;
              } else {
                baseMultiplier = 0.5;
              }
            }
            if (movie.isLiked) baseMultiplier += 1.0;

            // PONDERAZIONE CRONOLOGICA / TREND TEMPORALE
            final recency = _calculateRecencyMultiplier(
              movie.watchedDate,
              sampleMovies.indexOf(movie),
              sampleMovies.length,
            );
            final finalWeight = baseMultiplier * recency;

            var tmdbInfo = await _tmdbClient.searchMovie(movie.title, year: movie.year);
            tmdbInfo ??= await _tmdbClient.searchMovie(movie.title);

            if (tmdbInfo != null) {
              // Estrazione generi
              for (final gId in tmdbInfo.genreIds) {
                final gName = AppConfig.genreMap[gId] ?? 'Altro';
                genreCounts[gName] = (genreCounts[gName] ?? 0) + 1;
                genreWeightedScore[gName] = (genreWeightedScore[gName] ?? 0.0) + finalWeight;
              }

              // Per i film con voto alto, verifichiamo anche il regista da TMDb credits
              if ((movie.rating != null && movie.rating! >= 4.0) || movie.isLiked) {
                try {
                  final details = await _tmdbClient.getMovieDetails(tmdbInfo.id);
                  if (details?.director != null && details!.director!.isNotEmpty) {
                    directorScores[details.director!] =
                        (directorScores[details.director!] ?? 0.0) + finalWeight;
                  }
                } catch (_) {}
              }
            }
          } catch (e) {
            debugPrint('Errore analisi film ${movie.title}: $e');
          }
        }),
      );

      await Future.delayed(const Duration(milliseconds: 30));
    }

    // Calcolo percentuali di frequenza generi pesate con trend temporale
    final double totalScore = genreWeightedScore.values.fold(0.0, (a, b) => a + b);
    final Map<String, double> genrePercentages = {};

    if (totalScore > 0) {
      genreWeightedScore.forEach((genre, score) {
        final pct = (score / totalScore) * 100.0;
        genrePercentages[genre] = double.parse(pct.toStringAsFixed(1));
      });
    } else {
      // Fallback cinefilo bilanciato incentrato sui gusti dell'utente
      genrePercentages['Drammatico'] = 32.0;
      genrePercentages['Commedia'] = 24.0;
      genrePercentages['Avventura'] = 22.0;
      genrePercentages['Thriller'] = 14.0;
      genrePercentages['Azione'] = 8.0;
    }

    // Top registi ordinati per punteggio pesato
    final sortedDirectors = directorScores.entries.toList()
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

  /// Genera le raccomandazioni cinematografiche intelligenti on-device con bilanciamento dinamico
  Future<List<TmdbMovie>> generateRecommendations({
    required List<LetterboxdMovie> userMovies,
    required TasteProfile tasteProfile,
    required String countryCode,
    List<String> requiredProviders = const [],
    int maxResults = 25,
  }) async {
    // 1. Set dei titoli visti per esclusione assoluta
    final Set<String> watchedTitles = userMovies
        .where((m) => !m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Set<String> watchlistTitles = userMovies
        .where((m) => m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Map<int, TmdbMovie> candidates = {};
    final Map<int, String> candidateReasons = {};

    // 2. CANALE REGISTI AMATI (Tarantino, Kubrick, ecc.)
    // Se l'utente ha registi preferiti, cerchiamo film diretti da loro non ancora visti
    for (final director in tasteProfile.topDirectors.take(3)) {
      try {
        final directorMovies = await _tmdbClient.getMoviesByDirector(director);
        for (final m in directorMovies.take(6)) {
          if (!_isMovieExcluded(m, watchedTitles)) {
            candidates[m.id] = m;
            candidateReasons[m.id] = '✦ Diretto da $director, uno dei tuoi registi preferiti!';
          }
        }
      } catch (_) {}
    }

    // 3. CANALE FILM SEME DIVERSIFICATI (Non un solo film, ma generi diversi!)
    // Troviamo i film migliori per generi diversi (1 Dramma, 1 Avventura, 1 Commedia, 1 Thriller, ecc.)
    final highRated = userMovies.where((m) => (m.rating != null && m.rating! >= 4.0) || m.isLiked).toList();
    
    // Ordiniamo per data recente per privilegiare il trend attuale
    highRated.sort((a, b) {
      if (a.watchedDate != null && b.watchedDate != null) {
        return b.watchedDate!.compareTo(a.watchedDate!);
      }
      return 0;
    });

    final List<LetterboxdMovie> diverseSeeds = [];
    final Set<String> pickedSeedTitles = {};

    for (final m in highRated) {
      if (!pickedSeedTitles.contains(m.title)) {
        pickedSeedTitles.add(m.title);
        diverseSeeds.add(m);
        if (diverseSeeds.length >= 5) break;
      }
    }

    // Per ciascun film seme estraiamo AL MASSIMO 3 raccomandazioni (evita che 1 solo film inondi i consigli)
    for (final seed in diverseSeeds) {
      try {
        final searchResult = await _tmdbClient.searchMovie(seed.title, year: seed.year);
        if (searchResult != null) {
          final recs = await _tmdbClient.getRecommendations(searchResult.id);
          int addedFromThisSeed = 0;
          for (final m in recs) {
            if (!_isMovieExcluded(m, watchedTitles) && !candidates.containsKey(m.id)) {
              candidates[m.id] = m;
              candidateReasons[m.id] = '✦ Ispirato dal tuo gradimento per "${seed.title}"';
              addedFromThisSeed++;
              if (addedFromThisSeed >= 3) break; // TETTO MASSIMO DI 3 FILM PER SEME!
            }
          }
        }
      } catch (_) {}
    }

    // 4. CANALE DISCOVER SUI TOP GENERI DI TENDENZA ATTUALE (es. Drammatico, Avventura, Commedia)
    final sortedGenres = tasteProfile.genrePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedGenres.take(3)) {
      final gId = AppConfig.getGenreIdByName(entry.key);
      if (gId != null) {
        try {
          final discovered = await _tmdbClient.discoverMovies(
            withGenres: [gId],
            minVote: 7.2,
            minVoteCount: 200,
          );
          int addedFromGenre = 0;
          for (final m in discovered) {
            if (!_isMovieExcluded(m, watchedTitles) && !candidates.containsKey(m.id)) {
              candidates[m.id] = m;
              candidateReasons[m.id] = '✦ Perfetto per il tuo amore per ${entry.key} (${entry.value}% dei tuoi gusti)';
              addedFromGenre++;
              if (addedFromGenre >= 5) break;
            }
          }
        } catch (_) {}
      }
    }

    // 5. CANALE WATCHLIST LETTERBOXD DELL'UTENTE
    final watchlistCandidates = userMovies.where((m) => m.isInWatchlist).take(8).toList();
    for (final w in watchlistCandidates) {
      try {
        final wInfo = await _tmdbClient.searchMovie(w.title, year: w.year);
        if (wInfo != null && !_isMovieExcluded(wInfo, watchedTitles)) {
          candidates[wInfo.id] = wInfo.copyWith(isInUserWatchlist: true);
          candidateReasons[wInfo.id] = '✦ Dalla tua Watchlist di Letterboxd!';
        }
      } catch (_) {}
    }

    // 6. DETTAGLI COMPLETI, RATING RT E FILTER PROVIDER
    final candidateList = candidates.values.toList();
    final List<TmdbMovie> detailedCandidates = [];

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

      if (requiredProviders.isNotEmpty) {
        final hasMatch = requiredProviders.any((req) =>
            availableFlatrate.any((avail) => avail.contains(req.toLowerCase())));
        if (!hasMatch) continue;
      }

      // SCORING DINAMICO DELL'AFFINITÀ
      double score = 52.0;
      final List<String> reasons = [];

      if (candidateReasons.containsKey(full.id)) {
        score += 6.0;
        reasons.add(candidateReasons[full.id]!);
      }

      // Match Generi con la curva attuale
      double genrePoints = 0.0;
      for (final gId in full.genreIds) {
        final gName = AppConfig.genreMap[gId];
        if (gName != null && tasteProfile.genrePercentages.containsKey(gName)) {
          final pct = tasteProfile.genrePercentages[gName]!;
          genrePoints += (pct * 0.30);
          if (tasteProfile.topGenres.take(3).contains(gName)) {
            genrePoints += 5.0;
          }
        }
      }
      score += min(26.0, genrePoints);

      // Regista ricorrente o amato (bonus fino a 16 punti)
      if (full.director != null && tasteProfile.topDirectors.contains(full.director)) {
        score += 16.0;
        reasons.add('✦ Diretto da ${full.director}');
      }

      // Voto critico TMDb & Rotten Tomatoes
      score += ((full.voteAverage - 5.0).clamp(0.0, 5.0) * 1.8);
      if (full.rottenTomatoesScore != null) {
        final rt = int.tryParse(full.rottenTomatoesScore!.replaceAll('%', ''));
        if (rt != null && rt >= 80) {
          score += 4.0;
          reasons.add('✦ Rotten Tomatoes ${full.rottenTomatoesScore}');
        }
      }

      // Bonus Watchlist
      final isWatchlist = watchlistTitles.contains(_normalizeTitle(full.title)) || full.isInUserWatchlist;
      if (isWatchlist) {
        score += 8.0;
      }

      // Bonus Streaming Provider
      if (availableFlatrate.isNotEmpty) {
        score += 4.0;
        final names = full.flatrateProviders(countryCode).take(2).map((p) => p.providerName).join(', ');
        reasons.add('✦ Disponibile in streaming su $names');
      }

      final finalScore = score.clamp(52.0, 99.0);

      scoredList.add(
        full.copyWith(
          matchScore: double.parse(finalScore.toStringAsFixed(1)),
          matchReasons: reasons.toSet().toList(),
          isInUserWatchlist: isWatchlist,
        ),
      );
    }

    // 7. BILANCIAMENTO FINALE E DIVERSIFICAZIONE (TETTO PER GENERE)
    // Nessun genere (es. Romantico) può monopolizzare più del 20% della lista!
    scoredList.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    final Map<int, int> genreCountsInFeed = {};
    final List<TmdbMovie> diverseFeed = [];

    for (final movie in scoredList) {
      // Se è il genere Romance (ID 10749) e ne abbiamo già inseriti 2, saltiamo a meno che non sia in watchlist
      bool isOverRepresented = false;
      for (final gId in movie.genreIds) {
        final currentCount = genreCountsInFeed[gId] ?? 0;
        // Tetto di max 5 film per generi secondari, max 8 per generi primari
        if (gId == 10749 && currentCount >= 2 && !movie.isInUserWatchlist) {
          isOverRepresented = true;
          break;
        }
        if (currentCount >= 6 && !movie.isInUserWatchlist) {
          isOverRepresented = true;
          break;
        }
      }

      if (!isOverRepresented || diverseFeed.length < 10) {
        diverseFeed.add(movie);
        for (final gId in movie.genreIds) {
          genreCountsInFeed[gId] = (genreCountsInFeed[gId] ?? 0) + 1;
        }
      }

      if (diverseFeed.length >= maxResults) break;
    }

    return diverseFeed.isNotEmpty ? diverseFeed : scoredList.take(maxResults).toList();
  }

  /// Genera raccomandazioni successive per lo scroll infinito con apprendimento real-time
  Future<List<TmdbMovie>> generateNextPageRecommendations({
    required List<LetterboxdMovie> userMovies,
    required TasteProfile tasteProfile,
    required String countryCode,
    required int page,
    required Set<int> alreadyRecommendedIds,
    Map<int, double> realtimeGenreBoost = const {},
    Map<int, double> realtimeGenrePenalty = const {},
    List<String> requiredProviders = const [],
    int maxResults = 18,
  }) async {
    final Set<String> watchedTitles = userMovies
        .where((m) => !m.isInWatchlist)
        .map((m) => _normalizeTitle(m.title))
        .toSet();

    final Map<int, TmdbMovie> candidates = {};
    final Map<int, String> candidateReasons = {};

    // 1. Discover TMDb sulla pagina successiva per i generi preferiti o boosted
    final sortedGenres = tasteProfile.genrePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Se un genere è stato boostato in tempo reale (per swipe right), lo includiamo
    List<int> targetGenres = [];
    realtimeGenreBoost.forEach((gId, boost) {
      if (boost > 0 && !targetGenres.contains(gId)) {
        targetGenres.add(gId);
      }
    });

    for (final entry in sortedGenres.take(3)) {
      final gId = AppConfig.getGenreIdByName(entry.key);
      if (gId != null && !targetGenres.contains(gId)) {
        targetGenres.add(gId);
      }
    }

    for (final gId in targetGenres.take(3)) {
      if ((realtimeGenrePenalty[gId] ?? 0.0) >= 3.0) continue;

      try {
        final discovered = await _tmdbClient.discoverMovies(
          withGenres: [gId],
          minVote: 6.9,
          minVoteCount: 150,
          page: page,
        );
        for (final m in discovered) {
          if (!alreadyRecommendedIds.contains(m.id) &&
              !_isMovieExcluded(m, watchedTitles) &&
              !candidates.containsKey(m.id)) {
            candidates[m.id] = m;
            final gName = AppConfig.genreMap[gId] ?? 'Cinema';
            candidateReasons[m.id] = (realtimeGenreBoost[gId] ?? 0) > 0
                ? '✦ Basato sui tuoi recenti film aggiunti in Watchlist ($gName)'
                : '✦ Dal catalogo d\'eccellenza per $gName';
            if (candidates.length >= 25) break;
          }
        }
      } catch (_) {}
    }

    if (candidates.length < 10) {
      try {
        final pop = await _tmdbClient.getPopularMovies(page: page);
        for (final m in pop) {
          if (!alreadyRecommendedIds.contains(m.id) &&
              !_isMovieExcluded(m, watchedTitles) &&
              !candidates.containsKey(m.id)) {
            candidates[m.id] = m;
            candidateReasons[m.id] = '✦ Tra i film più visti e popolari';
          }
        }
      } catch (_) {}
    }

    final candidateList = candidates.values.toList();
    final List<TmdbMovie> detailed = [];
    const int bSize = 6;
    for (int i = 0; i < candidateList.length; i += bSize) {
      final b = candidateList.sublist(i, min(i + bSize, candidateList.length));
      final res = await Future.wait(
        b.map((c) async {
          try {
            return await _tmdbClient.getMovieDetails(c.id, countryCode: countryCode) ?? c;
          } catch (_) {
            return c;
          }
        }),
      );
      detailed.addAll(res);
      await Future.delayed(const Duration(milliseconds: 25));
    }

    final List<TmdbMovie> scored = [];
    for (final full in detailed) {
      final availableFlatrate = full
          .flatrateProviders(countryCode)
          .map((p) => p.providerName.toLowerCase())
          .toList();

      if (requiredProviders.isNotEmpty) {
        final hasMatch = requiredProviders.any((req) =>
            availableFlatrate.any((avail) => avail.contains(req.toLowerCase())));
        if (!hasMatch) continue;
      }

      double score = 52.0;
      final List<String> reasons = [];
      if (candidateReasons.containsKey(full.id)) {
        score += 6.0;
        reasons.add(candidateReasons[full.id]!);
      }

      for (final gId in full.genreIds) {
        final gName = AppConfig.genreMap[gId];
        if (gName != null && tasteProfile.genrePercentages.containsKey(gName)) {
          score += (tasteProfile.genrePercentages[gName]! * 0.28);
          if (tasteProfile.topGenres.take(3).contains(gName)) {
            score += 5.0;
          }
        }
        if (realtimeGenreBoost.containsKey(gId)) {
          score += realtimeGenreBoost[gId]! * 4.0;
        }
        if (realtimeGenrePenalty.containsKey(gId)) {
          score -= realtimeGenrePenalty[gId]! * 5.0;
        }
      }

      if (full.director != null && tasteProfile.topDirectors.contains(full.director)) {
        score += 16.0;
        reasons.add('✦ Diretto da ${full.director}');
      }

      score += ((full.voteAverage - 5.0).clamp(0.0, 5.0) * 1.8);

      if (availableFlatrate.isNotEmpty) {
        score += 4.0;
        final names = full.flatrateProviders(countryCode).take(2).map((p) => p.providerName).join(', ');
        reasons.add('✦ Disponibile in streaming su $names');
      }

      final finalScore = score.clamp(50.0, 99.0);
      scored.add(
        full.copyWith(
          matchScore: double.parse(finalScore.toStringAsFixed(1)),
          matchReasons: reasons.toSet().toList(),
        ),
      );
    }

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return scored.take(maxResults).toList();
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
