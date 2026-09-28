import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/backup_service.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
import 'features/onboarding/screens/sync_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurazione status bar e navigation bar trasparente per look edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inizializza Hive e SharedPreferences
  await LocalStorageService.init();

  // Verifica ed esegue l'auto-backup giornaliero a rotazione 7 giorni
  BackupService.performAutoBackupIfNeeded();

  runApp(
    const ProviderScope(
      child: CinePulseApp(),
    ),
  );
}

class CinePulseApp extends StatelessWidget {
  const CinePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se c'è già un utente registrato, apri direttamente la navigazione principale
    final activeUser = LocalStorageService.getActiveUsername();

    return MaterialApp(
      title: 'CinePulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: activeUser != null && activeUser.isNotEmpty
          ? const MainNavigationScreen()
          : const SyncProfileScreen(),
    );
  }
}
