import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/tv_series.dart';

class TvSeriesCard extends StatelessWidget {
  final TvSeries series;
  final VoidCallback onTap;
  final VoidCallback onMarkNextWatched;

  const TvSeriesCard({
    super.key,
    required this.series,
    required this.onTap,
    required this.onMarkNextWatched,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster = series.posterUrl != null && series.posterUrl!.isNotEmpty;
    final totalEpisodes = series.numberOfEpisodes > 0 ? series.numberOfEpisodes : 1;
    final watchedCount = series.totalWatchedEpisodes;
    final remaining = series.remainingEpisodes;

    // Segmented progress bar (stile Queue: 10-12 pillole luminose blu)
    const int maxSegments = 12;
    final int activeSegments = ((watchedCount / totalEpisodes) * maxSegments).round().clamp(0, maxSegments);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141923),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Locandina Verticale con angoli arrotondati (stile Queue)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 66,
                height: 98,
                child: hasPoster
                    ? CachedNetworkImage(
                        imageUrl: series.posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(
                          color: const Color(0xFF1F2633),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (ctx, url, err) => Container(
                          color: const Color(0xFF1F2633),
                          child: const Icon(Icons.live_tv, color: Colors.white38),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1F2633),
                        child: const Icon(Icons.live_tv, color: Colors.white38),
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // Dati Serie (Titolo, Episodio corrente, Rimanenti, Barre di avanzamento)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    series.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Titolo prossimo episodio (es. S1E10 Titolo Episodio)
                  Text(
                    series.currentEpisodeDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Sottotitolo episodi rimasti
                  Text(
                    series.status == 'completed'
                        ? 'Tutti gli episodi completati ✓'
                        : (remaining == 1
                            ? '1 episodio rimasto'
                            : '$remaining episodi rimasti'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: series.status == 'completed'
                          ? const Color(0xFF00E676)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Segmented Progress Bar (Pillole arrotondate blu e navy)
                  Row(
                    children: List.generate(maxSegments, (index) {
                      final isWatched = index < activeSegments;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index == maxSegments - 1 ? 0 : 3),
                          decoration: BoxDecoration(
                            color: isWatched
                                ? const Color(0xFF2979FF) // Vibrant Queue Blue
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isWatched
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2979FF).withOpacity(0.5),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Pulsante Rapido Checkmark (✓) per segnare il prossimo episodio come visto
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onMarkNextWatched();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: series.status == 'completed'
                        ? const Color(0xFF00E676).withOpacity(0.18)
                        : const Color(0xFF1E2838),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: series.status == 'completed'
                          ? const Color(0xFF00E676).withOpacity(0.4)
                          : Colors.white.withOpacity(0.12),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: series.status == 'completed'
                          ? const Color(0xFF00E676)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
