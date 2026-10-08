import 'package:flutter/material.dart';

/// Wrapper permettant d'afficher l'application dans un cadre réaliste de Smartphone
/// (Idéal pour la visualisation dans VS Code / Navigateur sans configuration complexe)
class PhoneFrameWrapper extends StatelessWidget {
  final Widget child;

  const PhoneFrameWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si l'écran est déjà de taille mobile (< 550px), on affiche plein écran
        if (constraints.maxWidth < 550) {
          return child;
        }

        // Sinon, on affiche le smartphone virtuel centré avec son cadre et son ombre 3D
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A), // Fond sombre premium pour faire ressortir le téléphone
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Container(
                width: 412,
                height: 860,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(color: const Color(0xFF334155), width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(42),
                  child: Stack(
                    children: [
                      // Contenu de l'application mobile
                      Positioned.fill(
                        child: child,
                      ),

                      // Dynamic Island / Encoche smartphone en haut
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 110,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Barre d'accueil en bas (Home Indicator)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 130,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(10),
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
      },
    );
  }
}
