import 'package:flutter/material.dart';

/// Échelle de comestibilité (cahier des charges §7).
enum Edibility {
  good('Bon comestible', Color(0xFF2E7D32), Icons.check_circle),
  conditional('Comestible sous conditions', Color(0xFFF9A825), Icons.info),
  inedible('Non comestible', Color(0xFF757575), Icons.remove_circle),
  toxic('Toxique', Color(0xFFEF6C00), Icons.warning),
  deadly('Mortel', Color(0xFFC62828), Icons.dangerous);

  const Edibility(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// Espèces pour lesquelles l'identification doit déclencher une alerte (RM-6).
  bool get isDangerous => this == toxic || this == deadly;
}

/// Une espèce avec laquelle on peut la confondre.
class Confusion {
  const Confusion({required this.name, required this.note, this.speciesId});

  final String name;
  final String note;

  /// Lien vers la fiche si l'espèce est dans le catalogue.
  final String? speciesId;
}

class Species {
  const Species({
    required this.id,
    required this.commonName,
    required this.edibility,
    this.scientificName,
    this.family,
    this.description = '',
    this.habitat,
    this.seasonStart,
    this.seasonEnd,
    this.confusions = const [],
    this.edibilityNote,
    this.photoPath,
    this.isCustom = false,
  });

  final String id;
  final String commonName;
  final String? scientificName;
  final String? family;
  final Edibility edibility;

  /// Précision sur la comestibilité (cuisson obligatoire, etc.).
  final String? edibilityNote;
  final String description;
  final String? habitat;

  /// Mois (1–12) de début et de fin de saison.
  final int? seasonStart;
  final int? seasonEnd;
  final List<Confusion> confusions;
  final String? photoPath;

  /// Fiche ajoutée par l'utilisateur : statut de sécurité non vérifié.
  final bool isCustom;

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String? get seasonLabel {
    final start = seasonStart;
    final end = seasonEnd;
    if (start == null || end == null) return null;
    return '${_months[start - 1]} → ${_months[end - 1]}';
  }
}
