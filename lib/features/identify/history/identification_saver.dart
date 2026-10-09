import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/photo_store.dart';
import '../identifier.dart';
import 'place_sheet.dart';

/// Dossier (sous les Documents de l'application) des photos des identifications.
const identificationPhotoFolder = 'identification_photos';

/// Ce qui a été enregistré.
class SavedIdentification {
  const SavedIdentification({
    required this.id,
    required this.photoPath,
    required this.speciesId,
    this.spot,
  });

  final String id;

  /// Chemin RELATIF de la photo copiée : à retrouver avec `resolveStoredPhoto`.
  final String photoPath;

  /// Espèce retenue par l'utilisateur (null = « Je ne sais pas »).
  final String? speciesId;

  /// Coin auquel l'identification est rattachée (null = aucun).
  final Spot? spot;
}

/// Enregistre une identification (ID-5).
///
/// - la photo est copiée dans le dossier de l'application, chemin relatif en base ;
/// - [speciesId] est l'espèce retenue par l'utilisateur (null = « Je ne sais pas ») :
///   le résultat du modèle est conservé à côté, sans être modifié (RM-3) ;
/// - la position est celle de la prise de vue, présente seulement pour une photo
///   prise avec l'appareil : on ne l'invente jamais ;
/// - [place] range l'identification dans un coin (créé au besoin), et l'espèce y est
///   alors marquée comme observée (SPOT-4).
///
/// Tout est écrit en une seule transaction ; si elle échoue, la photo copiée est
/// supprimée avant de relancer l'erreur, pour ne laisser aucun fichier orphelin.
Future<SavedIdentification> saveIdentification(
  AppDatabase db, {
  required IdentificationOutcome outcome,
  required String? speciesId,
  required PlaceChoice place,
  DateTime? now,
}) async {
  final source = outcome.imagePath;
  if (source == null) {
    throw ArgumentError('Une identification sans photo ne s\'enregistre pas.');
  }
  final at = now ?? DateTime.now();
  final id = const Uuid().v4();
  final stored = await savePhotoRelative(source, folder: identificationPhotoFolder, id: id);
  try {
    final spot = await db.transaction(() async {
      final target = await _resolveSpot(db, place, at);
      await db.addIdentification(
        IdentificationsCompanion.insert(
          id: id,
          photoPath: stored,
          modelVersion: outcome.modelVersion ?? 'inconnue',
          top5Json: jsonEncode([
            for (final c in outcome.candidates)
              {'id': c.speciesId, 'score': double.parse(c.score.toStringAsFixed(4))},
          ]),
          unknownScore: Value(outcome.unknownScore),
          chosenSpeciesId: Value(speciesId),
          createdAt: at,
          latitude: Value(outcome.latitude),
          longitude: Value(outcome.longitude),
          spotId: Value(target?.id),
        ),
      );
      if (speciesId != null && target != null) {
        await db.markSpeciesSeen(target.id, speciesId, at);
      }
      return target;
    });
    return SavedIdentification(id: id, photoPath: stored, speciesId: speciesId, spot: spot);
  } catch (_) {
    await deleteStoredPhoto(stored);
    rethrow;
  }
}

/// Le coin désigné par [place] : créé s'il est nouveau, relu s'il existe (il a pu
/// être supprimé entre-temps, auquel cas l'identification reste sans coin).
Future<Spot?> _resolveSpot(AppDatabase db, PlaceChoice place, DateTime at) async {
  switch (place) {
    case NoPlace():
      return null;
    case ExistingSpot(:final spot):
      return db.spotById(spot.id);
    case NewSpot(:final name, :final latitude, :final longitude):
      final id = const Uuid().v4();
      await db.upsertSpot(
        SpotsCompanion.insert(
          id: id,
          name: name,
          latitude: latitude,
          longitude: longitude,
          createdAt: at,
          updatedAt: at,
        ),
      );
      return db.spotById(id);
  }
}
