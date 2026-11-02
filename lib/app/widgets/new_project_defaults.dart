/// The part of the design parameters dialog about new projects (1.6.0
/// MOD): what they start with and where it comes from (the region of the
/// machine, the user's choice, the program), and the buttons that keep the
/// parameters of this project for the next ones or forget the choices.
library;

import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/new_project_prefs.dart';
import '../theme.dart';
import 'fields.dart';

class NewProjectDefaults extends StatefulWidget {
  const NewProjectDefaults({super.key, required this.c});
  final ProjectController c;

  @override
  State<NewProjectDefaults> createState() => _NewProjectDefaultsState();
}

class _NewProjectDefaultsState extends State<NewProjectDefaults> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = c.t;
    return Column(
      key: const Key('new_project_defaults'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(t('npd.title')),
        Text(c.newProjectDefaultsText(), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(key: const Key('npd_save'), icon: const Icon(Icons.bookmark_add_outlined, size: 16), label: Text(t('npd.save')), onPressed: () => setState(c.saveParamsAsDefault)),
            TextButton.icon(
              key: const Key('npd_clear'),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(t('npd.clear')),
              onPressed: c.hasNewProjectChoices ? () => setState(c.clearParamsDefault) : null,
            ),
          ],
        ),
      ],
    );
  }
}
