import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../movie_detail/screens/movie_detail_sheet.dart';

class TopRatedScreen extends ConsumerWidget {
  const TopRatedScreen({super.key});

  void _openMovieDetail(BuildContext context, WidgetRef ref, TmdbMovie movie, String countryCode) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MovieDetailSheet(
            movie: movie,
            countryCode: countryCode,
            onWatchlistToggle: () {
              ref.read(recommendationsProvider.notifier).toggleFavorite(movie.id);
            },
            onMarkAsWatched: () {
              ref.read(recommendationsProvider.notifier).dismissMovie(movie.id);
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.08);
          const end = Offset.zero;
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curve),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topRatedAsync = ref.watch(topRatedMoviesProvider);
    final countryCode = ref.watch(selectedCountryProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom + 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PIÙ ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'VOTATI',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppColors.primaryOrange,
                              shadows: [
                                Shadow(
                                  color: AppColors.primaryOrange.withOpacity(0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'I capolavori acclamati da critica e pubblico',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.workspace_premium_rounded, color: AppColors.primaryOrange, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Top 250',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: topRatedAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryOrange),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: AppColors.primaryOrange, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Impossibile caricare i film più votati',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => ref.refresh(topRatedMoviesProvider),
                        child: const Text('Ricarica'),
                      ),
                    ],
                  ),
                ),
                data: (movies) {
                  return RefreshIndicator(
                    color: AppColors.primaryOrange,
                    backgroundColor: AppColors.surfaceElevated,
                    onRefresh: () async => ref.refresh(topRatedMoviesProvider),
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
                      itemCount: movies.length,
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        return _TopRatedMovieTile(
                          rank: index + 1,
                          movie: movie,
                          countryCode: countryCode,
                          onTap: () => _openMovieDetail(context, ref, movie, countryCode),
                          onWatchlistToggle: () {
                            HapticFeedback.mediumImpact();
                            ref.read(recommendationsProvider.notifier).toggleFavorite(movie.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${movie.title}" aggiunto alla Watchlist!'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            );
                          },
                        ).animate().fadeIn(duration: 300.ms, delay: (index * 40).ms).slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 300.ms,
                              curve: Curves.easeOutQuad,
                            );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRatedMovieTile extends StatelessWidget {
  final int rank;
  final TmdbMovie movie;
  final String countryCode;
  final VoidCallback onTap;
  final VoidCallback onWatchlistToggle;

  const _TopRatedMovieTile({
    required this.rank,
    required this.movie,
    required this.countryCode,
    required this.onTap,
    required this.onWatchlistToggle,
  });

  @override
  Widget build(BuildContext context) {
    final streamProviders = movie.flatrateProviders(countryCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank Badge
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: rank <= 3 ? AppColors.primaryOrange : AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Locandina
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 74,
                    height: 108,
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.movie, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Info e Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titolo e Anno
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (movie.year.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              movie.year,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (movie.genres.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          movie.genres.take(2).join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Rating Row (Rotten Tomatoes, Letterboxd, IMDb)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (movie.rottenTomatoesScore != null)
                            _Badge(
                              emoji: '🍅',
                              text: movie.rottenTomatoesScore!.contains('%')
                                  ? movie.rottenTomatoesScore!
                                  : '${movie.rottenTomatoesScore}%',
                              bgColor: const Color(0xFFFA320A).withOpacity(0.18),
                              textColor: const Color(0xFFFF523B),
                            ),
                          if (movie.letterboxdScore != null)
                            _Badge(
                              emoji: '★',
                              text: movie.letterboxdScore!,
                              bgColor: const Color(0xFF00E054).withOpacity(0.18),
                              textColor: const Color(0xFF00E054),
                            ),
                          _Badge(
                            emoji: '⭐',
                            text: movie.voteAverage.toStringAsFixed(1),
                            bgColor: AppColors.primaryOrange.withOpacity(0.18),
                            textColor: AppColors.primaryOrange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Streaming Icons o Watchlist button
                      Row(
                        children: [
                          if (streamProviders.isNotEmpty) ...[
                            ...streamProviders.take(3).map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: CachedNetworkImage(
                                        imageUrl: p.logoUrl,
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const SizedBox(),
                                      ),
                                    ),
                                  ),
                                ),
                            if (streamProviders.length > 3)
                              Text(
                                '+${streamProviders.length - 3}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ] else
                            const Text(
                              'Disponibile a noleggio / acquisto',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              color: AppColors.primaryOrange,
                              size: 22,
                            ),
                            onPressed: onWatchlistToggle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String emoji;
  final String text;
  final Color bgColor;
  final Color textColor;

  const _Badge({
    required this.emoji,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
