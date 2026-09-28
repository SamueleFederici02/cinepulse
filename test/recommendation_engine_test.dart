import 'package:flutter_test/flutter_test.dart';
import 'package:cinepulse/core/models/letterboxd_movie.dart';
import 'package:cinepulse/core/models/taste_profile.dart';
import 'package:cinepulse/core/models/tmdb_movie.dart';
import 'package:cinepulse/core/models/watch_provider.dart';

void main() {
  group('CinePulse Taste & Recommendation Unit Tests', () {
    test('LetterboxdMovie JSON Serialization works as expected', () {
      final movie = LetterboxdMovie(
        slug: 'dune-part-two-2024',
        title: 'Dune: Part Two',
        year: 2024,
        rating: 4.5,
        isLiked: true,
        isInWatchlist: false,
      );

      final json = movie.toJson();
      expect(json['slug'], 'dune-part-two-2024');
      expect(json['rating'], 4.5);
      expect(json['isLiked'], true);

      final reconstructed = LetterboxdMovie.fromJson(json);
      expect(reconstructed.title, 'Dune: Part Two');
      expect(reconstructed.year, 2024);
      expect(reconstructed.rating, 4.5);
    });

    test('TmdbMovie handles watch providers per country properly', () {
      final movie = TmdbMovie(
        id: 693134,
        title: 'Dune: Parte Due',
        overview: 'Paul Atreides si unisce a Chani e ai Fremen...',
        voteAverage: 8.3,
        voteCount: 4500,
        watchProviders: {
          'IT': [
            const WatchProvider(
              providerId: 8,
              providerName: 'Netflix',
              logoPath: '/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg',
              type: 'flatrate',
            ),
            const WatchProvider(
              providerId: 119,
              providerName: 'Amazon Prime Video',
              logoPath: '/emthp39XA2zhcoYLbv0KU2UdICb.jpg',
              type: 'flatrate',
            ),
            const WatchProvider(
              providerId: 2,
              providerName: 'Apple TV',
              logoPath: '/peURlLlr8jggOwK53fJ5wdQl05y.jpg',
              type: 'rent',
            ),
          ],
          'US': [
            const WatchProvider(
              providerId: 1899,
              providerName: 'Max',
              logoPath: '/Ajqyt5GhGFOXny19RAST8dWUmNx.jpg',
              type: 'flatrate',
            ),
          ],
        },
      );

      final itFlatrate = movie.flatrateProviders('IT');
      expect(itFlatrate.length, 2);
      expect(itFlatrate.map((p) => p.providerName), containsAll(['Netflix', 'Amazon Prime Video']));

      final usFlatrate = movie.flatrateProviders('US');
      expect(usFlatrate.length, 1);
      expect(usFlatrate.first.providerName, 'Max');
    });

    test('TasteProfile percentages and average calculation', () {
      final profile = TasteProfile(
        username: 'cinephile_test',
        totalWatched: 100,
        totalRated: 80,
        totalInWatchlist: 25,
        genreCounts: {
          'Fantascienza': 40,
          'Drammatico': 30,
          'Thriller': 20,
          'Commedia': 10,
        },
        genrePercentages: {
          'Fantascienza': 40.0,
          'Drammatico': 30.0,
          'Thriller': 20.0,
          'Commedia': 10.0,
        },
        topDirectors: ['Denis Villeneuve', 'Christopher Nolan'],
        directorFilmCounts: {
          'Denis Villeneuve': 6,
          'Christopher Nolan': 4,
        },
        topMultiGenres: ['Fantascienza & Thriller', 'Drammatico & Sci-Fi'],
        multiGenrePercentages: {'Fantascienza & Thriller': 35.0},
        topSubgenres: ['Sci-Fi Psicologico', 'Neo-Noir'],
        averageRating: 4.2,
        lastSync: DateTime.now(),
      );

      expect(profile.genrePercentages['Fantascienza'], 40.0);
      expect(profile.topDirectors.first, 'Denis Villeneuve');
      expect(profile.directorFilmCounts['Denis Villeneuve'], 6);
      expect(profile.topMultiGenres, contains('Fantascienza & Thriller'));
      expect(profile.topSubgenres, contains('Sci-Fi Psicologico'));
      expect(profile.averageRating, 4.2);

      final json = profile.toJson();
      final fromJson = TasteProfile.fromJson(json);
      expect(fromJson.directorFilmCounts['Denis Villeneuve'], 6);
      expect(fromJson.directorFilmCounts['Christopher Nolan'], 4);
      expect(fromJson.topMultiGenres, contains('Fantascienza & Thriller'));
      expect(fromJson.topSubgenres, contains('Sci-Fi Psicologico'));
    });

    test('Director ranking sorts by most watched films descending', () {
      final directorFilmCounts = {
        'Quentin Tarantino': 6,
        'Martin Scorsese': 2,
        'Christopher Nolan': 4,
        'Single Film Director': 1,
      };
      final directorScores = {
        'Quentin Tarantino': 15.0,
        'Martin Scorsese': 7.0,
        'Christopher Nolan': 12.0,
        'Single Film Director': 3.5,
      };

      final eligibleDirectors = directorScores.keys
          .where((d) => (directorFilmCounts[d] ?? 0) >= 2)
          .toList()
        ..sort((a, b) {
          final countA = directorFilmCounts[a] ?? 0;
          final countB = directorFilmCounts[b] ?? 0;
          if (countB != countA) {
            return countB.compareTo(countA);
          }
          return (directorScores[b] ?? 0.0).compareTo(directorScores[a] ?? 0.0);
        });

      expect(eligibleDirectors.contains('Single Film Director'), isFalse);
      expect(eligibleDirectors, ['Quentin Tarantino', 'Christopher Nolan', 'Martin Scorsese']);
      expect(eligibleDirectors.first, 'Quentin Tarantino');
      expect(directorFilmCounts[eligibleDirectors.first], 6);
    });
  });
}
