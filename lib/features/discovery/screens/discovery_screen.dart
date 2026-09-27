import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../movie_detail/screens/movie_detail_sheet.dart';
import '../widgets/dynamic_ambient_background.dart';
import '../widgets/tinder_vertical_movie_card.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  late final PageController _verticalPageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _verticalPageController.addListener(() {
      final page = _verticalPageController.page?.round() ?? 0;
      if (page != _currentIndex) {
        setState(() {
          _currentIndex = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }

  void _openMovieDetail(TmdbMovie movie, String countryCode) {
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

  void _handleSwipeLeft(TmdbMovie movie) {
    ref.read(recommendationsProvider.notifier).dismissMovie(movie.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scartato "${movie.title}"'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  void _handleSwipeRight(TmdbMovie movie) {
    ref.read(recommendationsProvider.notifier).toggleFavorite(movie.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('"${movie.title}" aggiunto alla Watchlist!')),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recsAsync = ref.watch(recommendationsProvider);
    final countryCode = ref.watch(selectedCountryProvider);
    final username = ref.watch(activeUserProvider) ?? 'Cinefilo';
    final activeFilters = ref.watch(activeProvidersFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DynamicAmbientBackground(
        primaryGlow: AppColors.primaryOrange,
        secondaryGlow: AppColors.amberFlame,
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    // Brand CinePulse Arancione
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CINE',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'PULSE',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
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
                        Text(
                          'Letterboxd Sync @$username',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Badge Paese Streaming
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(navTabProvider.notifier).setTab(3);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countryCode == 'IT'
                                  ? '🇮🇹 IT'
                                  : countryCode == 'US'
                                      ? '🇺🇸 US'
                                      : '🇬🇧 UK',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (activeFilters.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Tasto Profilo / Statistiche
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(navTabProvider.notifier).setTab(3);
                      },
                    ),
                  ],
                ),
              ),

              if (username == 'Ospite' || ref.watch(userLetterboxdMoviesProvider).isEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(navTabProvider.notifier).setTab(3);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryOrange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.folder_zip_rounded, color: AppColors.primaryOrange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modalità Ospite • Tocca per importare lo .ZIP di Letterboxd',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: AppColors.primaryOrange, size: 12),
                      ],
                    ),
                  ),
                ),

              // CONTROLLO SCORRIMENTO VERTICALE (TIKTOK/REELS STYLE) + TINDER HORIZONTAL SWIPE
              Expanded(
                child: recsAsync.when(
                  loading: () => const _LoadingView(),
                  error: (err, _) => _ErrorView(
                    error: err.toString(),
                    onRetry: () => ref
                        .read(recommendationsProvider.notifier)
                        .loadRecommendations(forceRefresh: true),
                  ),
                  data: (movies) {
                    if (movies.isEmpty) {
                      return const _EmptyRecommendationsView();
                    }

                    return Stack(
                      children: [
                        // PageView Verticale: scorri su/giù liberamente
                        PageView.builder(
                          controller: _verticalPageController,
                          scrollDirection: Axis.vertical,
                          physics: const BouncingScrollPhysics(),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return TinderVerticalMovieCard(
                              movie: movie,
                              countryCode: countryCode,
                              onTap: () => _openMovieDetail(movie, countryCode),
                              onSwipeLeft: () => _handleSwipeLeft(movie),
                              onSwipeRight: () => _handleSwipeRight(movie),
                            );
                          },
                        ),

                        // Micro suggerimento visuale a comparsa laterale
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_drop_up, size: 16, color: AppColors.textMuted),
                                  Text(
                                    '${_currentIndex + 1}/${movies.length}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryOrange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.35),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryOrange,
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat()).scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 24),
          const Text(
            'Analisi del tuo gusto cinematografico...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Calcolo affinità generi e piattaforme streaming',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecommendationsView extends StatelessWidget {
  const _EmptyRecommendationsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_filter_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Nessun film trovato con i filtri attuali',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prova a rimuovere il filtro abbonamento streaming o a cambiare nazione nel tuo profilo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.primaryOrange),
            const SizedBox(height: 16),
            const Text(
              'Errore nel calcolo dei suggerimenti',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
