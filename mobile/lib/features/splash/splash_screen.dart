import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Logo(size: 110),
            SizedBox(height: 28),
            Text(
              'اطمئن... وصلت إلى وجهتك الأولى\nللإسعافات الأولية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, height: 1.7, fontWeight: FontWeight.w600, color: AppColors.brand),
            ),
          ]),
        ),
      ),
    );
  }
}
