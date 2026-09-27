import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/theme/app_theme.dart';

class TinderVerticalMovieCard extends StatefulWidget {
  final TmdbMovie movie;
  final String countryCode;
  final VoidCallback onTap;
  final VoidCallback onSwipeLeft; // Dislike
  final VoidCallback onSwipeRight; // Watchlist

  const TinderVerticalMovieCard({
    super.key,
    required this.movie,
    required this.countryCode,
    required this.onTap,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<TinderVerticalMovieCard> createState() => _TinderVerticalMovieCardState();
}

class _TinderVerticalMovieCardState extends State<TinderVerticalMovieCard>
    with SingleTickerProviderStateMixin {
  double _dragDx = 0.0;
  bool _isDragging = false;
  late AnimationController _animController;
  late Animation<double> _returnAnimation;

  static const double _swipeThreshold = 110.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
      setState(() {
        _dragDx = _returnAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _animController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDx += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    if (_dragDx > _swipeThreshold) {
      // SWIPE A DESTRA: SALVA IN WATCHLIST
      HapticFeedback.heavyImpact();
      _flyOutAndTrigger(true);
    } else if (_dragDx < -_swipeThreshold) {
      // SWIPE A SINISTRA: DISLIKE
      HapticFeedback.mediumImpact();
      _flyOutAndTrigger(false);
    } else {
      // TORNA AL CENTRO ELASTICAMENTE
      _returnAnimation = Tween<double>(
        begin: _dragDx,
        end: 0.0,
      ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
      );
      _animController.forward(from: 0.0);
    }
  }

  void _flyOutAndTrigger(bool isRight) {
    final double target = isRight ? 500.0 : -500.0;
    _returnAnimation = Tween<double>(
      begin: _dragDx,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward(from: 0.0).then((_) {
      if (isRight) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      if (mounted) {
        setState(() {
          _dragDx = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double rotation = (_dragDx / screenWidth) * 0.22; // Rotazione proporzionale
    final double dragProgress = (_dragDx.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final bool isRightSwipe = _dragDx > 0;
    final bool isLeftSwipe = _dragDx < 0;

    final providers = widget.movie.flatrateProviders(widget.countryCode);

    return Transform.translate(
      offset: Offset(_dragDx, 0),
      child: Transform.rotate(
        angle: rotation,
        child: GestureDetector(
          onTap: widget.onTap,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom + 92,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isRightSwipe
                      ? AppColors.primaryOrange.withOpacity(0.3 * dragProgress)
                      : isLeftSwipe
                          ? Colors.redAccent.withOpacity(0.3 * dragProgress)
                          : Colors.black.withOpacity(0.6),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // POSTER A TUTTO SCHERMO
                  Hero(
                    tag: 'poster_${widget.movie.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                      errorWidget: (_, __, ___) => Container(color: AppColors.surface),
                    ),
                  ),

                  // SFUMATURA SCURA INFERIORE
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 0.7, 1.0],
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.82),
                            Colors.black.withOpacity(0.98),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // TIMBRO TINDER: "WATCHLIST" (Swipe a destra)
                  if (isRightSwipe)
                    Positioned(
                      top: 40,
                      left: 28,
                      child: Transform.rotate(
                        angle: -0.25,
                        child: Opacity(
                          opacity: dragProgress,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primaryOrange, width: 3),
                              color: Colors.black.withOpacity(0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryOrange.withOpacity(0.6),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Text(
                              'WATCHLIST',
                              style: TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // TIMBRO TINDER: "DISLIKE" (Swipe a sinistra)
                  if (isLeftSwipe)
                    Positioned(
                      top: 40,
                      right: 28,
                      child: Transform.rotate(
                        angle: 0.25,
                        child: Opacity(
                          opacity: dragProgress,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.redAccent, width: 3),
                              color: Colors.black.withOpacity(0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.6),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Text(
                              'NON INTERESSA',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // TOP BAR: MATCH SCORE & GUIDA GESTURE
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Match Neon Arancione
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.primaryOrange.withOpacity(0.7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(0.35),
                                blurRadius: 12,
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
                                '${widget.movie.matchScore.toInt()}% MATCH',
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

                        // Guida gesture micro-badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.swap_horiz, size: 14, color: AppColors.textSecondary),
                              SizedBox(width: 4),
                              Text(
                                'Swipe per decidere',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CONTENUTO INFERIORE INFORMATIVO
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // RATING ROW: Rotten Tomatoes, Letterboxd, TMDb
                        Row(
                          children: [
                            if (widget.movie.releaseYear.isNotEmpty)
                              Text(
                                widget.movie.releaseYear,
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (widget.movie.formattedRuntime.isNotEmpty) ...[
                              const Text('  •  ', style: TextStyle(color: AppColors.textMuted)),
                              Text(
                                widget.movie.formattedRuntime,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Rotten Tomatoes
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Text('🍅 ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    widget.movie.rottenTomatoesScore ?? '91%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Letterboxd
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Text('🟢 ★', style: TextStyle(fontSize: 10, color: AppColors.primaryOrange)),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.movie.letterboxdScore ?? '4.2',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Titolo
                        Text(
                          widget.movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),

                        if (widget.movie.director != null && widget.movie.director!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Regia di ${widget.movie.director}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
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
                          ),

                        const SizedBox(height: 10),

                        // Motivo di Raccomandazione
                        if (widget.movie.matchReasons.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryOrange.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              widget.movie.matchReasons.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bordo lucido
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
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
