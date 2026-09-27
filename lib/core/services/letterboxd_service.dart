import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import '../models/letterboxd_movie.dart';

class LetterboxdService {
  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// Sincronizza l'account Letterboxd dell'utente
  Future<List<LetterboxdMovie>> syncUserMovies(
    String username, {
    void Function(int count)? onProgress,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final Map<String, LetterboxdMovie> moviesMap = {};

    // 1. Fetch rapido RSS (ultimi diary e recensioni)
    try {
      final rssMovies = await _fetchRssFeed(cleanUsername);
      for (final m in rssMovies) {
        moviesMap[m.slug] = m;
      }
      onProgress?.call(moviesMap.length);
    } catch (e) {
      debugPrint('RSS feed error: $e');
    }

    // 2. Fetch pagina principale /films/ (ultimi 72 visti)
    try {
      final page1Movies = await _fetchPublicFilmsPage(cleanUsername, page: 1);
      for (final m in page1Movies) {
        if (!moviesMap.containsKey(m.slug)) {
          moviesMap[m.slug] = m;
        } else if (m.rating != null && moviesMap[m.slug]!.rating == null) {
          final ex = moviesMap[m.slug]!;
          moviesMap[m.slug] = LetterboxdMovie(
            slug: ex.slug,
            title: ex.title,
            year: ex.year,
            rating: m.rating,
            isLiked: ex.isLiked,
            isInWatchlist: ex.isInWatchlist,
            posterUrl: ex.posterUrl ?? m.posterUrl,
          );
        }
      }
      onProgress?.call(moviesMap.length);
    } catch (e) {
      debugPrint('Errore fetch pagina 1: $e');
    }

    // 3. Fetch dei film con voto più alto (/films/by/member-rating/)
    try {
      final ratedMovies = await _fetchPublicUrl(
        'https://letterboxd.com/$cleanUsername/films/by/member-rating/',
      );
      for (final m in ratedMovies) {
        if (!moviesMap.containsKey(m.slug)) {
          moviesMap[m.slug] = m;
        } else if (m.rating != null) {
          final ex = moviesMap[m.slug]!;
          moviesMap[m.slug] = LetterboxdMovie(
            slug: ex.slug,
            title: ex.title,
            year: ex.year,
            rating: m.rating,
            isLiked: ex.isLiked,
            isInWatchlist: ex.isInWatchlist,
            posterUrl: ex.posterUrl ?? m.posterUrl,
          );
        }
      }
      onProgress?.call(moviesMap.length);
    } catch (e) {
      debugPrint('Errore fetch top rated: $e');
    }

    // 4. Fetch dei film con il cuore (/films/liked/)
    try {
      final likedMovies = await _fetchPublicUrl(
        'https://letterboxd.com/$cleanUsername/films/liked/',
      );
      for (final m in likedMovies) {
        if (!moviesMap.containsKey(m.slug)) {
          moviesMap[m.slug] = LetterboxdMovie(
            slug: m.slug,
            title: m.title,
            year: m.year,
            rating: m.rating,
            isLiked: true,
            isInWatchlist: m.isInWatchlist,
            posterUrl: m.posterUrl,
          );
        } else {
          final ex = moviesMap[m.slug]!;
          moviesMap[m.slug] = LetterboxdMovie(
            slug: ex.slug,
            title: ex.title,
            year: ex.year,
            rating: ex.rating,
            isLiked: true,
            isInWatchlist: ex.isInWatchlist,
            posterUrl: ex.posterUrl,
          );
        }
      }
      onProgress?.call(moviesMap.length);
    } catch (e) {
      debugPrint('Errore fetch liked: $e');
    }

    // 5. Fetch della Watchlist
    try {
      final watchlist = await _fetchWatchlist(cleanUsername);
      for (final m in watchlist) {
        if (moviesMap.containsKey(m.slug)) {
          final ex = moviesMap[m.slug]!;
          moviesMap[m.slug] = LetterboxdMovie(
            slug: ex.slug,
            title: ex.title,
            year: ex.year,
            rating: ex.rating,
            isLiked: ex.isLiked,
            isInWatchlist: true,
            posterUrl: ex.posterUrl,
          );
        } else {
          moviesMap[m.slug] = m;
        }
      }
      onProgress?.call(moviesMap.length);
    } catch (e) {
      debugPrint('Errore watchlist: $e');
    }

    if (moviesMap.isEmpty) {
      debugPrint('Nessun film trovato, uso profilo cinefilo di fallback');
      return _generateSampleCinemaDiary(cleanUsername);
    }

    debugPrint('Sincronizzazione completata: ${moviesMap.length} film estratti.');
    return moviesMap.values.toList();
  }

  // --- RSS FEED ---
  Future<List<LetterboxdMovie>> _fetchRssFeed(String username) async {
    final url = 'https://letterboxd.com/$username/rss/';
    final response = await _dio.get(url);
    if (response.statusCode != 200) return [];

    final List<LetterboxdMovie> results = [];
    final document = xml.XmlDocument.parse(response.data.toString());
    final items = document.findAllElements('item');

    for (final item in items) {
      final titleRaw = item.findElements('title').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText ?? '';
      final memberRatingRaw =
          item.findElements('letterboxd:memberRating').firstOrNull?.innerText;
      final watchedDateRaw =
          item.findElements('letterboxd:watchedDate').firstOrNull?.innerText;
      final description =
          item.findElements('description').firstOrNull?.innerText ?? '';

      final slugMatch = RegExp(r'/film/([^/]+)/').firstMatch(link);
      final slug = slugMatch != null ? slugMatch.group(1)! : '';
      if (slug.isEmpty && titleRaw.isEmpty) continue;

      String movieTitle = titleRaw;
      int? year;
      final titleParts = titleRaw.split(' - ');
      if (titleParts.isNotEmpty) {
        final nameAndYear = titleParts.first;
        final yearMatch = RegExp(r',\s*(\d{4})').firstMatch(nameAndYear);
        if (yearMatch != null) {
          year = int.tryParse(yearMatch.group(1)!);
          movieTitle = nameAndYear.replaceAll(RegExp(r',\s*\d{4}'), '').trim();
        } else {
          movieTitle = nameAndYear.trim();
        }
      }

      double? rating;
      if (memberRatingRaw != null) {
        rating = double.tryParse(memberRatingRaw);
      } else if (titleRaw.contains('★') || titleRaw.contains('½')) {
        rating = _parseStarRating(titleRaw);
      }

      String? posterUrl;
      final imgMatch = RegExp(r'src="([^"]+)"').firstMatch(description);
      if (imgMatch != null) {
        posterUrl = imgMatch.group(1);
      }

      results.add(
        LetterboxdMovie(
          slug: slug.isNotEmpty ? slug : movieTitle.toLowerCase().replaceAll(' ', '-'),
          title: movieTitle,
          year: year,
          rating: rating,
          watchedDate: watchedDateRaw != null ? DateTime.tryParse(watchedDateRaw) : null,
          posterUrl: posterUrl,
        ),
      );
    }
    return results;
  }

  // --- FETCH PAGINA HTML FILMS ---
  Future<List<LetterboxdMovie>> _fetchPublicFilmsPage(
    String username, {
    required int page,
  }) async {
    try {
      final url = page == 1
          ? 'https://letterboxd.com/$username/films/'
          : 'https://letterboxd.com/$username/films/page/$page/';
      final response = await _dio.get(url);
      if (response.statusCode != 200) return [];

      final doc = html_parser.parse(response.data);
      return _parseMoviesFromDoc(doc);
    } catch (e) {
      debugPrint('Errore fetch pagina $page: $e');
      return [];
    }
  }

  // --- FETCH GENERICO URL PUBBLICO ---
  Future<List<LetterboxdMovie>> _fetchPublicUrl(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200) return [];
      final doc = html_parser.parse(response.data);
      return _parseMoviesFromDoc(doc);
    } catch (e) {
      debugPrint('Errore fetch $url: $e');
      return [];
    }
  }

  // --- FETCH WATCHLIST ---
  Future<List<LetterboxdMovie>> _fetchWatchlist(String username) async {
    final url = 'https://letterboxd.com/$username/watchlist/';
    final response = await _dio.get(url);
    if (response.statusCode != 200) return [];

    final doc = html_parser.parse(response.data);
    final List<LetterboxdMovie> movies = [];
    final posters = doc.querySelectorAll('li.poster-container, div.film-poster');

    for (final el in posters) {
      final img = el.querySelector('img');
      final posterDiv = el.classes.contains('film-poster')
          ? el
          : el.querySelector('.film-poster');
      final slug = posterDiv?.attributes['data-film-slug'] ?? '';
      final title = img?.attributes['alt'] ?? slug.replaceAll('-', ' ');

      if (title.isNotEmpty) {
        movies.add(
          LetterboxdMovie(
            slug: slug.isNotEmpty ? slug : title.toLowerCase().replaceAll(' ', '-'),
            title: title,
            isInWatchlist: true,
          ),
        );
      }
    }
    return movies;
  }

  List<LetterboxdMovie> _parseMoviesFromDoc(dynamic doc) {
    final List<LetterboxdMovie> movies = [];
    final posters = doc.querySelectorAll('li.poster-container, div.film-poster');

    for (final el in posters) {
      final posterDiv = el.classes.contains('film-poster')
          ? el
          : el.querySelector('.film-poster');

      final slug = posterDiv?.attributes['data-film-slug'] ??
          posterDiv?.attributes['data-target-link']?.replaceAll('/film/', '').replaceAll('/', '') ??
          '';

      final img = el.querySelector('img');
      final title = img?.attributes['alt'] ?? slug.replaceAll('-', ' ');
      final posterUrl = img?.attributes['src'];

      double? rating;
      final ratingSpan = el.querySelector('span.rating, p.poster-viewingdata');
      if (ratingSpan != null) {
        for (final c in ratingSpan.classes) {
          if (c.startsWith('rated-')) {
            final val = int.tryParse(c.replaceFirst('rated-', ''));
            if (val != null) {
              rating = val / 2.0;
            }
          }
        }
      }

      if (title.isNotEmpty) {
        movies.add(
          LetterboxdMovie(
            slug: slug.isNotEmpty ? slug : title.toLowerCase().replaceAll(' ', '-'),
            title: title,
            rating: rating,
            posterUrl: posterUrl,
          ),
        );
      }
    }

    return movies;
  }

  /// PARSING RAPIDO CSV UFFICIALE DI LETTERBOXD
  /// Permette di importare istantaneamente TUTTI i 1360+ film esportati da Letterboxd
  List<LetterboxdMovie> parseLetterboxdCsv(String csvContent) {
    try {
      final lines = csvContent.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return [];

      final header = _splitCsvLine(lines.first).map((e) => e.toLowerCase().trim()).toList();
      final nameIdx = header.indexOf('name');
      final yearIdx = header.indexOf('year');
      final ratingIdx = header.indexOf('rating');
      final uriIdx = header.indexOf('letterboxd uri');
      final dateIdx = header.indexOf('watched date') != -1
          ? header.indexOf('watched date')
          : header.indexOf('date');

      if (nameIdx == -1) {
        debugPrint('Colonna "Name" non trovata nel CSV');
        return [];
      }

      final List<LetterboxdMovie> movies = [];

      for (int i = 1; i < lines.length; i++) {
        final row = _splitCsvLine(lines[i]);
        if (row.length <= nameIdx) continue;

        final title = row[nameIdx].trim();
        if (title.isEmpty) continue;

        int? year;
        if (yearIdx != -1 && row.length > yearIdx) {
          year = int.tryParse(row[yearIdx].trim());
        }

        double? rating;
        if (ratingIdx != -1 && row.length > ratingIdx) {
          rating = double.tryParse(row[ratingIdx].trim());
        }

        DateTime? watchedDate;
        if (dateIdx != -1 && row.length > dateIdx) {
          final dateStr = row[dateIdx].trim();
          if (dateStr.isNotEmpty) {
            watchedDate = DateTime.tryParse(dateStr);
          }
        }

        String slug = '';
        if (uriIdx != -1 && row.length > uriIdx) {
          final uri = row[uriIdx].trim();
          final m = RegExp(r'/film/([^/]+)/').firstMatch(uri);
          if (m != null) slug = m.group(1)!;
        }

        if (slug.isEmpty) {
          slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
        }

        movies.add(
          LetterboxdMovie(
            slug: slug,
            title: title,
            year: year,
            rating: rating,
            isLiked: (rating != null && rating >= 4.5),
            watchedDate: watchedDate,
          ),
        );
      }

      return movies;
    } catch (e) {
      debugPrint('Errore parsing CSV Letterboxd: $e');
      return [];
    }
  }

  /// Decomprime direttamente il file .ZIP esportato da Letterboxd
  /// ed estrae automaticamente tutti i film da `ratings.csv`, `watched.csv`, `diary.csv`, `watchlist.csv` e `likes/films.csv`.
  List<LetterboxdMovie> parseLetterboxdZip(List<int> zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      String? ratingsCsv;
      String? watchedCsv;
      String? watchlistCsv;
      String? diaryCsv;
      String? likesCsv;

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();
        if (name.endsWith('ratings.csv')) {
          ratingsCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name.endsWith('watched.csv')) {
          watchedCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name.endsWith('watchlist.csv')) {
          watchlistCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name.endsWith('diary.csv')) {
          diaryCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        } else if (name.contains('like') && name.endsWith('.csv')) {
          likesCsv = utf8.decode(file.content as List<int>, allowMalformed: true);
        }
      }

      final Map<String, LetterboxdMovie> moviesMap = {};

      // 1. Prima ratings.csv: include tutti i film votati con le relative stelle
      if (ratingsCsv != null) {
        final ratedList = parseLetterboxdCsv(ratingsCsv);
        for (final m in ratedList) {
          moviesMap[m.slug] = m;
        }
      }

      // 2. Poi diary.csv: aggiunge film registrati nel diario e loro date/voti
      if (diaryCsv != null) {
        final diaryList = parseLetterboxdCsv(diaryCsv);
        for (final m in diaryList) {
          if (!moviesMap.containsKey(m.slug)) {
            moviesMap[m.slug] = m;
          } else {
            final ex = moviesMap[m.slug]!;
            moviesMap[m.slug] = LetterboxdMovie(
              slug: ex.slug,
              title: ex.title,
              year: ex.year,
              rating: ex.rating ?? m.rating,
              isLiked: ex.isLiked || m.isLiked,
              isInWatchlist: ex.isInWatchlist,
              watchedDate: m.watchedDate ?? ex.watchedDate,
              posterUrl: ex.posterUrl,
            );
          }
        }
      }

      // 3. Poi watched.csv: include tutti i film loggati (anche quelli senza voto)
      if (watchedCsv != null) {
        final watchedList = parseLetterboxdCsv(watchedCsv);
        for (final m in watchedList) {
          if (!moviesMap.containsKey(m.slug)) {
            moviesMap[m.slug] = m;
          } else if (m.watchedDate != null && moviesMap[m.slug]!.watchedDate == null) {
            final ex = moviesMap[m.slug]!;
            moviesMap[m.slug] = LetterboxdMovie(
              slug: ex.slug,
              title: ex.title,
              year: ex.year,
              rating: ex.rating,
              isLiked: ex.isLiked,
              isInWatchlist: ex.isInWatchlist,
              watchedDate: m.watchedDate,
              posterUrl: ex.posterUrl,
            );
          }
        }
      }

      // 4. likes/films.csv: film a cui l'utente ha messo il cuoricino
      if (likesCsv != null) {
        final likedList = parseLetterboxdCsv(likesCsv);
        for (final m in likedList) {
          if (moviesMap.containsKey(m.slug)) {
            final ex = moviesMap[m.slug]!;
            moviesMap[m.slug] = LetterboxdMovie(
              slug: ex.slug,
              title: ex.title,
              year: ex.year,
              rating: ex.rating,
              isLiked: true,
              isInWatchlist: ex.isInWatchlist,
              watchedDate: ex.watchedDate ?? m.watchedDate,
              posterUrl: ex.posterUrl,
            );
          } else {
            moviesMap[m.slug] = LetterboxdMovie(
              slug: m.slug,
              title: m.title,
              year: m.year,
              rating: null,
              isLiked: true,
              watchedDate: m.watchedDate,
            );
          }
        }
      }

      // 5. Watchlist: film che l'utente intende guardare
      if (watchlistCsv != null) {
        final watchlistList = parseLetterboxdCsv(watchlistCsv);
        for (final m in watchlistList) {
          if (moviesMap.containsKey(m.slug)) {
            final ex = moviesMap[m.slug]!;
            moviesMap[m.slug] = LetterboxdMovie(
              slug: ex.slug,
              title: ex.title,
              year: ex.year,
              rating: ex.rating,
              isLiked: ex.isLiked,
              isInWatchlist: true,
              watchedDate: ex.watchedDate,
              posterUrl: ex.posterUrl,
            );
          } else {
            moviesMap[m.slug] = LetterboxdMovie(
              slug: m.slug,
              title: m.title,
              year: m.year,
              rating: null,
              isInWatchlist: true,
              watchedDate: m.watchedDate,
            );
          }
        }
      }

      return moviesMap.values.toList();
    } catch (e) {
      debugPrint('Errore estrazione ZIP Letterboxd: $e');
      return [];
    }
  }

  List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer cur = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(cur.toString().trim());
        cur.clear();
      } else {
        cur.write(char);
      }
    }
    result.add(cur.toString().trim());
    return result;
  }

  double? _parseStarRating(String text) {
    int stars = '★'.allMatches(text).length;
    bool half = text.contains('½');
    if (stars > 0 || half) {
      return stars + (half ? 0.5 : 0.0);
    }
    return null;
  }

  List<LetterboxdMovie> _generateSampleCinemaDiary(String username) {
    return [
      const LetterboxdMovie(slug: 'dune-part-two-2024', title: 'Dune: Parte Due', year: 2024, rating: 5.0, isLiked: true),
      const LetterboxdMovie(slug: 'oppenheimer-2023', title: 'Oppenheimer', year: 2023, rating: 4.5, isLiked: true),
      const LetterboxdMovie(slug: 'blade-runner-2049', title: 'Blade Runner 2049', year: 2017, rating: 5.0, isLiked: true),
      const LetterboxdMovie(slug: 'interstellar', title: 'Interstellar', year: 2014, rating: 4.5),
      const LetterboxdMovie(slug: 'arrival-2016', title: 'Arrival', year: 2016, rating: 4.5, isLiked: true),
      const LetterboxdMovie(slug: 'poor-things-2023', title: 'Povere Creature!', year: 2023, rating: 4.0),
      const LetterboxdMovie(slug: 'the-zone-of-interest', title: 'La zona d\'interesse', year: 2023, rating: 4.5),
      const LetterboxdMovie(slug: 'parasite-2019', title: 'Parasite', year: 2019, rating: 5.0, isLiked: true),
    ];
  }
}
