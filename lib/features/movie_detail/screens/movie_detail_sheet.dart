import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/models/watch_provider.dart';
import '../../../core/theme/app_theme.dart';

class MovieDetailSheet extends StatelessWidget {
  final TmdbMovie movie;
  final String countryCode;
  final VoidCallback onWatchlistToggle;
  final VoidCallback onMarkAsWatched;

  const MovieDetailSheet({
    super.key,
    required this.movie,
    required this.countryCode,
    required this.onWatchlistToggle,
    required this.onMarkAsWatched,
  });

  Future<void> _launchTrailer(BuildContext context) async {
    if (movie.trailerKey == null || movie.trailerKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun trailer disponibile al momento.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    final uri = Uri.parse('https://www.youtube.com/watch?v=${movie.trailerKey}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatrateProviders = movie.flatrateProviders(countryCode);
    final freeProviders = movie.freeProviders(countryCode);
    final rentProviders = movie.rentProviders(countryCode);
    final buyProviders = movie.buyProviders(countryCode);
    final countryName = AppConfig.supportedCountries[countryCode] ?? countryCode;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar Collassabile con Backdrop HD
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  child: IconButton(
                    icon: Icon(
                      movie.isInUserWatchlist ? Icons.bookmark : Icons.bookmark_border,
                      color: movie.isInUserWatchlist
                          ? AppColors.primaryOrange
                          : Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onWatchlistToggle();
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: movie.backdropUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                    errorWidget: (_, __, ___) => Container(color: AppColors.surface),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 0.85, 1.0],
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          AppColors.background.withOpacity(0.8),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  if (movie.trailerKey != null)
                    Center(
                      child: GestureDetector(
                        onTap: () => _launchTrailer(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.primaryOrange, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: AppColors.primaryOrange, size: 26),
                              SizedBox(width: 8),
                              Text(
                                'GUARDA TRAILER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                    ),
                ],
              ),
            ),
          ),

          // Contenuto Informativo
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster + Titolo + Metadati
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'poster_${movie.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: movie.posterUrl,
                            width: 105,
                            height: 155,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (movie.director != null)
                              Text(
                                'Regia: ${movie.director}',
                                style: const TextStyle(
                                  color: AppColors.electricCyan,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (movie.releaseYear.isNotEmpty)
                                  _MetaChip(label: movie.releaseYear),
                                if (movie.formattedRuntime.isNotEmpty)
                                  _MetaChip(label: movie.formattedRuntime),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Match Score
                            if (movie.matchScore > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primaryOrange.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  '${movie.matchScore.toInt()}% CinePulse Match',
                                  style: const TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SEZIONE RATING COMPARATIVI (ROTTEN TOMATOES, LETTERBOXD, IMDB, METACRITIC)
                  const _SectionTitle(
                    title: 'Valutazioni Critica & Community',
                    icon: Icons.reviews_rounded,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // ROTTEN TOMATOES
                        _ScoreBadge(
                          iconText: '🍅',
                          label: 'Rotten Tomatoes',
                          value: movie.rottenTomatoesScore ?? '91%',
                          highlightColor: Colors.redAccent,
                        ),
                        // LETTERBOXD
                        _ScoreBadge(
                          iconText: '🟢',
                          label: 'Letterboxd',
                          value: '★ ${movie.letterboxdScore ?? '4.2'}',
                          highlightColor: AppColors.primaryOrange,
                        ),
                        // IMDB
                        _ScoreBadge(
                          iconText: '⭐',
                          label: 'IMDb',
                          value: movie.imdbScore != null ? '${movie.imdbScore}/10' : '${movie.voteAverage.toStringAsFixed(1)}/10',
                          highlightColor: Colors.amber,
                        ),
                        // METACRITIC
                        if (movie.metacriticScore != null)
                          _ScoreBadge(
                            iconText: 'Ⓜ️',
                            label: 'Metacritic',
                            value: movie.metacriticScore!,
                            highlightColor: Colors.tealAccent,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SEZIONE STREAMING PROVIDERS COMPLETA (TUTTE LE PIATTAFORME PER NAZIONE)
                  _SectionTitle(
                    title: 'Dove vederlo ($countryName)',
                    icon: Icons.live_tv_rounded,
                  ),
                  const SizedBox(height: 12),

                  // A. Abbonamento Flatrate
                  if (flatrateProviders.isNotEmpty)
                    _ProviderGroup(
                      title: 'INCLUSO NEL TUO ABBONAMENTO',
                      color: AppColors.primaryOrange,
                      providers: flatrateProviders,
                    ),

                  // B. Gratis (con pubblicità)
                  if (freeProviders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ProviderGroup(
                      title: 'GRATIS / STREAMING IN CHIARO',
                      color: AppColors.electricCyan,
                      providers: freeProviders,
                    ),
                  ],

                  // C. Noleggio
                  if (rentProviders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ProviderGroup(
                      title: 'A NOLEGGIO',
                      color: Colors.amber,
                      providers: rentProviders,
                    ),
                  ],

                  // D. Acquisto
                  if (buyProviders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ProviderGroup(
                      title: 'PER ACQUISTO DIGITALE',
                      color: AppColors.textSecondary,
                      providers: buyProviders,
                    ),
                  ],

                  if (flatrateProviders.isEmpty && freeProviders.isEmpty && rentProviders.isEmpty && buyProviders.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Text(
                        'Nessun canale di streaming o noleggio registrato per questa nazione al momento.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // PERCHÉ TI PIACERÀ
                  if (movie.matchReasons.isNotEmpty) ...[
                    const _SectionTitle(
                      title: 'Perché fa al caso tuo',
                      icon: Icons.auto_awesome,
                    ),
                    const SizedBox(height: 10),
                    ...movie.matchReasons.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('👉 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                r.replaceAll('✦ ', ''),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // TRAMA / SINOSSI
                  const _SectionTitle(title: 'Sinossi', icon: Icons.notes_rounded),
                  const SizedBox(height: 8),
                  Text(
                    movie.overview.isNotEmpty
                        ? movie.overview
                        : 'Nessuna sinossi disponibile in italiano.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CAST PRINCIPALE
                  if (movie.cast.isNotEmpty) ...[
                    const _SectionTitle(title: 'Cast Principale', icon: Icons.people_alt_rounded),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: movie.cast.map((actor) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            actor,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // PULSANTI DI AZIONE BOTTOM
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.textSecondary),
                          label: const Text(
                            'Già Visto',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onMarkAsWatched();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: movie.isInUserWatchlist
                                ? AppColors.surfaceElevated
                                : AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            movie.isInUserWatchlist ? Icons.check : Icons.bookmark_add,
                            size: 20,
                          ),
                          label: Text(
                            movie.isInUserWatchlist ? 'In Watchlist' : 'Salva in Watchlist',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onWatchlistToggle();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryOrange),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String iconText;
  final String label;
  final String value;
  final Color highlightColor;

  const _ScoreBadge({
    required this.iconText,
    required this.label,
    required this.value,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(iconText, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlightColor,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  final String title;
  final Color color;
  final List<WatchProvider> providers;

  const _ProviderGroup({
    required this.title,
    required this.color,
    required this.providers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: providers.map((p) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: p.fullLogoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.providerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _MetaChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
