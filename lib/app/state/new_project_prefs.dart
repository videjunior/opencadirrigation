/// What a new project starts with (1.6.0 MOD): the mains frequency and the
/// currency of the user's region (by the locale of the machine), unless the
/// user chose others; the display units the user chose (never the US ones
/// by the region alone); and, when the user kept them, the design
/// parameters of a project (velocities, economics, losses…) as the
/// template of the next ones. Kept in the browser, per device.
library;

import 'dart:convert';

import '../../core/model/currency.dart' show currencyForLocale, exchangeRate;
import '../../core/model/project.dart';
import '../../core/model/regional.dart';
import '../../core/units.dart';
import '../io/prefs.dart';
import 'controller.dart';

/// Preference keys of the choices for new projects.
const newProjectParamsPref = 'params.template', newProjectCurrencyPref = 'currency', newProjectHzPref = 'mainsHz', newProjectUnitsPref = 'units';

/// Where a default of new projects comes from.
enum DefaultSource {
  /// The user's choice, kept on this device.
  chosen,

  /// The region of the machine (its locale).
  region,

  /// The program's default (no region known, or a choice the region never
  /// makes: the display units).
  program,
}

/// The new-project choices, on the controller.
extension NewProjectPrefs on ProjectController {
  /// Keeps the design parameters of the open project (velocities, losses,
  /// economics, units, mains frequency, currency…) as those every new
  /// project starts with on this device.
  void saveParamsAsDefault() {
    final p = project.params;
    setPref(newProjectParamsPref, jsonEncode(p.toJson()));
    if (p.currencyCode.isNotEmpty) setPref(newProjectCurrencyPref, p.currencyCode);
    setPref(newProjectHzPref, '${p.mainsHz.round()}');
    setPref(newProjectUnitsPref, jsonEncode(p.units.toJson()));
    notify(t('npd.saved'));
  }

  /// Forgets every choice: new projects start again with the mains
  /// frequency and currency of the region, metric units and the program's
  /// parameters.
  void clearParamsDefault() {
    for (final k in const [newProjectParamsPref, newProjectCurrencyPref, newProjectHzPref, newProjectUnitsPref]) {
      removePref(k);
    }
    notify(t('npd.cleared'));
  }

  /// Whether the user kept any choice for new projects.
  bool get hasNewProjectChoices => [newProjectParamsPref, newProjectCurrencyPref, newProjectHzPref, newProjectUnitsPref].any((k) => getPref(k) != null);

  /// The parameters kept with [saveParamsAsDefault] put on the new
  /// [project], whose currency (that of its catalogue) stays: the energy
  /// price kept in another currency is converted. Nothing without a
  /// template (or with a damaged one).
  void applyNewProjectTemplate() {
    final saved = getPref(newProjectParamsPref);
    if (saved == null) return;
    try {
      final p = DesignParameters.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      final code = project.params.currencyCode, symbol = project.params.currency;
      if (p.currencyCode != code) {
        final rate = exchangeRate(p.currencyCode, code);
        p.powerCostPerKwh = rate == null ? project.params.powerCostPerKwh : p.powerCostPerKwh * rate;
      }
      p
        ..currencyCode = code
        ..currency = symbol;
      project.params = p;
    } catch (_) {
      // a template of another version that cannot be read: the defaults
    }
  }

  /// The region (ISO 3166) of the machine for the interface language, or
  /// null.
  String? get machineRegion => regionForLocale(lang, ProjectController.systemLanguageTags());

  /// Where the mains frequency, the currency and the units of new projects
  /// come from.
  ({DefaultSource hz, DefaultSource currency, DefaultSource units}) get newProjectSources => (
    hz: getPref(newProjectHzPref) != null ? DefaultSource.chosen : (machineRegion != null ? DefaultSource.region : DefaultSource.program),
    currency: getPref(newProjectCurrencyPref) != null ? DefaultSource.chosen : (machineRegion != null ? DefaultSource.region : DefaultSource.program),
    units: getPref(newProjectUnitsPref) != null ? DefaultSource.chosen : DefaultSource.program,
  );

  /// What new projects start with, in a line: "60 Hz (region BR), BRL (your
  /// choice), metric units (default)".
  String newProjectDefaultsText() {
    final s = newProjectSources;
    final region = machineRegion ?? '';
    String from(DefaultSource x) => switch (x) {
      DefaultSource.chosen => t('npd.fromChoice'),
      DefaultSource.region => t('npd.fromRegion', {'r': region}),
      DefaultSource.program => t('npd.fromProgram'),
    };
    final u = defaultUnits();
    final unitsName = jsonEncode(u.toJson()) == jsonEncode(Units.metric.toJson())
        ? t('dlg.metric')
        : (jsonEncode(u.toJson()) == jsonEncode(Units.us.toJson()) ? t('dlg.us') : '${u.lengthLabel}, ${u.flowLabel}, ${u.pressureLabel}');
    final hz = defaultMainsHz().round();
    final cur = getPref(newProjectCurrencyPref) ?? currencyForLocale(lang, ProjectController.systemLanguageTags());
    return t('npd.now', {
      'hz': '$hz Hz',
      'hzFrom': from(s.hz),
      'c': cur,
      'cFrom': from(s.currency),
      'u': unitsName,
      'uFrom': from(s.units),
      'p': getPref(newProjectParamsPref) != null ? t('npd.withTemplate') : '',
    });
  }
}
