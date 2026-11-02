import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/traveller.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/units.dart';

double ft(double v) => v * metersPerFoot;
double gpm(double v) => v * m3sPerGpm;
double psi(double v) => v / psiPerMeterHead;

void main() {
  group('NRCS NEH 623 ch. 11', () {
    test('table 11-31: towpath spacing in percent of the wetted diameter', () {
      expect(laneSpacingPercent(WindClass.none), 80);
      expect(laneSpacingPercent(WindClass.none, taperedNozzle: false), 80);
      expect(laneSpacingPercent(WindClass.light), 75);
      expect(laneSpacingPercent(WindClass.light, taperedNozzle: false), 70);
      expect(laneSpacingPercent(WindClass.moderate), 65);
      expect(laneSpacingPercent(WindClass.moderate, taperedNozzle: false), 60);
      expect(laneSpacingPercent(WindClass.strong), 55);
      expect(laneSpacingPercent(WindClass.strong, taperedNozzle: false), 50);
      expect(windClassOf(0), WindClass.none);
      expect(windClassOf(2.0), WindClass.light);
      expect(windClassOf(4.0), WindClass.moderate);
      expect(windClassOf(6.0), WindClass.strong);
    });

    test('sample calculation 11-17: 515 gpm gun, 455 ft diameter, 2,640 ft field, 2.56 in', () {
      final r = analyzeTraveller(
        TravellerSpec(
          gunFlow: gpm(515),
          gunPressureM: psi(80),
          wettedDiameterM: ft(455),
          wind: WindClass.light,
          fieldWidthM: ft(2640),
          laneLengthM: ft(1320),
          targetDepthMm: 2.56 * 25.4,
          hoseLengthM: ft(660),
          hoseInnerMm: 4.5 * 25.4,
        ),
      );
      // 75 % of 455 ft = 341 ft: eight towpaths 330 ft apart
      expect(r.recommendedPct, 75);
      expect(r.lanes, 8);
      expect(r.laneSpacingM / metersPerFoot, closeTo(330, 1e-9));
      // eq. 11-40: S = 1.605·q/(W·d) = 0.978 ft/min, 1,320 ft in about 22.5 h
      expect(r.speedMPerMin / metersPerFoot, closeTo(1.605 * 515 / (330 * 2.56), 0.002));
      expect(r.travelHours, closeTo(22.5, 0.05));
      expect(r.grossDepthMm, closeTo(2.56 * 25.4, 1e-9));
      expect(r.cycleHours, closeTo(8 * (r.travelHours + 0.5), 1e-9));
      expect(r.areaPerLaneM2, closeTo(ft(330) * ft(1320), 1e-6));
      expect(r.volumePerLaneM3, closeTo(gpm(515) * r.travelHours * 3600, 1e-9));
      // 0.96 ft/min gives 505 gpm for the same depth (the alternative of the example)
      final slower = analyzeTraveller(TravellerSpec(gunFlow: gpm(505), gunPressureM: psi(80), wettedDiameterM: ft(455), fieldWidthM: ft(2640), laneLengthM: ft(1320), speedMPerMin: ft(0.96)));
      expect(slower.grossDepthMm / 25.4, closeTo(2.56, 0.01));
    });

    test('eq. 11-39: application rates of 0.26 and 0.44 in/h for the 0.8 and 1.6 in nozzles at 80 psi', () {
      expect(gunApplicationRate(flow: gpm(165), wettedRadiusM: ft(155)) / 25.4, closeTo(0.26, 0.005));
      expect(gunApplicationRate(flow: gpm(675), wettedRadiusM: ft(240)) / 25.4, closeTo(0.44, 0.005));
      // a half circle doubles the rate
      expect(gunApplicationRate(flow: gpm(165), wettedRadiusM: ft(155), sectorDeg: 180), closeTo(2 * gunApplicationRate(flow: gpm(165), wettedRadiusM: ft(155)), 1e-12));
    });
  });

  group('hydraulics of the hose reel', () {
    const spec = TravellerSpec(
      gunFlow: 30 / 3600,
      gunPressureM: 45,
      wettedDiameterM: 90,
      hoseLengthM: 350,
      hoseInnerMm: 90,
      driveLossM: 8,
      gunHeightM: 2.5,
      groundRiseM: 3,
      speedMPerMin: 0.5,
      wind: WindClass.moderate,
      pumpEfficiency: 0.7,
    );
    final r = analyzeTraveller(spec);

    test('hose friction over the whole hose, inlet pressure and power', () {
      final hf = hazenWilliamsLoss(flow: 30 / 3600, diameter: 0.09, length: 350, c: 150);
      expect(r.hoseFrictionM, closeTo(hf, 1e-12));
      expect(r.inletHeadM, closeTo(45 + hf + 8 + 2.5 + 3, 1e-12));
      expect(r.shaftPowerKw, closeTo(shaftPower(flow: 30 / 3600, head: r.inletHeadM, efficiency: 0.7) / 1000, 1e-12));
      expect(r.hydraulicPowerKw, closeTo(waterDensity * gravity * 30 / 3600 * r.inletHeadM / 1000, 1e-9));
      expect(r.hoseVelocity, closeTo(30 / 3600 / (math.pi * 0.045 * 0.045), 1e-9));
      // Darcy-Weisbach on the same hose gives a similar loss
      final dw = analyzeTraveller(
        const TravellerSpec(gunFlow: 30 / 3600, gunPressureM: 45, wettedDiameterM: 90, hoseLengthM: 350, hoseInnerMm: 90, method: FrictionMethod.darcyWeisbach, speedMPerMin: 0.5),
      );
      expect(dw.hoseFrictionM, closeTo(hf, hf * 0.25));
    });

    test('lane, depth and times at a given speed', () {
      expect(r.laneSpacingM, closeTo(0.65 * 90, 1e-9));
      expect(r.lanes, 1);
      expect(r.laneLengthM, 350);
      expect(r.grossDepthMm, closeTo(30 / 3600 / (58.5 * 0.5 / 60) * 1000, 1e-9));
      expect(r.travelHours, closeTo(350 / 0.5 / 60, 1e-9));
      expect(r.laneHours, closeTo(r.travelHours + 0.5, 1e-12));
      expect(r.cycleDays, closeTo(r.cycleHours / 22, 1e-12));
      final back = TravellerResult.fromJson(r.toJson());
      expect(back.inletHeadM, closeTo(r.inletHeadM, 1e-12));
      expect(back.lanes, 1);
    });

    test('messages: no speed, speed out of range, rate above the soil intake, spacing wider than the table', () {
      expect(analyzeTraveller(const TravellerSpec(gunFlow: 0.008, gunPressureM: 45, wettedDiameterM: 90), id: 't').warnings, contains('traveller_no_speed:t'));
      expect(analyzeTraveller(const TravellerSpec(gunFlow: 0.008, gunPressureM: 45, wettedDiameterM: 90, speedMPerMin: 3, maxSpeedMPerMin: 2)).warnings, contains('traveller_speed_range'));
      expect(analyzeTraveller(const TravellerSpec(gunFlow: 0.008, gunPressureM: 45, wettedDiameterM: 90, speedMPerMin: 0.5, soilIntakeMmH: 5)).warnings, contains('traveller_app_rate'));
      expect(analyzeTraveller(const TravellerSpec(gunFlow: 0.008, gunPressureM: 45, wettedDiameterM: 90, speedMPerMin: 0.5, laneSpacingM: 80)).warnings, contains('traveller_lane_wide'));
      expect(analyzeTraveller(const TravellerSpec(gunFlow: 0, gunPressureM: 45, wettedDiameterM: 90, speedMPerMin: 0.5)).warnings, contains('traveller_no_flow'));
    });

    test('flow and wetted diameter of a catalogue gun nozzle', () {
      final n = NozzleSpec(
        id: 'g',
        name: 'gun',
        curve: EmitterCurve.fromNominal(flow: 25 * m3sPerM3h, head: 45, radius: 40, radiusB: 0.5),
      );
      final (q, d) = gunPerformance(n, 45);
      expect(q, closeTo(25 * m3sPerM3h, 1e-15));
      expect(d, closeTo(80, 1e-9));
    });
  });
}
