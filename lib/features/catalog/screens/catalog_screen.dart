import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../movie_detail/screens/movie_detail_sheet.dart';

enum CatalogSection {
  nowPlaying,
  topRated,
  trending,
  byGenre,
  byDecade,
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  CatalogSection _activeSection = CatalogSection.nowPlaying;
  int _selectedGenreId = 18; // Default: Drammatico (18)
  String _selectedDecade = '2020'; // 2020, 2010, 2000, 1990, 1980, 1970

  final Map<String, List<TmdbMovie>> _catalogCache = {};
  bool _isLoading = false;
  List<TmdbMovie> _currentMovies = [];

  final List<Map<String, dynamic>> _genrePills = [
    {'name': 'Drammatico', 'id': 18},
    {'name': 'Avventura', 'id': 12},
    {'name': 'Commedia', 'id': 35},
    {'name': 'Azione', 'id': 28},
    {'name': 'Fantascienza', 'id': 878},
    {'name': 'Thriller', 'id': 53},
    {'name': 'Horror', 'id': 27},
    {'name': 'Animazione', 'id': 16},
    {'name': 'Crime', 'id': 80},
    {'name': 'Mistero', 'id': 9648},
  ];

  final List<Map<String, String>> _decadePills = [
    {'label': 'Anni 2020', 'value': '2020', 'range': '2020-01-01,2029-12-31'},
    {'label': 'Anni 2010', 'value': '2010', 'range': '2010-01-01,2019-12-31'},
    {'label': 'Anni 2000', 'value': '2000', 'range': '2000-01-01,2009-12-31'},
    {'label': 'Anni \'90', 'value': '1990', 'range': '1990-01-01,1999-12-31'},
    {'label': 'Anni \'80', 'value': '1980', 'range': '1980-01-01,1989-12-31'},
    {'label': 'Anni \'70', 'value': '1970', 'range': '1970-01-01,1979-12-31'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final country = ref.read(selectedCountryProvider);
    final cacheKey = '${_activeSection.name}_${_selectedGenreId}_${_selectedDecade}_$country';

    if (_catalogCache.containsKey(cacheKey)) {
      setState(() {
        _currentMovies = _catalogCache[cacheKey]!;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final tmdb = ref.read(tmdbClientProvider);
    List<TmdbMovie> results = [];

    try {
      switch (_activeSection) {
        case CatalogSection.nowPlaying:
          results = await tmdb.getNowPlayingMovies();
          break;
        case CatalogSection.topRated:
          results = await tmdb.getTopRatedMovies();
          break;
        case CatalogSection.trending:
          results = await tmdb.getTrending();
          break;
        case CatalogSection.byGenre:
          results = await tmdb.discoverMovies(
            withGenres: [_selectedGenreId],
            minVote: 7.0,
            minVoteCount: 150,
          );
          break;
        case CatalogSection.byDecade:
          final startYear = int.parse(_selectedDecade);
          results = await tmdb.discoverMovies(
            minVote: 7.2,
            minVoteCount: 120,
          );
          results = results.where((m) {
            final y = int.tryParse(m.releaseYear);
            return y != null && y >= startYear && y < (startYear + 10);
          }).toList();
          break;
      }

      // Arricchimento dettagli e streaming providers
      final detailed = await Future.wait(
        results.take(24).map((m) async {
          try {
            return await tmdb.getMovieDetails(m.id, countryCode: country) ?? m;
          } catch (_) {
            return m;
          }
        }),
      );

      _catalogCache[cacheKey] = detailed;
      if (mounted) {
        setState(() {
          _currentMovies = detailed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              ref.read(recommendationsProvider.notifier).recordWatchlist(movie);
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
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ESPLORA ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'LISTE',
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
                        'Nuove uscite, capolavori, generi e decenni',
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
                        Icon(Icons.movie_filter_rounded, color: AppColors.primaryOrange, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Cataloghi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Macro-Categorie Principali (Nuovi, Top 250, Trending, Per Genere, Per Decenni)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _buildMainPill('🎬 Nuove Uscite', CatalogSection.nowPlaying),
                  const SizedBox(width: 8),
                  _buildMainPill('🏆 Top 250', CatalogSection.topRated),
                  const SizedBox(width: 8),
                  _buildMainPill('🔥 Trending', CatalogSection.trending),
                  const SizedBox(width: 8),
                  _buildMainPill('🎭 Per Genere', CatalogSection.byGenre),
                  const SizedBox(width: 8),
                  _buildMainPill('⏳ Per Decenni', CatalogSection.byDecade),
                ],
              ),
            ),

            // Sotto-categorie (se selezionato Genere o Decennio)
            if (_activeSection == CatalogSection.byGenre)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: _genrePills.map((g) {
                    final isSel = _selectedGenreId == g['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(g['name'] as String),
                        selected: isSel,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedGenreId = g['id'] as int;
                          });
                          _loadCatalog();
                        },
                        selectedColor: AppColors.primaryOrange,
                        backgroundColor: AppColors.surfaceElevated,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            if (_activeSection == CatalogSection.byDecade)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: _decadePills.map((d) {
                    final isSel = _selectedDecade == d['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(d['label']!),
                        selected: isSel,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDecade = d['value']!;
                          });
                          _loadCatalog();
                        },
                        selectedColor: AppColors.amberFlame,
                        backgroundColor: AppColors.surfaceElevated,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 4),

            // Griglia Film
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : _currentMovies.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessun film trovato per questa selezione.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _currentMovies.length,
                          itemBuilder: (context, index) {
                            final movie = _currentMovies[index];
                            return _CatalogMovieCard(
                              movie: movie,
                              countryCode: countryCode,
                              onTap: () => _openDetail(movie, countryCode),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPill(String title, CatalogSection section) {
    final isSelected = _activeSection == section;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeSection = section;
        });
        _loadCatalog();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withOpacity(0.2)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CatalogMovieCard extends StatelessWidget {
  final TmdbMovie movie;
  final String countryCode;
  final VoidCallback onTap;

  const _CatalogMovieCard({
    required this.movie,
    required this.countryCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final providers = movie.flatrateProviders(countryCode);

    return GestureDetector(
      onTap: onTap,
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
                    CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.movie, size: 36, color: Colors.white38),
                      ),
                    ),

                    // Gradiente scuro
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

                    // Voto critico badge
                    if (movie.voteAverage > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryOrange.withOpacity(0.8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: AppColors.amberFlame),
                              const SizedBox(width: 3),
                              Text(
                                movie.voteAverage.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Provider di streaming
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
                      movie.title,
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
                          movie.releaseYear.isNotEmpty ? movie.releaseYear : '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (movie.rottenTomatoesScore != null)
                          Text(
                            '🍅 ${movie.rottenTomatoesScore}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
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
      ),
    );
  }
}
