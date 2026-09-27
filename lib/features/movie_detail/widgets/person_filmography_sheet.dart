import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/movie_detail_sheet.dart';

class PersonFilmographySheet extends ConsumerStatefulWidget {
  final int personId;
  final String personName;
  final String? profileUrl;
  final String role; // 'Regista' o 'Attore'
  final bool isDirector;
  final String countryCode;

  const PersonFilmographySheet({
    super.key,
    required this.personId,
    required this.personName,
    this.profileUrl,
    required this.role,
    this.isDirector = false,
    required this.countryCode,
  });

  static void show(
    BuildContext context, {
    required int personId,
    required String personName,
    String? profileUrl,
    required String role,
    bool isDirector = false,
    required String countryCode,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PersonFilmographySheet(
        personId: personId,
        personName: personName,
        profileUrl: profileUrl,
        role: role,
        isDirector: isDirector,
        countryCode: countryCode,
      ),
    );
  }

  @override
  ConsumerState<PersonFilmographySheet> createState() => _PersonFilmographySheetState();
}

class _PersonFilmographySheetState extends ConsumerState<PersonFilmographySheet> {
  bool _isLoading = true;
  List<TmdbMovie> _movies = [];

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final tmdb = ref.read(tmdbClientProvider);
    final res = await tmdb.getPersonFilmography(widget.personId, isDirector: widget.isDirector);
    if (mounted) {
      setState(() {
        _movies = res;
        _isLoading = false;
      });
    }
  }

  void _openMovieDetail(TmdbMovie movie) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MovieDetailSheet(
            movie: movie,
            countryCode: widget.countryCode,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Persona
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: widget.profileUrl != null && widget.profileUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.profileUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.person, color: Colors.white54, size: 36),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.person, color: Colors.white54, size: 36),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryOrange.withOpacity(0.4)),
                            ),
                            child: Text(
                              widget.role,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.personName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isLoading
                            ? 'Caricamento filmografia...'
                            : '${_movies.length} film nella filmografia',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // Filmografia Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : _movies.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun film trovato per questa persona.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.56,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _movies.length,
                        itemBuilder: (context, index) {
                          final m = _movies[index];
                          return GestureDetector(
                            onTap: () => _openMovieDetail(m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: m.posterUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (_, __) => Container(color: Colors.white10),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.surfaceElevated,
                                        child: const Icon(Icons.movie, color: Colors.white30),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  m.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      m.releaseYear,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (m.voteAverage > 0)
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 12, color: AppColors.amberFlame),
                                          const SizedBox(width: 1),
                                          Text(
                                            m.voteAverage.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 10.5,
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
