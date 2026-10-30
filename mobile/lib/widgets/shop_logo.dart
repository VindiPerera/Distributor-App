import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Shop logo loaded from the backend's public asset URL, with a storefront
/// icon fallback while loading or if the image fails (e.g. offline).
class ShopLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const ShopLogo({super.key, this.size = 40, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.network(
          ApiClient.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _fallback();
          },
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: size * 0.5,
        color: AppColors.accent,
      ),
    );
  }
}
