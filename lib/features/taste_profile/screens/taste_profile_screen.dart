import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/letterboxd_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/screens/sync_profile_screen.dart';

class TasteProfileScreen extends ConsumerWidget {
  const TasteProfileScreen({super.key});

  Future<void> _handleFileImport(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'csv'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final fileName = file.name.toLowerCase();
      final isZip = fileName.endsWith('.zip');

      HapticFeedback.lightImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isZip
                  ? 'Decompressione archivio .ZIP Letterboxd in corso...'
                  : 'Lettura file CSV Letterboxd in corso...',
            ),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final letterboxdService = ref.read(letterboxdServiceProvider);
      final recommendationEngine = ref.read(recommendationEngineProvider);

      List<LetterboxdMovie> movies = [];
      if (isZip) {
        List<int> bytes;
        if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          bytes = await file.xFile.readAsBytes();
        }
        movies = letterboxdService.parseLetterboxdZip(bytes);
      } else {
        String? content;
        if (file.path != null) {
          content = await File(file.path!).readAsString();
        } else {
          content = await file.xFile.readAsString();
        }
        if (content.isNotEmpty) {
          movies = letterboxdService.parseLetterboxdCsv(content);
        }
      }

      if (movies.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nessun film riconosciuto nel file. Seleziona lo .zip scaricato da Letterboxd o un CSV valido (ratings.csv / watched.csv).',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      String username = ref.read(activeUserProvider) ?? '';
      if ((username.isEmpty || username == 'Ospite') && fileName.contains('letterboxd-')) {
        final parts = fileName.split('-');
        if (parts.length >= 2) username = parts[1];
      }
      if (username.isEmpty || username == 'Ospite') username = 'LetterboxdUser';

      await LocalStorageService.setActiveUsername(username);
      await LocalStorageService.saveLetterboxdMovies(movies);

      final profile = await recommendationEngine.buildTasteProfile(username, movies);

      ref.read(activeUserProvider.notifier).setUsername(username);
      ref.read(userLetterboxdMoviesProvider.notifier).setMovies(movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);
      ref.read(recommendationsProvider.notifier).loadRecommendations(forceRefresh: true);

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Importati con successo ${movies.length} film di @$username!'),
            backgroundColor: AppColors.primaryOrange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore importazione: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasteProfile = ref.watch(tasteProfileProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final activeFilters = ref.watch(activeProvidersFilterProvider);
    final username = ref.watch(activeUserProvider) ?? 'Cinefilo';
    final bottomInset = MediaQuery.of(context).padding.bottom + 110;

    final countryProvidersAsync = ref.watch(countryProvidersListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          username == 'Ospite' ? 'Profilo Ospite' : '@$username',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (tasteProfile != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primaryOrange),
              tooltip: 'Ricalcola raccomandazioni',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(recommendationsProvider.notifier).loadRecommendations(forceRefresh: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ricalcolo delle raccomandazioni in corso...'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SE NON HA ANCORA COLLEGATO LETTERBOXD (GUEST MODE)
            if (tasteProfile == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.primaryOrange.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primaryOrange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Collega il tuo Letterboxd',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Stai usando CinePulse in modalità ospite. Importa il tuo file .zip esportato da Letterboxd per visualizzare le tue statistiche e sbloccare le raccomandazioni su misura per te!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.folder_zip_rounded, size: 20),
                        label: const Text(
                          'Importa archivio .ZIP Letterboxd',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        onPressed: () => _handleFileImport(context, ref),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SyncProfileScreen()),
                          );
                        },
                        child: const Text(
                          'Oppure sincronizza tramite username',
                          style: TextStyle(color: AppColors.amberFlame, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
            ] else ...[
              // BENTO GRID STATS OVERVIEW
              Row(
                children: [
                  Expanded(
                    child: _BentoStatCard(
                      title: 'FILM VISTI',
                      value: '${tasteProfile.totalWatched}',
                      icon: Icons.movie_filter_rounded,
                      accentColor: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BentoStatCard(
                      title: 'VOTATI',
                      value: '${tasteProfile.totalRated}',
                      icon: Icons.star_half_rounded,
                      accentColor: AppColors.amberFlame,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BentoStatCard(
                      title: 'MEDIA VOTO',
                      value: tasteProfile.averageRating > 0
                          ? '★ ${tasteProfile.averageRating}'
                          : 'N/A',
                      icon: Icons.auto_awesome,
                      accentColor: AppColors.electricCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BentoStatCard(
                      title: 'IN WATCHLIST',
                      value: '${tasteProfile.totalInWatchlist}',
                      icon: Icons.bookmark_added_rounded,
                      accentColor: AppColors.velvetPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tasto Aggiorna/Reimporta ZIP
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.folder_zip_outlined, color: AppColors.primaryOrange, size: 18),
                  label: const Text(
                    'Aggiorna o reimporta archivio .ZIP',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _handleFileImport(context, ref),
                ),
              ),

              const SizedBox(height: 28),
            ],

            // SELEZIONE NAZIONE STREAMING
            const _Header(
              title: 'Nazione Streaming (JustWatch)',
              subtitle: 'I provider e i prezzi mostrati si adatteranno a questo paese',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCountry,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryOrange),
                  items: AppConfig.supportedCountries.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          Text(
                            entry.key == 'IT'
                                ? '🇮🇹 '
                                : entry.key == 'US'
                                    ? '🇺🇸 '
                                    : entry.key == 'GB'
                                        ? '🇬🇧 '
                                        : '🌍 ',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      LocalStorageService.setSelectedCountry(val);
                      ref.read(selectedCountryProvider.notifier).setCountry(val);
                      ref.refresh(countryProvidersListProvider);
                      ref.refresh(nowPlayingMoviesProvider);
                      ref.refresh(topRatedMoviesProvider);
                      ref.read(recommendationsProvider.notifier).loadRecommendations();
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            // FILTRO PROVIDER STREAMING (ABBONAMENTO CON LOGHI IN ORDINE A-Z)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _Header(
                    title: 'I Tuoi Abbonamenti Streaming',
                    subtitle: 'Piattaforme disponibili (A-Z con loghi ufficiali)',
                  ),
                ),
                if (activeFilters.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      LocalStorageService.setSelectedStreamingProviders([]);
                      ref.read(activeProvidersFilterProvider.notifier).setProviders([]);
                      ref.read(recommendationsProvider.notifier).loadRecommendations();
                    },
                    child: const Text(
                      'Resetta',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            countryProvidersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2),
                ),
              ),
              error: (_, __) => _buildProvidersWrap(
                AppConfig.getKnownProvidersForCountry(selectedCountry),
                activeFilters,
                ref,
              ),
              data: (providers) => _buildProvidersWrap(
                providers,
                activeFilters,
                ref,
              ),
            ),

            if (tasteProfile != null) ...[
              const SizedBox(height: 30),

              // GUSTO CINEMATOGRAFICO (BARRE % GENERI)
              const _Header(
                title: 'Gusto Cinematografico',
                subtitle: 'Distribuzione statistica dei generi che guardi di più',
              ),
              const SizedBox(height: 14),

              ...(tasteProfile.genrePercentages.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(6)
                  .map((entry) {
                  final pct = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (pct / 100.0).clamp(0.05, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryOrange,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 30),

              // REGISTI RICORRENTI
              if (tasteProfile.topDirectors.isNotEmpty) ...[
                const _Header(
                  title: 'Registi Ricorrenti',
                  subtitle: 'Autori più presenti nella tua storia di visioni',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tasteProfile.topDirectors.map((director) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_creation_outlined, size: 14, color: AppColors.electricCyan),
                          const SizedBox(width: 6),
                          Text(
                            director,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
              ],
            ],

            const SizedBox(height: 10),

            // DISCONNETTI ACCOUNT O CAMBIA USERNAME
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                label: Text(
                  username == 'Ospite' ? 'Torna alla schermata di sincronizzazione' : 'Cambia account Letterboxd',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceElevated,
                      title: const Text('Disconnetti profilo?'),
                      content: const Text(
                        'Vuoi rimuovere i dati memorizzati e cambiare account o sincronizzazione?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Annulla'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Disconnetti',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await LocalStorageService.clearUser();
                    ref.read(activeUserProvider.notifier).setUsername(null);
                    ref.read(tasteProfileProvider.notifier).setProfile(null);
                    ref.read(userLetterboxdMoviesProvider.notifier).setMovies([]);
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SyncProfileScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersWrap(
    List<Map<String, String>> providers,
    List<String> activeFilters,
    WidgetRef ref,
  ) {
    if (providers.isEmpty) {
      return const Text(
        'Nessun provider registrato per questa nazione.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: providers.map((p) {
        final name = p['name'] ?? '';
        final logo = p['logo'] ?? '';
        final isSelected = activeFilters.any((f) => f.toLowerCase() == name.toLowerCase());

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final updated = List<String>.from(activeFilters);
            if (isSelected) {
              updated.removeWhere((f) => f.toLowerCase() == name.toLowerCase());
            } else {
              updated.add(name);
            }
            LocalStorageService.setSelectedStreamingProviders(updated);
            ref.read(activeProvidersFilterProvider.notifier).setProviders(updated);
            ref.read(recommendationsProvider.notifier).loadRecommendations();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryOrange.withOpacity(0.18)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primaryOrange : AppColors.borderSubtle,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: logo,
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 22, height: 22, color: Colors.white10),
                    errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 16, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 14, color: AppColors.primaryOrange),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
