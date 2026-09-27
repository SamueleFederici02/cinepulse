import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/tmdb_movie.dart';
import '../models/watch_provider.dart';

class TmdbClient {
  late final Dio _dio;
  late final Dio _omdbDio;
  final Map<String, dynamic> _memoryCache = {};

  TmdbClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.tmdbBaseUrl,
        queryParameters: {
          'api_key': AppConfig.tmdbApiKey,
          'language': 'it-IT',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _omdbDio = Dio(
      BaseOptions(
        baseUrl: 'https://www.omdbapi.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
  }

  // --- RICERCA FILM ---
  Future<TmdbMovie?> searchMovie(String title, {int? year}) async {
    final cacheKey = 'search_${title.toLowerCase()}_$year';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey] as TmdbMovie?;
    }

    try {
      final response = await _dio.get(
        '/search/movie',
        queryParameters: {
          'query': title,
          if (year != null) 'year': year,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final movie = TmdbMovie.fromJson(results.first);
        _memoryCache[cacheKey] = movie;
        return movie;
      }
    } catch (e) {
      debugPrint('Errore nella ricerca TMDb per "$title": $e');
    }
    return null;
  }

  // --- DETTAGLI COMPLETI + CREDITS + VIDEOS + EXTERNAL IDS + ROTTEN TOMATOES ---
  Future<TmdbMovie?> getMovieDetails(int movieId, {String countryCode = 'IT'}) async {
    final cacheKey = 'details_${movieId}_$countryCode';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey] as TmdbMovie?;
    }

    try {
      final response = await _dio.get(
        '/movie/$movieId',
        queryParameters: {
          'append_to_response': 'credits,videos,watch/providers,external_ids',
          'include_video_language': 'it,en,null',
        },
      );

      final data = response.data;
      var movie = TmdbMovie.fromJson(data);

      // Regista e Cast
      String? director;
      List<String> castList = [];
      if (data['credits'] != null) {
        final crew = data['credits']['crew'] as List?;
        if (crew != null) {
          final dir = crew.firstWhere(
            (c) => c['job'] == 'Director',
            orElse: () => null,
          );
          if (dir != null) {
            director = dir['name'];
          }
        }

        final cast = data['credits']['cast'] as List?;
        if (cast != null) {
          castList = cast
              .take(6)
              .map((c) => c['name']?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
        }
      }

      // Trailer YouTube (priorità trailer/teaser, poi qualsiasi video YouTube)
      String? trailerKey;
      if (data['videos'] != null && data['videos']['results'] != null) {
        final videos = data['videos']['results'] as List;
        final ytTrailer = videos.firstWhere(
          (v) =>
              v['site'] == 'YouTube' &&
              (v['type'] == 'Trailer' || v['type'] == 'Teaser'),
          orElse: () => null,
        );
        if (ytTrailer != null) {
          trailerKey = ytTrailer['key'];
        } else {
          final anyYt = videos.firstWhere(
            (v) => v['site'] == 'YouTube' && v['key'] != null,
            orElse: () => null,
          );
          if (anyYt != null) {
            trailerKey = anyYt['key'];
          }
        }
      }

      // Watch Providers per Tutte le Nazioni
      final Map<String, List<WatchProvider>> providersMap = {};
      if (data['watch/providers'] != null &&
          data['watch/providers']['results'] != null) {
        final results = data['watch/providers']['results'] as Map<String, dynamic>;

        results.forEach((country, countryData) {
          final List<WatchProvider> list = [];
          if (countryData['flatrate'] != null) {
            for (final p in countryData['flatrate']) {
              list.add(WatchProvider.fromJson(p, type: 'flatrate'));
            }
          }
          if (countryData['free'] != null) {
            for (final p in countryData['free']) {
              list.add(WatchProvider.fromJson(p, type: 'free'));
            }
          }
          if (countryData['rent'] != null) {
            for (final p in countryData['rent']) {
              list.add(WatchProvider.fromJson(p, type: 'rent'));
            }
          }
          if (countryData['buy'] != null) {
            for (final p in countryData['buy']) {
              list.add(WatchProvider.fromJson(p, type: 'buy'));
            }
          }
          providersMap[country.toUpperCase()] = list;
        });
      }

      // Recupero Rotten Tomatoes, Metacritic, IMDb tramite external_ids
      String? rottenTomatoes;
      String? imdb;
      String? metacritic;
      final imdbId = data['external_ids']?['imdb_id'];

      if (imdbId != null && imdbId.toString().isNotEmpty) {
        try {
          final omdbRes = await _omdbDio.get(
            '',
            queryParameters: {
              'i': imdbId,
              'apikey': AppConfig.omdbApiKey,
            },
          );

          if (omdbRes.statusCode == 200 && omdbRes.data != null) {
            final ratings = omdbRes.data['Ratings'] as List?;
            if (ratings != null) {
              for (final r in ratings) {
                final source = r['Source']?.toString() ?? '';
                final val = r['Value']?.toString() ?? '';
                if (source.contains('Rotten Tomatoes')) {
                  rottenTomatoes = val;
                } else if (source.contains('Metacritic')) {
                  metacritic = val;
                }
              }
            }
            final omdbImdb = omdbRes.data['imdbRating']?.toString();
            if (omdbImdb != null && omdbImdb != 'N/A') {
              imdb = omdbImdb;
            }
          }
        } catch (e) {
          debugPrint('OMDb rating non disponibile per $imdbId: $e');
        }
      }

      // Stima / Formattazione Letterboxd Score (in scala 5 stelle con 1 decimale)
      final letterboxdRating = (movie.voteAverage / 2.0).clamp(1.0, 5.0).toStringAsFixed(1);

      movie = movie.copyWith(
        director: director,
        cast: castList,
        trailerKey: trailerKey,
        watchProviders: providersMap,
        rottenTomatoesScore: rottenTomatoes,
        letterboxdScore: letterboxdRating,
        imdbScore: imdb ?? (movie.voteAverage > 0 ? movie.voteAverage.toStringAsFixed(1) : null),
        metacriticScore: metacritic,
      );

      _memoryCache[cacheKey] = movie;
      return movie;
    } catch (e) {
      debugPrint('Errore nel recupero dettagli TMDb per ID $movieId: $e');
      return null;
    }
  }

