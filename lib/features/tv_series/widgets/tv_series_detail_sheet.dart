import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tv_series.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class TvSeriesDetailSheet extends ConsumerStatefulWidget {
  final TvSeries series;
  final String countryCode;

  const TvSeriesDetailSheet({
    super.key,
    required this.series,
    required this.countryCode,
  });

  @override
  ConsumerState<TvSeriesDetailSheet> createState() => _TvSeriesDetailSheetState();
}

class _TvSeriesDetailSheetState extends ConsumerState<TvSeriesDetailSheet> {
  late int _selectedSeason;
  List<TvEpisode> _episodes = [];
  bool _isLoadingEpisodes = true;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.series.currentSeason > 0 ? widget.series.currentSeason : 1;
    _fetchEpisodesForSeason(_selectedSeason);
  }

  Future<void> _fetchEpisodesForSeason(int seasonNum) async {
    setState(() {
      _isLoadingEpisodes = true;
    });

    final tmdb = ref.read(tmdbClientProvider);
    try {
      final eps = await tmdb.getTvSeason(widget.series.id, seasonNum);
      if (mounted) {
        setState(() {
          _episodes = eps;
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesList = ref.watch(tvSeriesProvider);
    // Ottieni la versione aggiornata in tempo reale della serie
    final currentSeries = seriesList.firstWhere(
      (s) => s.id == widget.series.id,
      orElse: () => widget.series,
    );

    final seasonCount = currentSeries.numberOfSeasons > 0
        ? currentSeries.numberOfSeasons
        : (currentSeries.seasons.isNotEmpty ? currentSeries.seasons.length : 1);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF11141C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Maniglia di trascinamento
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    // Header con Locandina / Backdrop
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 100,
                              height: 150,
                              child: currentSeries.posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: currentSeries.posterUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFF1E2430),
                                      child: const Icon(Icons.live_tv, size: 40, color: Colors.white38),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSeries.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (currentSeries.year.isNotEmpty) ...[
                                      Text(
                                        currentSeries.year,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    if (currentSeries.voteAverage > 0) ...[
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 3),
                                      Text(
                                        currentSeries.voteAverage.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$seasonCount ${seasonCount == 1 ? "Stagione" : "Stagioni"} • ${currentSeries.numberOfEpisodes} Episodi',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Avanzamento Generale
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: currentSeries.progress,
                                          minHeight: 6,
                                          backgroundColor: const Color(0xFF1E293B),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2979FF)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${currentSeries.totalWatchedEpisodes}/${currentSeries.numberOfEpisodes}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge Provider Streaming (Se presenti)
                    if (currentSeries.providers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DOVE GUARDARLA IN STREAMING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentSeries.providers.map((p) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A2230),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (p.logoUrl.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(p.logoUrl, width: 18, height: 18),
                                        ),
                                      const SizedBox(width: 6),
                                      Text(
                                        p.providerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Sinossi
                    if (currentSeries.overview != null && currentSeries.overview!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text(
                          currentSeries.overview!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCBD5E1),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Selettore Stagioni a Scorrimento Orizzontale
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: const Text(
                        'STAGIONI ED EPISODI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: seasonCount,
                        itemBuilder: (context, index) {
                          final seasonNum = index + 1;
                          final isSelected = seasonNum == _selectedSeason;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text('Stagione $seasonNum'),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2979FF),
                              backgroundColor: const Color(0xFF1E2838),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF2979FF) : Colors.transparent,
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedSeason = seasonNum;
                                  });
                                  _fetchEpisodesForSeason(seasonNum);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Azione Rapida: Segna tutta la stagione come vista
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Episodi Stagione $_selectedSeason',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              ref.read(tvSeriesProvider.notifier).markSeasonWatched(
                                    currentSeries.id,
                                    _selectedSeason,
                                    _episodes.isNotEmpty ? _episodes.length : 10,
                                  );
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF2979FF)),
                            label: const Text(
                              'Segna tutti visti',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2979FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista Episodi
                    if (_isLoadingEpisodes)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF2979FF),
                          ),
                        ),
                      )
                    else if (_episodes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'Nessun dettaglio episodi disponibile per questa stagione.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._episodes.map((ep) {
                        final isWatched = currentSeries.isEpisodeWatched(_selectedSeason, ep.episodeNumber);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isWatched
                                ? const Color(0xFF1E2838).withOpacity(0.4)
                                : const Color(0xFF161C26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isWatched
                                  ? const Color(0xFF2979FF).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox per segnare l'episodio
                              IconButton(
                                icon: Icon(
                                  isWatched ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  color: isWatched ? const Color(0xFF2979FF) : const Color(0xFF64748B),
                                  size: 26,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(tvSeriesProvider.notifier).toggleEpisode(
                                        currentSeries.id,
                                        _selectedSeason,
                                        ep.episodeNumber,
                                      );
                                },
                              ),
                              const SizedBox(width: 8),

                              // Info Episodio
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${ep.episodeNumber}. ${ep.name}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isWatched ? Colors.white70 : Colors.white,
                                        decoration: isWatched ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        ep.overview!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Azione: Rimuovi dalla coda
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref.read(tvSeriesProvider.notifier).removeSeries(currentSeries.id);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        label: const Text(
                          'Rimuovi serie dalla Coda',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
