import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

void main() {
  final t = I18n('pt');

  group('temperature derating', () {
    test('PVC follows the NBR/ISO table, PE the ISO 4427 one, metals none', () {
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 20), 1.0);
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 25), 1.0);
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 27.5), closeTo(0.95, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 30), closeTo(0.9, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 35), closeTo(0.8, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 45), closeTo(0.6, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pvc, 60), closeTo(0.6, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pehd, 20), 1.0);
      expect(pipeTemperatureDerating(PipeMaterial.pehd, 30), closeTo(0.87, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.peld, 35), closeTo(0.805, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.pehd, 40), closeTo(0.74, 1e-12));
      expect(pipeTemperatureDerating(PipeMaterial.steel, 40), 1.0);
      expect(pipeTemperatureDerating(PipeMaterial.pvc, double.nan), 1.0);
      final pvc = Catalog.defaultCatalog().pipe('pvc100')!;
      expect(pvc.ratingAt(20), pvc.pressureRatingM);
      expect(pvc.ratingAt(35), closeTo(0.8 * pvc.pressureRatingM, 1e-9));
    });
  });

  group('pressure class as a sizing constraint', () {
    // A fixed-pressure supply well above the PN 80 of the catalogue PVC: the
    // mainline must come out in a pipe that withstands it, not in the
    // cheaper PVC with a warning afterwards.
    Project build(double supplyHead, {double waterTemp = 20}) {
      final p = Project();
      p.params.waterTempC = waterTemp;
      const valvePos = Pt(300, 0);
      p.entities.add(PipeEntity(id: 'main', points: [Pt.zero, const Pt(150, 0), valvePos], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: supplyHead, maxHeadM: supplyHead));
      p.entities.add(ControlValveEntity(id: 'v', position: valvePos, zoneName: 'Z', valveSpecId: 'ev50'));
      p.entities.add(PipeEntity(id: 'sub', points: [valvePos, const Pt(300, 22)], scope: HydraulicScope.zone));
      for (var i = 0; i < 6; i++) {
        p.entities.add(SpraylineEntity(id: 's$i', points: [Pt(300, 2 + i * 4.0), Pt(340, 2 + i * 4.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      }
      return p;
    }

    for (final method in SizingMethod.values) {
      test('${method.name}: a 95 m supply never gets PN 80 PVC', () {
        final p = build(95);
        p.params.sizingMethod = method;
        final r = Designer(p, label: (k) => t(k)).designAll();
        final mains = p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline).toList();
        expect(mains, isNotEmpty);
        for (final m in mains) {
          final spec = p.catalog.pipe(m.pipeSpecId)!;
          expect(spec.ratingAt(20), greaterThanOrEqualTo(95 - 1e-6), reason: spec.name);
        }
        final warnings = [for (final f in r.systemFlows) ...f.warnings];
        expect(warnings.where((w) => w.startsWith('pressure_rating_exceeded')), isEmpty, reason: '$warnings');
      });
    }

    test('warm water derates the class: PVC passes at 20 °C but not at 35 °C', () {
      String material(double temp) {
        final p = build(70, waterTemp: temp);
        final r = Designer(p, label: (k) => t(k)).designAll();
        final warnings = [for (final f in r.systemFlows) ...f.warnings];
        expect(warnings.where((w) => w.startsWith('pressure_rating_exceeded')), isEmpty, reason: '$temp °C: $warnings');
        final mains = p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline);
        for (final m in mains) {
          final spec = p.catalog.pipe(m.pipeSpecId)!;
          expect(spec.ratingAt(temp), greaterThanOrEqualTo(70 - 1e-6), reason: '$temp °C ${spec.name}');
          // the reported class is the derated one
          for (final f in r.systemFlows) {
            for (final s in f.pipes.where((s) => s.entityId == m.id)) {
              expect(s.pressureRating, closeTo(spec.ratingAt(temp), 1e-9));
            }
          }
        }
        return p.catalog.pipe(mains.first.pipeSpecId)!.material.name;
      }

      expect(material(20), PipeMaterial.pvc.name);
      expect(material(35), isNot(PipeMaterial.pvc.name));
    });

    test('nothing in the catalogue withstands the pressure: sized as before and warned', () {
      final p = build(260);
      final r = Designer(p, label: (k) => t(k)).designAll();
      final warnings = [for (final f in r.systemFlows) ...f.warnings];
      expect(warnings.where((w) => w.startsWith('pressure_rating_exceeded')), isNotEmpty);
    });
  });
}
