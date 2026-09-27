import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cinepulse/core/services/letterboxd_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test estrazione e parsing diretto archivio .ZIP esportato da Letterboxd', () {
    final service = LetterboxdService();

    // Creiamo un archivio ZIP in memoria simulando l'export reale di Letterboxd
    final ratingsCsv = '''Date,Name,Year,Letterboxd URI,Rating
2024-03-01,Dune: Part Two,2024,https://boxd.it/test1,5.0
2023-07-21,Oppenheimer,2023,https://boxd.it/test2,4.5
2014-11-07,Interstellar,2014,https://boxd.it/test3,4.0
''';

    final watchedCsv = '''Date,Name,Year,Letterboxd URI
2024-03-01,Dune: Part Two,2024,https://boxd.it/test1
2023-07-21,Oppenheimer,2023,https://boxd.it/test2
2022-01-15,The Batman,2022,https://boxd.it/test4
''';

    final watchlistCsv = '''Date,Name,Year,Letterboxd URI
2024-09-01,Gladiator II,2024,https://boxd.it/test5
''';

    final archive = Archive();
    archive.addFile(ArchiveFile('ratings.csv', ratingsCsv.length, utf8.encode(ratingsCsv)));
    archive.addFile(ArchiveFile('watched.csv', watchedCsv.length, utf8.encode(watchedCsv)));
    archive.addFile(ArchiveFile('watchlist.csv', watchlistCsv.length, utf8.encode(watchlistCsv)));

    final zipBytes = ZipEncoder().encode(archive);
    expect(zipBytes, isNotNull);

    final movies = service.parseLetterboxdZip(zipBytes!);

    // Dovrebbero esserci: Dune 2 (voto 5.0), Oppenheimer (voto 4.5), Interstellar (voto 4.0), The Batman (senza voto), Gladiator II (in watchlist)
    expect(movies.length, equals(5));

    final dune = movies.firstWhere((m) => m.title == 'Dune: Part Two');
    expect(dune.rating, equals(5.0));
    expect(dune.isLiked, isTrue);

    final batman = movies.firstWhere((m) => m.title == 'The Batman');
    expect(batman.rating, isNull);
    expect(batman.year, equals(2022));

    final gladiator = movies.firstWhere((m) => m.title == 'Gladiator II');
    expect(gladiator.isInWatchlist, isTrue);
  });
}
