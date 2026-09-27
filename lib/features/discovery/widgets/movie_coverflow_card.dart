import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/theme/app_theme.dart';

class MovieCoverflowCard extends StatelessWidget {
  final TmdbMovie movie;
  final double pageOffset;
  final String countryCode;
  final VoidCallback onTap;
  final VoidCallback onWatchlistToggle;
  final VoidCallback onDismiss;

  const MovieCoverflowCard({
    super.key,
    required this.movie,
    required this.pageOffset,
    required this.countryCode,
    required this.onTap,
    required this.onWatchlistToggle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Calcolo rotazione 3D e prospettiva basata sull'offset di scorrimento
    final double gauss = exp(-(pow(pageOffset.abs(), 2) / 0.5));
    final double rotationY = pageOffset * -0.35; // Rotazione angolare 3D
    final double scale = 0.88 + (0.12 * gauss);
    final double opacity = (0.5 + (0.5 * gauss)).clamp(0.0, 1.0);

    final providers = movie.flatrateProviders(countryCode);

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015) // Effetto prospettiva reale
        ..rotateY(rotationY)
        ..scale(scale, scale),
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.18 * gauss),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster Immagine HD
                  Hero(
                    tag: 'poster_${movie.id}',
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceElevated,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.movie, size: 60, color: AppColors.textMuted),
                      ),
                    ),
                  ),

                  // Gradiente di protezione inferiore per leggibilità
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 0.75, 1.0],
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.85),
                            Colors.black.withOpacity(0.98),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge Top Bar: Match Score & Watchlist Status
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Match Neon
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.primaryOrange.withOpacity(0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.primaryOrange,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${movie.matchScore.toInt()}% MATCH',
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottone Rapido Watchlist
                        GestureDetector(
                          onTap: onWatchlistToggle,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(
                                color: movie.isInUserWatchlist
                                    ? AppColors.amberFlame
                                    : AppColors.borderSubtle,
                              ),
                            ),
                            child: Icon(
                              movie.isInUserWatchlist
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: movie.isInUserWatchlist
                                  ? AppColors.amberFlame
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenuto Inferiore: Titolo, Generi, Streaming Providers & Spiegazione
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Anno e Durata
                        Row(
                          children: [
                            if (movie.releaseYear.isNotEmpty)
                              Text(
                                movie.releaseYear,
                                style: const TextStyle(
                                  color: AppColors.electricCyan,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (movie.formattedRuntime.isNotEmpty) ...[
                              const Text('  •  ', style: TextStyle(color: AppColors.textMuted)),
                              Text(
                                movie.formattedRuntime,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Rating TMDb
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 3),
                                Text(
                                  movie.voteAverage.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Titolo del Film
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Tag Regista o Genere Principale
                        if (movie.director != null && movie.director!.isNotEmpty)
                          Text(
                            'Regia di ${movie.director}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Streaming Providers Badge
                        if (providers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'In streaming su: ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ...providers.take(3).map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: CachedNetworkImage(
                                        imageUrl: p.fullLogoUrl,
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.tv,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Disponibile a noleggio / acquisto',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Motivazione di Raccomandazione (Reasoning)
                        if (movie.matchReasons.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primaryOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              movie.matchReasons.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bordo sottile lucido
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
