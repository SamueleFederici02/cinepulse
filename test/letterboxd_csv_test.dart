import 'package:flutter_test/flutter_test.dart';
import 'package:cinepulse/core/services/letterboxd_service.dart';

void main() {
  test('Test parsing CSV Letterboxd esportato (watched.csv e ratings.csv)', () {
    final service = LetterboxdService();
    const sampleCsv = '''Date,Name,Year,Letterboxd URI,Rating
2024-03-01,Dune: Part Two,2024,https://boxd.it/hNkc,5.0
2023-07-21,Oppenheimer,2023,https://boxd.it/sYek,4.5
2014-11-07,Interstellar,2014,https://boxd.it/69sY,4.5
2017-10-06,Blade Runner 2049,2017,https://boxd.it/7dK2,5.0
2019-05-30,Parasite,2019,https://boxd.it/h27g,4.5
''';

    final movies = service.parseLetterboxdCsv(sampleCsv);
    expect(movies.length, 5);
    expect(movies.first.title, 'Dune: Part Two');
    expect(movies.first.year, 2024);
    expect(movies.first.rating, 5.0);
    expect(movies.first.isLiked, true);
  });
}
