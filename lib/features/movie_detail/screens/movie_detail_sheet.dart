import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/tmdb_movie.dart';
import '../../../core/models/watch_provider.dart';
import '../../../core/network/tmdb_client.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/person_filmography_sheet.dart';

class MovieDetailSheet extends StatefulWidget {
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

  @override
  State<MovieDetailSheet> createState() => _MovieDetailSheetState();
}

class _MovieDetailSheetState extends State<MovieDetailSheet> {
  late TmdbMovie _movie;
  YoutubePlayerController? _youtubeController;
  bool _isMuted = true;
  bool _isPlaying = true;
  late bool _isInWatchlist;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _isInWatchlist = widget.movie.isInUserWatchlist;
    _initTrailer();
    _loadFullDetailsIfNeeded();
  }

  void _initTrailer() {
    final key = _movie.trailerKey;
    if (key != null && key.isNotEmpty) {
      _youtubeController?.close();
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: key,
        autoPlay: true,
        params: const YoutubePlayerParams(
          mute: true,
          showControls: false,
          showFullscreenButton: false,
          loop: true,
        ),
      );
      _isPlaying = true;
    }
  }

  Future<void> _loadFullDetailsIfNeeded() async {
    if (_movie.castMembers.isEmpty || _movie.trailerKey == null || _movie.directorId == null) {
      try {
        final client = TmdbClient();
        final detailed = await client.getMovieDetails(_movie.id, countryCode: widget.countryCode);
        if (detailed != null && mounted) {
          setState(() {
            _movie = detailed.copyWith(
              isInUserWatchlist: _isInWatchlist,
              matchScore: _movie.matchScore > 0 ? _movie.matchScore : detailed.matchScore,
              matchReasons: _movie.matchReasons.isNotEmpty ? _movie.matchReasons : detailed.matchReasons,
            );
            if (_youtubeController == null && _movie.trailerKey != null) {
              _initTrailer();
            }
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  void _openPersonFilmography({
    int? personId,
    required String name,
    String? profileUrl,
    required bool isDirector,
  }) {
    if (personId == null) return;
    HapticFeedback.lightImpact();
    PersonFilmographySheet.show(
      context,
      personId: personId,
      personName: name,
      profileUrl: profileUrl,
      role: isDirector ? 'Regista' : 'Attore',
      isDirector: isDirector,
      countryCode: widget.countryCode,
    );
  }

  Future<void> _launchTrailer(BuildContext context) async {
    final String url;
    if (_movie.trailerKey != null && _movie.trailerKey!.isNotEmpty) {
      url = 'https://www.youtube.com/watch?v=${_movie.trailerKey}';
    } else {
      url = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${_movie.title} official trailer')}';
    }

    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        final webLaunched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
        if (!webLaunched) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossibile aprire il trailer: $e'),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatrateProviders = _movie.flatrateProviders(widget.countryCode);
    final freeProviders = _movie.freeProviders(widget.countryCode);
    final rentProviders = _movie.rentProviders(widget.countryCode);
    final buyProviders = _movie.buyProviders(widget.countryCode);
    final countryName = AppConfig.supportedCountries[widget.countryCode] ?? widget.countryCode;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar Collassabile con Trailer Netflix-Style o Backdrop HD
          SliverAppBar(
            expandedHeight: 228,
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
                      _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                      color: _isInWatchlist
                          ? AppColors.primaryOrange
                          : Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isInWatchlist = !_isInWatchlist;
                      });
                      widget.onWatchlistToggle();
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
                  // 1. Video Player Trailer or Backdrop (16:9 esatto, non ritagliato)
                  if (_youtubeController != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: YoutubePlayer(
                            controller: _youtubeController!,
                            aspectRatio: 16 / 9,
                          ),
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: _movie.backdropUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                      errorWidget: (_, __, ___) => Container(color: AppColors.surface),
                    ),

                  // 2. Gradienti discreti per contrasto e leggibilità (IgnorePointer per non bloccare i tocchi)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.35, 0.75, 1.0],
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              AppColors.background.withOpacity(0.6),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Fallback con bottone esplicito se non c'è controller trailer
                  if (_youtubeController == null)
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
                  // Barra Controlli Trailer Dedicata (Separata dal video, senza alcuna sovrapposizione)
                  if (_youtubeController != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.movie_filter_rounded, color: Color(0xFF00E676), size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Trailer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          // Play / Pause
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (_isPlaying) {
                                    _youtubeController?.pauseVideo();
                                    _isPlaying = false;
                                  } else {
                                    _youtubeController?.playVideo();
                                    _isPlaying = true;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isPlaying ? 'Pausa' : 'Play',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Mute / Unmute
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (_isMuted) {
                                    _youtubeController?.unMute();
                                    _isMuted = false;
                                  } else {
                                    _youtubeController?.mute();
                                    _isMuted = true;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: _isMuted ? Colors.white54 : const Color(0xFF00E676),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isMuted ? 'Muto' : 'Audio',
                                      style: TextStyle(
                                        color: _isMuted ? Colors.white70 : const Color(0xFF00E676),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Apri YouTube Esterno
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _launchTrailer(context),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: const Icon(
                                  Icons.open_in_new_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Poster + Titolo + Metadati + Regista Cliccabile
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'poster_${_movie.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: _movie.posterUrl,
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
                              _movie.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Regista interattivo con foto e filmografia
                            if (_movie.director != null) ...[
                              GestureDetector(
                                onTap: () => _openPersonFilmography(
                                  personId: _movie.directorId,
                                  name: _movie.director!,
                                  profileUrl: _movie.directorProfileUrl,
                                  isDirector: true,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.electricCyan.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_movie.directorProfileUrl != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            imageUrl: _movie.directorProfileUrl!,
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(
                                              Icons.movie_creation_outlined,
                                              size: 16,
                                              color: AppColors.electricCyan,
                                            ),
                                          ),
                                        )
                                      else
                                        const Icon(Icons.movie_creation_outlined, size: 16, color: AppColors.electricCyan),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          'Regia: ${_movie.director}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.electricCyan,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.electricCyan),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (_movie.releaseYear.isNotEmpty)
                                  _MetaChip(label: _movie.releaseYear),
                                if (_movie.formattedRuntime.isNotEmpty)
                                  _MetaChip(label: _movie.formattedRuntime),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Match Score
                            if (_movie.matchScore > 0)
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
                                  '${_movie.matchScore.toInt()}% CinePulse Match',
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
                          value: _movie.rottenTomatoesScore ?? '91%',
                          highlightColor: Colors.redAccent,
                        ),
                        // LETTERBOXD
                        _ScoreBadge(
                          iconText: '🟢',
                          label: 'Letterboxd',
                          value: '★ ${_movie.letterboxdScore ?? '4.2'}',
                          highlightColor: AppColors.primaryOrange,
                        ),
                        // IMDB
                        _ScoreBadge(
                          iconText: '⭐',
                          label: 'IMDb',
                          value: _movie.imdbScore != null ? '${_movie.imdbScore}/10' : '${_movie.voteAverage.toStringAsFixed(1)}/10',
                          highlightColor: Colors.amber,
                        ),
                        // METACRITIC
                        if (_movie.metacriticScore != null)
                          _ScoreBadge(
                            iconText: 'Ⓜ️',
                            label: 'Metacritic',
                            value: _movie.metacriticScore!,
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
                  if (_movie.matchReasons.isNotEmpty) ...[
                    const _SectionTitle(
                      title: 'Perché fa al caso tuo',
                      icon: Icons.auto_awesome,
                    ),
                    const SizedBox(height: 10),
                    ..._movie.matchReasons.map(
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
                    _movie.overview.isNotEmpty
                        ? _movie.overview
                        : 'Nessuna sinossi disponibile in italiano.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CAST PRINCIPALE CON FOTO E FILMOGRAFIA INTERATTIVA
                  if (_movie.castMembers.isNotEmpty) ...[
                    const _SectionTitle(title: 'Cast Principale', icon: Icons.people_alt_rounded),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 135,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _movie.castMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final actor = _movie.castMembers[index];
                          return GestureDetector(
                            onTap: () => _openPersonFilmography(
                              personId: actor.id,
                              name: actor.name,
                              profileUrl: actor.profileUrl,
                              isDirector: false,
                            ),
                            child: SizedBox(
                              width: 78,
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      color: AppColors.surfaceElevated,
                                      child: actor.profileUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: actor.profileUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(color: Colors.white10),
                                              errorWidget: (_, __, ___) => const Icon(
                                                Icons.person,
                                                size: 32,
                                                color: Colors.white30,
                                              ),
                                            )
                                          : const Icon(Icons.person, size: 32, color: Colors.white30),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    actor.name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                  if (actor.character != null && actor.character!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      actor.character!,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                  ] else if (_movie.cast.isNotEmpty) ...[
                    const _SectionTitle(title: 'Cast Principale', icon: Icons.people_alt_rounded),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _movie.cast.map((actor) {
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
                            widget.onMarkAsWatched();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isInWatchlist
                                ? AppColors.surfaceElevated
                                : AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            _isInWatchlist ? Icons.check : Icons.bookmark_add,
                            size: 20,
                          ),
                          label: Text(
                            _isInWatchlist ? 'In Watchlist' : 'Salva in Watchlist',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isInWatchlist = !_isInWatchlist;
                            });
                            widget.onWatchlistToggle();
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
