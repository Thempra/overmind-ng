import 'package:flutter/material.dart';

import '../theme.dart';

/// Tarjeta de acción grande, coherente con la estética del juego.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 20, vertical: big ? 26 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.6), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.22),
                blurRadius: big ? 20 : 12,
              ),
            ],
            gradient: LinearGradient(
              colors: [
                OvermindColors.panel,
                accent.withOpacity(0.14),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: big ? 54 : 44,
                height: big ? 54 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.16),
                  border: Border.all(color: accent),
                ),
                child: Icon(icon, color: accent,
                    size: big ? 28 : 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        fontSize: big ? 20 : 17,
                        color: OvermindColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OvermindColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
