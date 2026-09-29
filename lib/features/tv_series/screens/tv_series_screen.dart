import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tv_series.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/tv_series_card.dart';
import '../widgets/tv_series_detail_sheet.dart';

class TvSeriesScreen extends ConsumerStatefulWidget {
  const TvSeriesScreen({super.key});

  @override
  ConsumerState<TvSeriesScreen> createState() => _TvSeriesScreenState();
}

class _TvSeriesScreenState extends ConsumerState<TvSeriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'queued'; // 'queued', 'watched', 'all'
  bool _isSearching = false;
  List<TvSeries> _searchResults = [];
  bool _isSearchLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
    });

    final tmdb = ref.read(tmdbClientProvider);
    try {
      final results = await tmdb.searchTvSeries(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
        });
      }
    }
  }

  void _openSeriesDetail(TvSeries series, String countryCode) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TvSeriesDetailSheet(
        series: series,
        countryCode: countryCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSeries = ref.watch(tvSeriesProvider);
    final countryCode = ref.watch(selectedCountryProvider);

    final queuedSeries = allSeries.where((s) => s.status != 'completed').toList();
    final watchedSeries = allSeries.where((s) => s.status == 'completed').toList();

    List<TvSeries> displayList;
    if (_activeTab == 'queued') {
      displayList = queuedSeries;
    } else if (_activeTab == 'watched') {
      displayList = watchedSeries;
    } else {
      displayList = allSeries;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Ricerca Serie TV
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF141923),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      _performSearch(val);
                      if (!_isSearching) setState(() => _isSearching = true);
                    } else {
                      setState(() {
                        _isSearching = false;
                        _searchResults = [];
                      });
                    }
                  },
                  onSubmitted: _performSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cerca una serie TV da aggiungere...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Modalità Ricerca Attiva
            if (_isSearching) ...[
              Expanded(
                child: _isSearchLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF2979FF),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'Nessuna serie TV trovata.',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90, top: 8),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final item = _searchResults[index];
                              final isAlreadyInQueue = allSeries.any((s) => s.id == item.id);

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141923),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 52,
                                        height: 78,
                                        child: item.posterUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: item.posterUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: const Color(0xFF1E2838),
                                                child: const Icon(Icons.live_tv, color: Colors.white38),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (item.year.isNotEmpty) ...[
                                                Text(
                                                  item.year,
                                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              if (item.voteAverage > 0) ...[
                                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                                const SizedBox(width: 2),
                                                Text(
                                                  item.voteAverage.toStringAsFixed(1),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: isAlreadyInQueue
                                          ? null
                                          : () async {
                                              HapticFeedback.mediumImpact();
                                              await ref.read(tvSeriesProvider.notifier).addSeries(item);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded,
                                                            color: Color(0xFF00E676), size: 18),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text('"${item.name}" aggiunta alla tua Coda!'),
                                                        ),
                                                      ],
                                                    ),
                                                    duration: const Duration(seconds: 2),
                                                    backgroundColor: const Color(0xFF1E2430),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                );
                                            },
                                      icon: Icon(
                                        isAlreadyInQueue ? Icons.done_rounded : Icons.add_rounded,
                                        size: 16,
                                      ),
                                      label: Text(isAlreadyInQueue ? 'In Coda' : 'Aggiungi'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isAlreadyInQueue
                                            ? const Color(0xFF1E2838)
                                            : const Color(0xFF2979FF),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ] else ...[
              // Sub-Tabs Stile Queue (13 Queued | 1 visti | 0 Liste/Tutte)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _FilterTabItem(
                      label: '${queuedSeries.length} Queued',
                      icon: Icons.hourglass_top_rounded,
                      isActive: _activeTab == 'queued',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeTab = 'queued');
                      },
                    ),
                    const SizedBox(width: 16),
                    _FilterTabItem(
                      label: '${watchedSeries.length} visti',
                      icon: Icons.check_circle_outline_rounded,
                      isActive: _activeTab == 'watched',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeTab = 'watched');
                      },
                    ),
                    const SizedBox(width: 16),
                    _FilterTabItem(
                      label: '${allSeries.length} Tutte',
                      icon: Icons.list_alt_rounded,
                      isActive: _activeTab == 'all',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeTab = 'all');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Lista Serie TV
              Expanded(
                child: displayList.isEmpty
                    ? _EmptyTvSeriesView(
                        tab: _activeTab,
                        onSearchTap: () {
                          // Porta il focus sulla barra di ricerca
                        },
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF2979FF),
                        backgroundColor: const Color(0xFF161A22),
                        onRefresh: () async {
                          ref.read(tvSeriesProvider.notifier).refresh();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96, top: 4),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final series = displayList[index];
                            return TvSeriesCard(
                              series: series,
                              onTap: () => _openSeriesDetail(series, countryCode),
                              onMarkNextWatched: () async {
                                final curEp = series.currentEpisodeDisplay;
                                await ref.read(tvSeriesProvider.notifier).markNextEpisodeWatched(series.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_rounded, color: Color(0xFF00E676), size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Visto: $curEp (${series.name})'),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF1E2430),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterTabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTabItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Indicatore sottolineato stile Queue
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isActive ? 60 : 0,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTvSeriesView extends StatelessWidget {
  final String tab;
  final VoidCallback onSearchTap;

  const _EmptyTvSeriesView({
    required this.tab,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    String message = 'Nessuna serie in coda.';
    if (tab == 'watched') message = 'Nessuna serie ancora completata.';
    if (tab == 'all') message = 'Nessuna serie TV tracciata.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141923),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                size: 48,
                color: Color(0xFF2979FF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa la barra di ricerca in alto per trovare qualsiasi serie TV e iniziare a spuntare gli episodi come nell\'app Queue!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
