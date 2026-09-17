/// First-run welcome: a short introduction, the example gallery (open a
/// ready project) and the interactive tutorial. Reopened from Help →
/// Welcome and example gallery.
library;

import 'package:flutter/material.dart';

import '../../actions.dart';
import '../../examples.dart';
import '../../state/controller.dart';
import '../../version.dart';

enum WelcomeChoice { tutorial, example, skip }

IconData exampleIcon(ExampleId id) => switch (id) {
  ExampleId.orchard => Icons.park_outlined,
  ExampleId.garden => Icons.yard_outlined,
  ExampleId.sportsField => Icons.sports_soccer_outlined,
  ExampleId.rowCrop => Icons.grass_outlined,
  ExampleId.pivot => Icons.radar_outlined,
  ExampleId.greenhouse => Icons.warehouse_outlined,
  ExampleId.nursery => Icons.local_florist_outlined,
  ExampleId.coffee => Icons.coffee_outlined,
  ExampleId.bananas => Icons.nature_outlined,
  ExampleId.sugarcane => Icons.eco_outlined,
  ExampleId.gravity => Icons.terrain_outlined,
  ExampleId.pasture => Icons.agriculture_outlined,
  ExampleId.golf => Icons.golf_course_outlined,
  ExampleId.sectorPivot => Icons.pie_chart_outline,
  ExampleId.linear => Icons.linear_scale,
};

/// Shows the welcome dialog. Choosing an example loads it into [c] and
/// returns [WelcomeChoice.example]; the caller starts the tutorial when
/// [WelcomeChoice.tutorial] comes back.
Future<WelcomeChoice> showWelcomeDialog(BuildContext context, ProjectController c, {bool firstRun = false}) async {
  final t = c.t;
  final r = await showDialog<WelcomeChoice>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (ctx) {
      final width = MediaQuery.sizeOf(ctx).width;
      final compact = width < 720;
      final cardWidth = compact ? (width - 96).clamp(200.0, 320.0) : 200.0;
      return AlertDialog(
        title: Row(children: [
          Image.asset('assets/brand/logo-mark.png', height: 34, filterQuality: FilterQuality.medium),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t('welcome.title')),
              // exact build shown at start-up: version, build number, date, commit
              Text(t('about.version', {'v': appVersionLabel}), key: const Key('welcome_version'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, fontFamily: 'monospace', color: Colors.white54)),
            ]),
          ),
        ]),
        content: SizedBox(
          width: compact ? double.maxFinite : 680,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('welcome.body'), style: const TextStyle(height: 1.4, fontSize: 13)),
              const SizedBox(height: 14),
              Text(t('welcome.examples'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(t('welcome.examplesHint'), style: const TextStyle(fontSize: 11.5, color: Colors.white60, height: 1.35)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ex in exampleGallery)
                    _ExampleCard(
                      key: Key('example_${ex.id.name}'),
                      icon: exampleIcon(ex.id),
                      title: t(ex.titleKey),
                      subtitle: t(ex.subtitleKey),
                      tags: t(ex.tagsKey),
                      width: cardWidth,
                      open: t('welcome.open'),
                      onTap: () {
                        loadExampleAction(c, ex.id);
                        Navigator.pop(ctx, WelcomeChoice.example);
                      },
                    ),
                ],
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(key: const Key('tut_skip'), onPressed: () => Navigator.pop(ctx, WelcomeChoice.skip), child: Text(t('welcome.skip'))),
          FilledButton.icon(key: const Key('tut_start'), onPressed: () => Navigator.pop(ctx, WelcomeChoice.tutorial), icon: const Icon(Icons.school_outlined, size: 18), label: Text(t('welcome.tutorial'))),
        ],
      );
    },
  );
  return r ?? WelcomeChoice.skip;
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({super.key, required this.icon, required this.title, required this.subtitle, required this.tags, required this.width, required this.open, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String tags;
  final double width;
  final String open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFF232830),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 22, color: const Color(0xFF64B5F6)),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ]),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3), maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(tags, style: const TextStyle(fontSize: 10.5, color: Colors.white38))),
                Text(open, style: const TextStyle(fontSize: 11, color: Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
