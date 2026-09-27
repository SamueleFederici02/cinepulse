import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/letterboxd_movie.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../movie_detail/screens/movie_detail_sheet.dart';

enum WatchlistSortOrder {
  addedDesc('Più recenti aggiunti'),
  releaseDesc('Anno: più recente (↓)'),
  releaseAsc('Anno: meno recente (↑)'),
  ratingDesc('Voto più alto (★)'),
  titleAsc('Titolo (A - Z)');

  final String label;
  const WatchlistSortOrder(this.label);
}

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  String _searchQuery = '';
  int _activeFilterIndex = 0; // 0: Tutti, 1: CinePulse, 2: Letterboxd, 3: In Streaming
  WatchlistSortOrder _currentSortOrder = WatchlistSortOrder.addedDesc;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetail(TmdbMovie movie, String countryCode) {
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
              ref.read(watchlistProvider.notifier).removeMovie(movie.id);
            },
            onMarkAsWatched: () {
              ref.read(recommendationsProvider.notifier).markMovieAsWatched(movie);
              ref.read(watchlistProvider.notifier).removeMovie(movie.id);
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
  Widget build(BuildContext context) {
    final countryCode = ref.watch(selectedCountryProvider);
    final cinepulseWatchlist = ref.watch(watchlistProvider);
    final letterboxdMovies = ref.watch(userLetterboxdMoviesProvider);
    final letterboxdWatchlist = letterboxdMovies.where((m) => m.isInWatchlist).toList();
    final bottomInset = MediaQuery.of(context).padding.bottom + 100;

    // Unione e indicizzazione
    final Set<String> cinepulseTitles = cinepulseWatchlist.map((m) => m.title.toLowerCase().trim()).toSet();

    // Convertiamo i film di Letterboxd Watchlist in elementi visualizzabili
    final List<_WatchlistUnifiedItem> unifiedList = [];

    for (final m in cinepulseWatchlist) {
      unifiedList.add(
        _WatchlistUnifiedItem(
          id: m.id,
          title: m.title,
          year: m.releaseYear.isNotEmpty ? m.releaseYear : null,
          posterUrl: m.posterUrl,
          tmdbMovie: m,
          isFromCinepulse: true,
          isFromLetterboxd: letterboxdWatchlist.any((l) => l.title.toLowerCase().trim() == m.title.toLowerCase().trim()),
          voteAverage: m.voteAverage,
        ),
      );
    }

    for (final l in letterboxdWatchlist) {
      if (!cinepulseTitles.contains(l.title.toLowerCase().trim())) {
        unifiedList.add(
          _WatchlistUnifiedItem(
            id: null,
            title: l.title,
            year: l.year?.toString(),
            posterUrl: l.posterUrl,
            letterboxdMovie: l,
            isFromCinepulse: false,
            isFromLetterboxd: true,
            voteAverage: l.rating != null ? l.rating! * 2.0 : null,
          ),
        );
      }
    }

    // Filtro di ricerca
    var filtered = unifiedList.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery);
    }).toList();

    // Filtro categorie
    if (_activeFilterIndex == 1) {
      filtered = filtered.where((item) => item.isFromCinepulse).toList();
    } else if (_activeFilterIndex == 2) {
      filtered = filtered.where((item) => item.isFromLetterboxd).toList();
    } else if (_activeFilterIndex == 3) {
      filtered = filtered.where((item) {
        if (item.tmdbMovie != null) {
          return item.tmdbMovie!.flatrateProviders(countryCode).isNotEmpty;
        }
        return false;
      }).toList();
    }

    // Ordinamento
    switch (_currentSortOrder) {
      case WatchlistSortOrder.addedDesc:
        break;
      case WatchlistSortOrder.releaseDesc:
        filtered.sort((a, b) {
          final ya = int.tryParse(a.year ?? '') ?? 0;
          final yb = int.tryParse(b.year ?? '') ?? 0;
          return yb.compareTo(ya);
        });
        break;
      case WatchlistSortOrder.releaseAsc:
        filtered.sort((a, b) {
          final ya = int.tryParse(a.year ?? '') ?? 9999;
          final yb = int.tryParse(b.year ?? '') ?? 9999;
          return ya.compareTo(yb);
        });
        break;
      case WatchlistSortOrder.ratingDesc:
        filtered.sort((a, b) {
          final va = a.voteAverage ?? 0.0;
          final vb = b.voteAverage ?? 0.0;
          return vb.compareTo(va);
        });
        break;
      case WatchlistSortOrder.titleAsc:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

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
                            'LA TUA ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'WATCHLIST',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: const Color(0xFF00E676),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF00E676).withOpacity(0.55),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${unifiedList.length} film salvati',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Selettore Ordinamento
                  PopupMenuButton<WatchlistSortOrder>(
                    initialValue: _currentSortOrder,
                    tooltip: 'Ordina watchlist',
                    onSelected: (order) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _currentSortOrder = order;
                      });
                    },
                    color: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, color: Color(0xFF00E676), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _currentSortOrder.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => WatchlistSortOrder.values.map((order) {
                      final isSel = order == _currentSortOrder;
                      return PopupMenuItem(
                        value: order,
                        child: Row(
                          children: [
                            Icon(
                              isSel ? Icons.check_circle_rounded : Icons.circle_outlined,
                              size: 16,
                              color: isSel ? const Color(0xFF00E676) : Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? const Color(0xFF00E676) : Colors.white,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Cerca nella tua Watchlist...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF00E676)),
                  ),
                ),
              ),
            ),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildFilterPill('Tutti (${unifiedList.length})', 0),
                  const SizedBox(width: 8),
                  _buildFilterPill('Da CinePulse (${cinepulseWatchlist.length})', 1),
                  const SizedBox(width: 8),
                  _buildFilterPill('Da Letterboxd (${letterboxdWatchlist.length})', 2),
                  const SizedBox(width: 8),
                  _buildFilterPill('Disponibili in Streaming', 3),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Griglia / Lista Film
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.58,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _WatchlistCard(
                          item: item,
                          countryCode: countryCode,
                          onTap: () async {
                            if (item.tmdbMovie != null) {
                              _openDetail(item.tmdbMovie!, countryCode);
                            } else {
                              final cached = _WatchlistCardState._movieCache[item.title];
                              if (cached != null) {
                                _openDetail(cached, countryCode);
                                return;
                              }
                              // Cerca il film su TMDb e apri i dettagli
                              final tmdb = ref.read(tmdbClientProvider);
                              final res = await tmdb.searchMovie(item.title, year: int.tryParse(item.year ?? ''));
                              if (res != null && context.mounted) {
                                final full = await tmdb.getMovieDetails(res.id, countryCode: countryCode) ?? res;
                                if (context.mounted) _openDetail(full, countryCode);
                              }
                            }
                          },
                          onRemove: () {
                            HapticFeedback.lightImpact();
                            if (item.id != null) {
                              ref.read(watchlistProvider.notifier).removeMovie(item.id!);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Rimosso "${item.title}" dalla Watchlist'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String title, int index) {
    final isSelected = _activeFilterIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withOpacity(0.18)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E676) : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_add_outlined, size: 48, color: Color(0xFF00E676)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nessun film in Watchlist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fai swipe a destra nella scheda "Per Te" per salvare al volo i film che vuoi vedere, oppure importa la tua Watchlist di Letterboxd dal profilo!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistUnifiedItem {
  final int? id;
  final String title;
  final String? year;
  final String? posterUrl;
  final TmdbMovie? tmdbMovie;
  final LetterboxdMovie? letterboxdMovie;
  final bool isFromCinepulse;
  final bool isFromLetterboxd;
  final double? voteAverage;

  _WatchlistUnifiedItem({
    required this.id,
    required this.title,
    this.year,
    this.posterUrl,
    this.tmdbMovie,
    this.letterboxdMovie,
    required this.isFromCinepulse,
    required this.isFromLetterboxd,
    this.voteAverage,
  });
}

class _WatchlistCard extends ConsumerStatefulWidget {
  final _WatchlistUnifiedItem item;
  final String countryCode;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WatchlistCard({
    required this.item,
    required this.countryCode,
    required this.onTap,
    required this.onRemove,
  });

  @override
  ConsumerState<_WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends ConsumerState<_WatchlistCard> {
  static final Map<String, String?> _posterCache = {};
  static final Map<String, TmdbMovie?> _movieCache = {};
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _fetchDetailsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _WatchlistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.title != widget.item.title) {
      _fetchDetailsIfNeeded();
    }
  }

  void _fetchDetailsIfNeeded() {
    final title = widget.item.title;
    if (widget.item.posterUrl != null && widget.item.posterUrl!.isNotEmpty) {
      return;
    }
    if (_posterCache.containsKey(title)) {
      return;
    }
    if (_isFetching) return;

    _isFetching = true;
    Future.microtask(() async {
      try {
        final tmdb = ref.read(tmdbClientProvider);
        final found = await tmdb.searchMovie(title, year: int.tryParse(widget.item.year ?? ''));
        if (found != null) {
          final full = await tmdb.getMovieDetails(found.id, countryCode: widget.countryCode) ?? found;
          _posterCache[title] = full.posterUrl;
          _movieCache[title] = full;
        } else {
          _posterCache[title] = null;
        }
      } catch (_) {
        _posterCache[title] = null;
      } finally {
        if (mounted) {
          setState(() {
            _isFetching = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cachedMovie = _movieCache[item.title];
    final effectiveMovie = item.tmdbMovie ?? cachedMovie;
    final effectivePosterUrl = (item.posterUrl != null && item.posterUrl!.isNotEmpty)
        ? item.posterUrl
        : _posterCache[item.title];
    final providers = effectiveMovie?.flatrateProviders(widget.countryCode) ?? [];
    final voteAvg = item.voteAverage ?? effectiveMovie?.voteAverage;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (effectivePosterUrl != null && effectivePosterUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: effectivePosterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.movie, size: 36, color: Colors.white38),
                        ),
                      )
                    else if (_isFetching)
                      Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.movie, size: 36, color: Colors.white38),
                      ),

                    // Gradiente
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.6, 1.0],
                            colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                          ),
                        ),
                      ),
                    ),

                    // Badge Fonte
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isFromCinepulse
                                ? const Color(0xFF00E676).withOpacity(0.8)
                                : AppColors.primaryOrange.withOpacity(0.8),
                          ),
                        ),
                        child: Text(
                          item.isFromCinepulse ? 'CinePulse' : 'Letterboxd',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: item.isFromCinepulse ? const Color(0xFF00E676) : AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ),

                    // Tasto Rimuovi
                    if (item.isFromCinepulse)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: widget.onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ),
                      ),

                    // Piattaforme streaming badge
                    if (providers.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Row(
                          children: providers.take(3).map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: CachedNetworkImage(
                                  imageUrl: p.fullLogoUrl,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // Info Film
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.year ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (voteAvg != null && voteAvg > 0)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: AppColors.amberFlame),
                              const SizedBox(width: 2),
                              Text(
                                voteAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
    );
  }
}
