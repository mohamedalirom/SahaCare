import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import '../../i18n/strings.g.dart';

class MainLayoutShell extends StatefulWidget {
  const MainLayoutShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<MainLayoutShell> createState() => _MainLayoutShellState();
}

class _MainLayoutShellState extends State<MainLayoutShell> {
  // Navigation bar starts visible
  bool _isHidden = false; 

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern is to go to the initial location when tapping the item that is already active.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Le contenu principal défilant
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // 1. Détection du défilement bidirectionnel
              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.forward) {
                  if (_isHidden) setState(() => _isHidden = false);
                } else if (notification.direction == ScrollDirection.reverse) {
                  if (!_isHidden) setState(() => _isHidden = true);
                }
              }
              
              // 2. Gestion des cas extrêmes : sommet absolu ou bas absolu
              if (notification is ScrollUpdateNotification) {
                if (notification.metrics.pixels <= 0 && _isHidden) {
                  setState(() => _isHidden = false);
                }
                if (notification.metrics.pixels >= notification.metrics.maxScrollExtent && _isHidden) {
                  setState(() => _isHidden = false);
                }
              }
              return false; 
            },
            child: widget.navigationShell,
          ),
          
          // La barre de navigation flottante
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            // Défilement vers le bas : Glisser hors de l'écran (-100)
            // Défilement vers le haut : Réapparition fluide (24)
            bottom: _isHidden ? -100.0 : (24.0 + MediaQuery.paddingOf(context).bottom),
            left: 48.0,
            right: 48.0,
            child: Container(
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildNavItem(0, Icons.person_outline, Icons.person, t.navProfile),
                        _buildNavItem(1, Icons.medication_outlined, Icons.medication, t.navMedications),
                        _buildNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, t.navAppointments),
                        _buildNavItem(3, Icons.monitor_heart_outlined, Icons.monitor_heart, t.navTracking),
                        _buildNavItem(4, Icons.folder_shared_outlined, Icons.folder_shared, t.navDocuments),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = widget.navigationShell.currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () => _goBranch(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.transparent, // Ensures the entire Expanded area is tap-friendly
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                width: 50.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorScheme.primary.withValues(alpha: 0.15) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedScale(
                    scale: 0.9,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected 
                          ? colorScheme.primary 
                          : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