  // --- ULTIMI USCITI (Now Playing al cinema e streaming) ---
  Future<List<TmdbMovie>> getNowPlayingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/now_playing',
        queryParameters: {'page': page},
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore getNowPlayingMovies TMDb: $e');
    }
    return [];
  }

  // --- PIÙ VOTATI DI SEMPRE (Top Rated) ---
  Future<List<TmdbMovie>> getTopRatedMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/top_rated',
        queryParameters: {'page': page},
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore getTopRatedMovies TMDb: $e');
    }
    return [];
  }

  // --- POPOLARI ---
  Future<List<TmdbMovie>> getPopularMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/popular',
        queryParameters: {'page': page},
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore getPopularMovies TMDb: $e');
    }
    return [];
  }

  // --- RACCOMANDAZIONI TMDb ---
  Future<List<TmdbMovie>> getRecommendations(int movieId) async {
    try {
      final response = await _dio.get('/movie/$movieId/recommendations');
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore recommendations per $movieId: $e');
    }
    return [];
  }

  // --- FILM SIMILI TMDb ---
  Future<List<TmdbMovie>> getSimilarMovies(int movieId) async {
    try {
      final response = await _dio.get('/movie/$movieId/similar');
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore similar per $movieId: $e');
    }
    return [];
  }

  // --- DISCOVER FILM ---
  Future<List<TmdbMovie>> discoverMovies({
    List<int>? withGenres,
    String? withCast,
    double minVote = 6.8,
    int minVoteCount = 120,
    int page = 1,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'sort_by': 'popularity.desc',
        'vote_average.gte': minVote,
        'vote_count.gte': minVoteCount,
        'page': page,
        'include_adult': false,
      };

      if (withGenres != null && withGenres.isNotEmpty) {
        params['with_genres'] = withGenres.join(',');
      }
      if (withCast != null && withCast.isNotEmpty) {
        params['with_cast'] = withCast;
      }

      final response = await _dio.get('/discover/movie', queryParameters: params);
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore discoverMovies TMDb: $e');
    }
    return [];
  }

  // --- TRENDING DELLA SETTIMANA ---
  Future<List<TmdbMovie>> getTrending() async {
    try {
      final response = await _dio.get('/trending/movie/week');
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore getTrending TMDb: $e');
    }
    return [];
  }

  // --- FILM IN USCITA PROSSIMAMENTE (BLOCKBUSTER E NUOVI ARRIVI) ---
  Future<List<TmdbMovie>> getUpcomingMovies({int page = 1, String countryCode = 'IT'}) async {
    final cacheKey = 'upcoming_${countryCode}_$page';
    if (_memoryCache.containsKey(cacheKey)) {
      return (_memoryCache[cacheKey] as List).cast<TmdbMovie>();
    }
    try {
      final response = await _dio.get(
        '/movie/upcoming',
        queryParameters: {
          'page': page,
          'region': countryCode.toUpperCase(),
        },
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        final list = results.map((m) => TmdbMovie.fromJson(m)).toList();
        _memoryCache[cacheKey] = list;
        return list;
      }
    } catch (e) {
      debugPrint('Errore getUpcomingMovies TMDb: $e');
    }
    return [];
  }

  // --- RICERCA MULTIPLA FILM PER TITOLO (SEARCH COMPLETO) ---
  Future<List<TmdbMovie>> searchMoviesList(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _dio.get(
        '/search/movie',
        queryParameters: {
          'query': query.trim(),
          'page': page,
          'include_adult': false,
        },
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        return results.map((m) => TmdbMovie.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Errore searchMoviesList TMDb: $e');
    }
    return [];
  }

  // --- FILM DIRETTO DA UN REGISTA SPECIFICO ---
  Future<List<TmdbMovie>> getMoviesByDirector(String directorName) async {
    final cacheKey = 'director_films_${directorName.toLowerCase().replaceAll(' ', '_')}';
    if (_memoryCache.containsKey(cacheKey)) {
      return (_memoryCache[cacheKey] as List).cast<TmdbMovie>();
    }

    try {
      final res = await _dio.get(
        '/search/person',
        queryParameters: {'query': directorName},
      );
      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final personId = results.first['id'];
        final creditsRes = await _dio.get('/person/$personId/movie_credits');
        final crew = creditsRes.data['crew'] as List?;
        if (crew != null) {
          final directed = crew
              .where((c) => c['job'] == 'Director')
              .map((m) => TmdbMovie.fromJson(m))
              .toList();
          directed.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
          _memoryCache[cacheKey] = directed;
          return directed;
        }
      }
    } catch (e) {
      debugPrint('Errore getMoviesByDirector per $directorName: $e');
    }
    return [];
  }

  // --- CATALOGO PROVIDER STREAMING PER NAZIONE (ORDINATO ALFABETICAMENTE CON LOGHI) ---
  Future<List<Map<String, String>>> getWatchProvidersForCountry(String countryCode) async {
    final cacheKey = 'country_providers_${countryCode.toUpperCase()}';
    if (_memoryCache.containsKey(cacheKey)) {
      return (_memoryCache[cacheKey] as List).cast<Map<String, String>>();
    }

    final Map<String, String> providersMap = {};

    // 1. Inserisci i provider base noti
    final base = AppConfig.getKnownProvidersForCountry(countryCode);
    for (final p in base) {
      providersMap[p['name']!] = p['logo']!;
    }

    // 2. Chiamata API JustWatch/TMDb per recuperare tutti gli altri provider registrati nella nazione
    try {
      final response = await _dio.get(
        '/watch/providers/movie',
        queryParameters: {'watch_region': countryCode.toUpperCase()},
      );
      final results = response.data['results'] as List?;
      if (results != null) {
        for (final item in results) {
          final name = item['provider_name']?.toString() ?? '';
          final logo = item['logo_path']?.toString() ?? '';
          if (name.isNotEmpty && logo.isNotEmpty) {
            providersMap[name] = 'https://image.tmdb.org/t/p/w92$logo';
          }
        }
      }
    } catch (e) {
      debugPrint('Errore getWatchProvidersForCountry TMDb: $e');
    }

    // Ordina in ordine alfabetico (A-Z)
    final sortedList = providersMap.entries
        .map((e) => {'name': e.key, 'logo': e.value})
        .toList()
      ..sort((a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()));

    _memoryCache[cacheKey] = sortedList;
    return sortedList;
  }
}
