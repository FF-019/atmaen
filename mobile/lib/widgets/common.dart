import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/images/logo.svg', width: size, height: size);
}

/// Card with a hairline border instead of a shadow. Shadows on a warm
/// background looked dirty in testing.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key});
  final String severity;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.severity(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.severitySoft(severity), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(severityLabel(severity), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft, letterSpacing: 0.2)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: AppColors.ink,
      child: const Row(children: [
        Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text('أنت غير متصل. الإرشادات الأساسية تعمل بدون إنترنت.',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    );
  }
}

Future<void> callNumber(String number) => launchUrl(Uri(scheme: 'tel', path: number));

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating));
}

IconData stepIcon(String? key) => switch (key) {
      'phone' => Icons.call_rounded,
      'hospital' => Icons.local_hospital_rounded,
      'water' => Icons.water_drop_outlined,
      'cup' => Icons.local_drink_outlined,
      'shower' => Icons.shower_outlined,
      'eye' => Icons.visibility_outlined,
      'lungs' => Icons.air_rounded,
      'sit' => Icons.event_seat_outlined,
      'no-food' => Icons.no_food_outlined,
      'package' => Icons.inventory_2_outlined,
      'hand' => Icons.back_hand_outlined,
      'count' => Icons.format_list_numbered_rounded,
      'clock' => Icons.schedule_rounded,
      'chat' => Icons.forum_outlined,
      'camera' => Icons.photo_camera_outlined,
      'wind' => Icons.wind_power_outlined,
      'recovery' => Icons.airline_seat_flat_outlined,
      'honey' => Icons.hive_outlined,
      _ => Icons.info_outline_rounded,
    };
