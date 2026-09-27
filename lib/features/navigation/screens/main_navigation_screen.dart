import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalog/screens/catalog_screen.dart';
import '../../discovery/screens/discovery_screen.dart';
import '../../taste_profile/screens/taste_profile_screen.dart';
import '../../watchlist/screens/watchlist_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = const [
    DiscoveryScreen(),
    CatalogScreen(),
    WatchlistScreen(),
    TasteProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncLetterboxd();
    });
  }

  Future<void> _autoSyncLetterboxd() async {
    final username = ref.read(activeUserProvider);
    if (username != null && username.isNotEmpty && username.toLowerCase() != 'ospite') {
      final updatedCount = await ref.read(userLetterboxdMoviesProvider.notifier).syncRecentFromLetterboxd(username);
      if (updatedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync_rounded, color: Color(0xFF00E676), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronizzato con Letterboxd: $updatedCount modifiche aggiornate!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF1E2430),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(navTabProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Screen Corrente
          IndexedStack(
            index: currentTab,
            children: _screens,
          ),

          // Floating Glassmorphic Bottom Navigation Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomInset > 0 ? bottomInset + 8 : 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavBarItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Per Te',
                        isSelected: currentTab == 0,
                        onTap: () => _onTabSelected(0),
                      ),
                      _NavBarItem(
                        icon: Icons.movie_filter_rounded,
                        label: 'Liste',
                        isSelected: currentTab == 1,
                        onTap: () => _onTabSelected(1),
                      ),
                      _NavBarItem(
                        icon: Icons.bookmark_added_rounded,
                        label: 'Watchlist',
                        isSelected: currentTab == 2,
                        onTap: () => _onTabSelected(2),
                      ),
                      _NavBarItem(
                        icon: Icons.person_rounded,
                        label: 'Profilo',
                        isSelected: currentTab == 3,
                        onTap: () => _onTabSelected(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    if (index != ref.read(navTabProvider)) {
      HapticFeedback.lightImpact();
      ref.read(navTabProvider.notifier).setTab(index);
    }
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withOpacity(0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryOrange : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryOrange : AppColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
