import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LogoCooperadoraWidget extends StatelessWidget {
  final double size;
  final double borderRadius;

  const LogoCooperadoraWidget({
    super.key,
    this.size = 80,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final logoUrl = data['logoUrl'] as String?;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.celesteBorde),
            color: AppTheme.celesteFondo,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: logoUrl != null
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.azulMedio, strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, err, st) => Icon(Icons.school,
                        size: size * 0.5, color: AppTheme.azulMedio),
                  )
                : Icon(Icons.school,
                    size: size * 0.5, color: AppTheme.azulMedio),
          ),
        );
      },
    );
  }
}
