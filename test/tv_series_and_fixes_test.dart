import 'package:flutter_test/flutter_test.dart';
import 'package:cinepulse/core/services/letterboxd_service.dart';
import 'package:cinepulse/core/models/tv_series.dart';

void main() {
  group('Fixes & TV Series Tests', () {
    test('parseLetterboxdCsv ignores custom lists with /list/ URIs and list metadata', () {
      final service = LetterboxdService();
      
      const mixedCsv = '''Date,Name,Year,Letterboxd URI,Rating
2024-01-10,Inception,2010,https://letterboxd.com/film/inception/,4.5
2024-02-15,La mia infanzia,,https://letterboxd.com/user/list/la-mia-infanzia/,
2024-03-01,Interstellar,2014,https://letterboxd.com/film/interstellar/,5.0
''';

      final movies = service.parseLetterboxdCsv(mixedCsv);

      expect(movies.length, 2);
      expect(movies.any((m) => m.title == 'Inception'), isTrue);
      expect(movies.any((m) => m.title == 'Interstellar'), isTrue);
      expect(movies.any((m) => m.title == 'La mia infanzia'), isFalse);
    });

    test('TvSeries model tracks watched episodes, progress, and remaining episodes accurately', () {
      final series = TvSeries(
        id: 120998,
        name: 'Poker Face',
        numberOfSeasons: 2,
        numberOfEpisodes: 10,
        currentSeason: 1,
        currentEpisode: 3,
        currentEpisodeTitle: 'The Night Shift',
        watchedEpisodeKeys: {'s1e1', 's1e2'},
        addedAt: DateTime.now(),
      );

      expect(series.totalWatchedEpisodes, 2);
      expect(series.remainingEpisodes, 8);
      expect(series.progress, 0.2);
      expect(series.isEpisodeWatched(1, 1), isTrue);
      expect(series.isEpisodeWatched(1, 2), isTrue);
      expect(series.isEpisodeWatched(1, 3), isFalse);
      expect(series.currentEpisodeDisplay, 'S1E3 The Night Shift');

      // Test JSON serialization & deserialization
      final json = series.toJson();
      final revived = TvSeries.fromJson(json);

      expect(revived.id, 120998);
      expect(revived.name, 'Poker Face');
      expect(revived.totalWatchedEpisodes, 2);
      expect(revived.watchedEpisodeKeys.contains('s1e1'), isTrue);
    });
  });
}
