import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../emergency/identify_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// First screen for a logged out user. The emergency button is here on
/// purpose: nobody should have to create an account while their child is
/// in danger.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: Logo(size: 44)),
            const Spacer(flex: 2),
            Text('حين يبلع طفلك\nشيئاً لا يجب بلعه', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            const Text(
              'اكتب اسم المادة أو صوّرها، ونعطيك خطوات الإسعاف الأولي فوراً. '
              'ومتطوعون من الأطباء جاهزون للرد عليك.',
              style: TextStyle(fontSize: 16, height: 1.7, color: AppColors.inkSoft),
            ),
            const Spacer(flex: 3),
            _EmergencyNow(onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdentifyScreen()));
            }),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('تسجيل الدخول'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('حساب جديد'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const RegisterScreen(asVolunteer: true))),
                child: const Text('أنا طبيب أو طالب طب وأريد التطوع'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmergencyNow extends StatelessWidget {
  const _EmergencyNow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.signal,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(children: [
            Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('عندي حالة الآن',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('بدون تسجيل، يعمل بدون إنترنت',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            Icon(Icons.arrow_back_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}
