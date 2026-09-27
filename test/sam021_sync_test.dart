import 'package:cinepulse/core/network/tmdb_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TMDb searchMovie trova Serpenti/Snake con slug', () async {
    final client = TmdbClient();
    final movie = await client.searchMovie('Snake', year: 2026, slug: 'serpenti');
    
    expect(movie, isNotNull);
    expect(movie!.id, 1645164);
    expect(movie.posterUrl, isNotEmpty);
    expect(movie.posterUrl.contains('xHDfVddxKnvEaWeEEnr3T4Yemgc'), true);
  });

  test('TMDb searchMovie trova Serpenti/Snake anche senza slug tramite fallback bilingue', () async {
    final client = TmdbClient();
    final movie = await client.searchMovie('Snake', year: 2026);
    
    expect(movie, isNotNull);
    expect(movie!.id, 1645164);
    expect(movie.posterUrl, isNotEmpty);
    expect(movie.posterUrl.contains('xHDfVddxKnvEaWeEEnr3T4Yemgc'), true);
  });
}
