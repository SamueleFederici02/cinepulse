import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/letterboxd_movie.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../navigation/screens/main_navigation_screen.dart';

class SyncProfileScreen extends ConsumerStatefulWidget {
  const SyncProfileScreen({super.key});

  @override
  ConsumerState<SyncProfileScreen> createState() => _SyncProfileScreenState();
}

class _SyncProfileScreenState extends ConsumerState<SyncProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String _syncStep = '';
  int _moviesFound = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _startSync(String username) async {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un username Letterboxd valido.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _moviesFound = 0;
      _syncStep = 'Connessione al profilo Letterboxd...';
    });

    try {
      final letterboxdService = ref.read(letterboxdServiceProvider);
      final recommendationEngine = ref.read(recommendationEngineProvider);

      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _syncStep = 'Scansione cronologia, rating e watchlist...';
      });

      final movies = await letterboxdService.syncUserMovies(
        clean,
        onProgress: (count) {
          if (mounted) {
            setState(() {
              _moviesFound = count;
              _syncStep = 'Sincronizzati $_moviesFound film...';
            });
          }
        },
      );

      setState(() {
        _moviesFound = movies.length;
        _syncStep = 'Analisi di $_moviesFound film e calcolo del gusto...';
      });

      await LocalStorageService.setActiveUsername(clean);
      await LocalStorageService.saveLetterboxdMovies(movies);

      final profile = await recommendationEngine.buildTasteProfile(clean, movies);

      ref.read(activeUserProvider.notifier).setUsername(clean);
      ref.read(userLetterboxdMoviesProvider.notifier).setMovies(movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);

      setState(() {
        _syncStep = 'Completato! Benvenuto su CinePulse.';
      });

      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ref.read(recommendationsProvider.notifier).loadRecommendations();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: const MainNavigationScreen(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _syncStep = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il sync: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importArchiveFile() async {
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
      setState(() {
        _isLoading = true;
        _syncStep = isZip
            ? 'Decompressione archivio .ZIP Letterboxd...'
            : 'Lettura file .CSV Letterboxd...';
      });

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
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessun film riconosciuto nel file. Seleziona il file .zip scaricato da Letterboxd o un CSV valido (ratings.csv / watched.csv).'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Ricava l'username dal textfield oppure dal nome del file zip
      String username = _usernameController.text.trim().replaceAll('@', '');
      if (username.isEmpty && fileName.contains('letterboxd-')) {
        final parts = fileName.split('-');
        if (parts.length >= 2) {
          username = parts[1];
        }
      }
      if (username.isEmpty) {
        username = 'LetterboxdUser';
      }

      setState(() {
        _moviesFound = movies.length;
        _syncStep = 'Trovati $_moviesFound film! Calcolo delle raccomandazioni...';
      });

      await LocalStorageService.setActiveUsername(username);
      await LocalStorageService.saveLetterboxdMovies(movies);

      final profile = await recommendationEngine.buildTasteProfile(username, movies);

      ref.read(activeUserProvider.notifier).setUsername(username);
      ref.read(userLetterboxdMoviesProvider.notifier).setMovies(movies);
      ref.read(tasteProfileProvider.notifier).setProfile(profile);

      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ref.read(recommendationsProvider.notifier).loadRecommendations();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: const MainNavigationScreen(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore importazione file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exploreAsGuest() async {
    HapticFeedback.mediumImpact();
    const guestUser = 'Ospite';
    await LocalStorageService.setActiveUsername(guestUser);
    ref.read(activeUserProvider.notifier).setUsername(guestUser);
    ref.read(userLetterboxdMoviesProvider.notifier).setMovies([]);
    ref.read(tasteProfileProvider.notifier).setProfile(null);
    ref.read(recommendationsProvider.notifier).loadRecommendations();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const MainNavigationScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Sfondo con luci ambientali arancioni
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryOrange.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amberFlame.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LOGO CINEPULSE
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryOrange.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange.withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_movies_rounded,
                          size: 44,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 20),

                    // TITOLO BRAND
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'CINE',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'PULSE',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.primaryOrange,
                            shadows: [
                              Shadow(
                                color: AppColors.primaryOrange.withOpacity(0.6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 8),

                    const Text(
                      'I migliori film scelti dai tuoi gusti Letterboxd.\nZero backend, 100% on-device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 36),

                    if (!_isLoading) ...[
                      // INPUT USERNAME
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tuo username Letterboxd (es. sam021)',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.5),
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              color: AppColors.primaryOrange,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onSubmitted: (val) => _startSync(val),
                        ),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 14),

                      // BOTTONE SINCRONIZZA
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => _startSync(_usernameController.text),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sincronizza Letterboxd',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 14),

                      // BOTTONE IMPORTA ZIP / CSV COMPLETO (PLUG & PLAY PER TUTTI I FILM)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.8), width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            backgroundColor: AppColors.surfaceElevated,
                          ),
                          icon: const Icon(Icons.folder_zip_rounded, color: AppColors.primaryOrange, size: 22),
                          label: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Importa archivio .ZIP o .CSV (Consigliato)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Carica direttamente lo zip esportato da Letterboxd',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          onPressed: _importArchiveFile,
                        ),
                      ).animate().fadeIn(delay: 550.ms),

                      const SizedBox(height: 16),

                      // BOTTONE ENTRA DIRETTAMENTE CON CINEPULSE STANDALONE
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.amberFlame.withOpacity(0.4)),
                        ),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.rocket_launch_rounded, color: AppColors.amberFlame, size: 22),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Inizia senza Letterboxd (CinePulse Standalone)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Esplora film, traccia cosa guardi e ricevi consigli on-device',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          onPressed: _exploreAsGuest,
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ] else ...[
                      // ANIMAZIONE DI STATO SYNC
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primaryOrange.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.primaryOrange,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _syncStep,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _moviesFound > 0
                                  ? 'Trovati $_moviesFound film finora'
                                  : 'Connessione e scansione catalogo',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
                    ],

                    const SizedBox(height: 36),

                    // PRIVACY
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Text(
                          '100% Privacy • Nessun server • Dati solo sul dispositivo',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
