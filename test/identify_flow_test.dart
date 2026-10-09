import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/identify/identify_flow.dart';
import 'package:mycelium/features/map/location.dart';

/// Moteur factice : renvoie des scores fixes, ou échoue.
class StubEngine implements Identifier {
  StubEngine({this.fail = false});

  final bool fail;
  String? lastPath;

  @override
  bool get isDemo => false;

  @override
  Future<RawIdentification> identify(IdentificationInput input) async {
    lastPath = input.imagePath;
    if (fail) throw StateError('modèle indisponible');
    return const RawIdentification(
      modelVersion: 'stub-1',
      unknownScore: 0.05,
      candidates: [
        Candidate(speciesId: 'girolle', score: 0.80),
        Candidate(speciesId: 'fausse-girolle', score: 0.10),
        Candidate(speciesId: 'amanite-phalloide', score: 0.004),
      ],
    );
  }
}

Position here() => Position(
      latitude: 48.2,
      longitude: 7.3,
      timestamp: DateTime(2026, 10, 9),
      accuracy: 6,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

ProviderContainer container({String? photo = '/tmp/photo.jpg', bool withGps = true}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final c = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
    photoPickerProvider.overrideWithValue((_) async => photo),
    locationProvider.overrideWith(
      (ref) => Stream.value(withGps
          ? LocationState(LocationStatus.ok, here())
          : const LocationState(LocationStatus.unavailable)),
    ),
  ]);
  c.listen(locationProvider, (_, _) {});
  return c;
}

void main() {
  test('appareil photo : la position de la prise de vue est conservée', () async {
    final c = container();
    addTearDown(c.dispose);
    await c.read(locationProvider.future);

    final outcome = await c
        .read(identifyFlowProvider)
        .captureAndIdentify(ImageSource.camera, StubEngine());

    expect(outcome.imagePath, '/tmp/photo.jpg');
    expect(outcome.latitude, 48.2);
    expect(outcome.longitude, 7.3);
    expect(outcome.hasLocation, isTrue);
    expect(outcome.modelVersion, 'stub-1');
    expect(outcome.isDemo, isFalse);
  });

  test('galerie : aucun emplacement inventé (la photo peut venir d\'ailleurs)', () async {
    final c = container();
    addTearDown(c.dispose);
    await c.read(locationProvider.future);

    final outcome = await c
        .read(identifyFlowProvider)
        .captureAndIdentify(ImageSource.gallery, StubEngine());

    expect(outcome.hasLocation, isFalse);
    expect(outcome.latitude, isNull);
  });

  test('appareil photo sans GPS : pas de position, l\'identification fonctionne', () async {
    final c = container(withGps: false);
    addTearDown(c.dispose);
    await c.read(locationProvider.future);

    final outcome = await c
        .read(identifyFlowProvider)
        .captureAndIdentify(ImageSource.camera, StubEngine());

    expect(outcome.hasLocation, isFalse);
    expect(outcome.candidates.first.speciesId, 'girolle');
  });

  test('règles de sécurité appliquées : candidat quasi nul écarté (RM-6 sans bruit)', () async {
    final c = container();
    addTearDown(c.dispose);
    final outcome = await c
        .read(identifyFlowProvider)
        .captureAndIdentify(ImageSource.gallery, StubEngine());

    expect(outcome.candidates.map((e) => e.speciesId), ['girolle', 'fausse-girolle']);
    expect(outcome.dangerousSpeciesIds, isEmpty);
    expect(outcome.unknownScore, 0.05);
  });

  test('fenêtre de choix fermée => annulation, aucune analyse', () async {
    final c = container(photo: null);
    addTearDown(c.dispose);
    final engine = StubEngine();

    await expectLater(
      c.read(identifyFlowProvider).captureAndIdentify(ImageSource.gallery, engine),
      throwsA(isA<IdentifyCancelled>()),
    );
    expect(engine.lastPath, isNull);
  });

  test('échec du choix de photo et échec du modèle ont des erreurs distinctes', () async {
    final failingPicker = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
      photoPickerProvider.overrideWithValue((_) async => throw StateError('refusé')),
    ]);
    addTearDown(failingPicker.dispose);
    await expectLater(
      failingPicker
          .read(identifyFlowProvider)
          .captureAndIdentify(ImageSource.camera, StubEngine()),
      throwsA(isA<IdentifyPhotoError>()),
    );

    final c = container();
    addTearDown(c.dispose);
    await expectLater(
      c
          .read(identifyFlowProvider)
          .captureAndIdentify(ImageSource.gallery, StubEngine(fail: true)),
      throwsA(isA<IdentifyAnalysisError>()),
    );
  });

  test('onPhotoChosen est appelé avant l\'analyse', () async {
    final c = container();
    addTearDown(c.dispose);
    final order = <String>[];
    final engine = _OrderEngine(order);
    await c.read(identifyFlowProvider).captureAndIdentify(
          ImageSource.gallery,
          engine,
          onPhotoChosen: () => order.add('photo choisie'),
        );
    expect(order, ['photo choisie', 'analyse']);
  });

  test('exemple de démonstration : marqué fictif, sans photo ni position', () async {
    final c = container();
    addTearDown(c.dispose);
    final outcome = await c.read(identifyFlowProvider).demo(2);
    expect(outcome.isDemo, isTrue);
    expect(outcome.imagePath, isNull);
    expect(outcome.hasLocation, isFalse);
    expect(outcome.dangerousSpeciesIds, contains('amanite-phalloide'));
  });
}

class _OrderEngine implements Identifier {
  _OrderEngine(this.order);

  final List<String> order;

  @override
  bool get isDemo => false;

  @override
  Future<RawIdentification> identify(IdentificationInput input) async {
    order.add('analyse');
    return const RawIdentification(candidates: [], modelVersion: 'x');
  }
}
