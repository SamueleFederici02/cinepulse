import 'package:flutter_test/flutter_test.dart';
import 'package:cinepulse/core/services/letterboxd_service.dart';

void main() async {
  test('Test sincronizzazione reale profilo Letterboxd sam021', () async {
    final service = LetterboxdService();
    print('Avvio sync per username: sam021...');
    
    int lastCount = 0;
    final movies = await service.syncUserMovies(
      'sam021',
      onProgress: (count) {
        lastCount = count;
        print('Progresso download: $count film estratti...');
      },
    );

    print('TOTALE FILM TROVATI per sam021: ${movies.length}');
    if (movies.isNotEmpty) {
      print('Primo film: ${movies.first.title} (${movies.first.year}) - Rating: ${movies.first.rating}');
      print('Ultimo film: ${movies.last.title} (${movies.last.year}) - Rating: ${movies.last.rating}');
    }

    expect(movies.isNotEmpty, true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
