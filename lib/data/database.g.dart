// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SpotsTable extends Spots with TableInfo<$SpotsTable, Spot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forestTypeMeta = const VerificationMeta(
    'forestType',
  );
  @override
  late final GeneratedColumn<String> forestType = GeneratedColumn<String>(
    'forest_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    forestType,
    notes,
    isFavorite,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Spot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('forest_type')) {
      context.handle(
        _forestTypeMeta,
        forestType.isAcceptableOrUnknown(data['forest_type']!, _forestTypeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Spot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Spot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      forestType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forest_type'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SpotsTable createAlias(String alias) {
    return $SpotsTable(attachedDatabase, alias);
  }
}

class Spot extends DataClass implements Insertable<Spot> {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? forestType;
  final String? notes;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Spot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.forestType,
    this.notes,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || forestType != null) {
      map['forest_type'] = Variable<String>(forestType);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SpotsCompanion toCompanion(bool nullToAbsent) {
    return SpotsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      forestType: forestType == null && nullToAbsent
          ? const Value.absent()
          : Value(forestType),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Spot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Spot(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      forestType: serializer.fromJson<String?>(json['forestType']),
      notes: serializer.fromJson<String?>(json['notes']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'forestType': serializer.toJson<String?>(forestType),
      'notes': serializer.toJson<String?>(notes),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    Value<String?> forestType = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Spot(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    forestType: forestType.present ? forestType.value : this.forestType,
    notes: notes.present ? notes.value : this.notes,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Spot copyWithCompanion(SpotsCompanion data) {
    return Spot(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      forestType: data.forestType.present
          ? data.forestType.value
          : this.forestType,
      notes: data.notes.present ? data.notes.value : this.notes,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Spot(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('forestType: $forestType, ')
          ..write('notes: $notes, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    forestType,
    notes,
    isFavorite,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Spot &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.forestType == this.forestType &&
          other.notes == this.notes &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SpotsCompanion extends UpdateCompanion<Spot> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> forestType;
  final Value<String?> notes;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SpotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.forestType = const Value.absent(),
    this.notes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpotsCompanion.insert({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    this.forestType = const Value.absent(),
    this.notes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Spot> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? forestType,
    Expression<String>? notes,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (forestType != null) 'forest_type': forestType,
      if (notes != null) 'notes': notes,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpotsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String?>? forestType,
    Value<String?>? notes,
    Value<bool>? isFavorite,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SpotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      forestType: forestType ?? this.forestType,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (forestType.present) {
      map['forest_type'] = Variable<String>(forestType.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('forestType: $forestType, ')
          ..write('notes: $notes, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutingsTable extends Outings with TableInfo<$OutingsTable, Outing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spotIdMeta = const VerificationMeta('spotId');
  @override
  late final GeneratedColumn<String> spotId = GeneratedColumn<String>(
    'spot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spotId,
    startedAt,
    durationMin,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Outing> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('spot_id')) {
      context.handle(
        _spotIdMeta,
        spotId.isAcceptableOrUnknown(data['spot_id']!, _spotIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Outing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Outing(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spot_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $OutingsTable createAlias(String alias) {
    return $OutingsTable(attachedDatabase, alias);
  }
}

class Outing extends DataClass implements Insertable<Outing> {
  final String id;
  final String? spotId;
  final DateTime startedAt;
  final int? durationMin;
  final String? notes;
  const Outing({
    required this.id,
    this.spotId,
    required this.startedAt,
    this.durationMin,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || spotId != null) {
      map['spot_id'] = Variable<String>(spotId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  OutingsCompanion toCompanion(bool nullToAbsent) {
    return OutingsCompanion(
      id: Value(id),
      spotId: spotId == null && nullToAbsent
          ? const Value.absent()
          : Value(spotId),
      startedAt: Value(startedAt),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Outing.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Outing(
      id: serializer.fromJson<String>(json['id']),
      spotId: serializer.fromJson<String?>(json['spotId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spotId': serializer.toJson<String?>(spotId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMin': serializer.toJson<int?>(durationMin),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Outing copyWith({
    String? id,
    Value<String?> spotId = const Value.absent(),
    DateTime? startedAt,
    Value<int?> durationMin = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Outing(
    id: id ?? this.id,
    spotId: spotId.present ? spotId.value : this.spotId,
    startedAt: startedAt ?? this.startedAt,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    notes: notes.present ? notes.value : this.notes,
  );
  Outing copyWithCompanion(OutingsCompanion data) {
    return Outing(
      id: data.id.present ? data.id.value : this.id,
      spotId: data.spotId.present ? data.spotId.value : this.spotId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Outing(')
          ..write('id: $id, ')
          ..write('spotId: $spotId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMin: $durationMin, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, spotId, startedAt, durationMin, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Outing &&
          other.id == this.id &&
          other.spotId == this.spotId &&
          other.startedAt == this.startedAt &&
          other.durationMin == this.durationMin &&
          other.notes == this.notes);
}

class OutingsCompanion extends UpdateCompanion<Outing> {
  final Value<String> id;
  final Value<String?> spotId;
  final Value<DateTime> startedAt;
  final Value<int?> durationMin;
  final Value<String?> notes;
  final Value<int> rowid;
  const OutingsCompanion({
    this.id = const Value.absent(),
    this.spotId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutingsCompanion.insert({
    required String id,
    this.spotId = const Value.absent(),
    required DateTime startedAt,
    this.durationMin = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Outing> custom({
    Expression<String>? id,
    Expression<String>? spotId,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMin,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spotId != null) 'spot_id': spotId,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMin != null) 'duration_min': durationMin,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutingsCompanion copyWith({
    Value<String>? id,
    Value<String?>? spotId,
    Value<DateTime>? startedAt,
    Value<int?>? durationMin,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return OutingsCompanion(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      startedAt: startedAt ?? this.startedAt,
      durationMin: durationMin ?? this.durationMin,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spotId.present) {
      map['spot_id'] = Variable<String>(spotId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutingsCompanion(')
          ..write('id: $id, ')
          ..write('spotId: $spotId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMin: $durationMin, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HarvestsTable extends Harvests with TableInfo<$HarvestsTable, Harvest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HarvestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outingIdMeta = const VerificationMeta(
    'outingId',
  );
  @override
  late final GeneratedColumn<String> outingId = GeneratedColumn<String>(
    'outing_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speciesIdMeta = const VerificationMeta(
    'speciesId',
  );
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
    'species_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityCountMeta = const VerificationMeta(
    'quantityCount',
  );
  @override
  late final GeneratedColumn<int> quantityCount = GeneratedColumn<int>(
    'quantity_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    outingId,
    speciesId,
    quantityCount,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'harvests';
  @override
  VerificationContext validateIntegrity(
    Insertable<Harvest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('outing_id')) {
      context.handle(
        _outingIdMeta,
        outingId.isAcceptableOrUnknown(data['outing_id']!, _outingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_outingIdMeta);
    }
    if (data.containsKey('species_id')) {
      context.handle(
        _speciesIdMeta,
        speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesIdMeta);
    }
    if (data.containsKey('quantity_count')) {
      context.handle(
        _quantityCountMeta,
        quantityCount.isAcceptableOrUnknown(
          data['quantity_count']!,
          _quantityCountMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Harvest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Harvest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      outingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outing_id'],
      )!,
      speciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species_id'],
      )!,
      quantityCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_count'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $HarvestsTable createAlias(String alias) {
    return $HarvestsTable(attachedDatabase, alias);
  }
}

class Harvest extends DataClass implements Insertable<Harvest> {
  final String id;
  final String outingId;
  final String speciesId;
  final int? quantityCount;
  final String? notes;
  const Harvest({
    required this.id,
    required this.outingId,
    required this.speciesId,
    this.quantityCount,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['outing_id'] = Variable<String>(outingId);
    map['species_id'] = Variable<String>(speciesId);
    if (!nullToAbsent || quantityCount != null) {
      map['quantity_count'] = Variable<int>(quantityCount);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  HarvestsCompanion toCompanion(bool nullToAbsent) {
    return HarvestsCompanion(
      id: Value(id),
      outingId: Value(outingId),
      speciesId: Value(speciesId),
      quantityCount: quantityCount == null && nullToAbsent
          ? const Value.absent()
          : Value(quantityCount),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Harvest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Harvest(
      id: serializer.fromJson<String>(json['id']),
      outingId: serializer.fromJson<String>(json['outingId']),
      speciesId: serializer.fromJson<String>(json['speciesId']),
      quantityCount: serializer.fromJson<int?>(json['quantityCount']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'outingId': serializer.toJson<String>(outingId),
      'speciesId': serializer.toJson<String>(speciesId),
      'quantityCount': serializer.toJson<int?>(quantityCount),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Harvest copyWith({
    String? id,
    String? outingId,
    String? speciesId,
    Value<int?> quantityCount = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Harvest(
    id: id ?? this.id,
    outingId: outingId ?? this.outingId,
    speciesId: speciesId ?? this.speciesId,
    quantityCount: quantityCount.present
        ? quantityCount.value
        : this.quantityCount,
    notes: notes.present ? notes.value : this.notes,
  );
  Harvest copyWithCompanion(HarvestsCompanion data) {
    return Harvest(
      id: data.id.present ? data.id.value : this.id,
      outingId: data.outingId.present ? data.outingId.value : this.outingId,
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      quantityCount: data.quantityCount.present
          ? data.quantityCount.value
          : this.quantityCount,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Harvest(')
          ..write('id: $id, ')
          ..write('outingId: $outingId, ')
          ..write('speciesId: $speciesId, ')
          ..write('quantityCount: $quantityCount, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, outingId, speciesId, quantityCount, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Harvest &&
          other.id == this.id &&
          other.outingId == this.outingId &&
          other.speciesId == this.speciesId &&
          other.quantityCount == this.quantityCount &&
          other.notes == this.notes);
}

class HarvestsCompanion extends UpdateCompanion<Harvest> {
  final Value<String> id;
  final Value<String> outingId;
  final Value<String> speciesId;
  final Value<int?> quantityCount;
  final Value<String?> notes;
  final Value<int> rowid;
  const HarvestsCompanion({
    this.id = const Value.absent(),
    this.outingId = const Value.absent(),
    this.speciesId = const Value.absent(),
    this.quantityCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HarvestsCompanion.insert({
    required String id,
    required String outingId,
    required String speciesId,
    this.quantityCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       outingId = Value(outingId),
       speciesId = Value(speciesId);
  static Insertable<Harvest> custom({
    Expression<String>? id,
    Expression<String>? outingId,
    Expression<String>? speciesId,
    Expression<int>? quantityCount,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (outingId != null) 'outing_id': outingId,
      if (speciesId != null) 'species_id': speciesId,
      if (quantityCount != null) 'quantity_count': quantityCount,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HarvestsCompanion copyWith({
    Value<String>? id,
    Value<String>? outingId,
    Value<String>? speciesId,
    Value<int?>? quantityCount,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return HarvestsCompanion(
      id: id ?? this.id,
      outingId: outingId ?? this.outingId,
      speciesId: speciesId ?? this.speciesId,
      quantityCount: quantityCount ?? this.quantityCount,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (outingId.present) {
      map['outing_id'] = Variable<String>(outingId.value);
    }
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (quantityCount.present) {
      map['quantity_count'] = Variable<int>(quantityCount.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HarvestsCompanion(')
          ..write('id: $id, ')
          ..write('outingId: $outingId, ')
          ..write('speciesId: $speciesId, ')
          ..write('quantityCount: $quantityCount, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomSpeciesTable extends CustomSpecies
    with TableInfo<$CustomSpeciesTable, CustomSpeciesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomSpeciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commonNameMeta = const VerificationMeta(
    'commonName',
  );
  @override
  late final GeneratedColumn<String> commonName = GeneratedColumn<String>(
    'common_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    commonName,
    description,
    photoPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_species';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomSpeciesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('common_name')) {
      context.handle(
        _commonNameMeta,
        commonName.isAcceptableOrUnknown(data['common_name']!, _commonNameMeta),
      );
    } else if (isInserting) {
      context.missing(_commonNameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomSpeciesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomSpeciesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commonName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}common_name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomSpeciesTable createAlias(String alias) {
    return $CustomSpeciesTable(attachedDatabase, alias);
  }
}

class CustomSpeciesRow extends DataClass
    implements Insertable<CustomSpeciesRow> {
  final String id;
  final String commonName;
  final String description;
  final String? photoPath;
  final DateTime createdAt;
  const CustomSpeciesRow({
    required this.id,
    required this.commonName,
    required this.description,
    this.photoPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['common_name'] = Variable<String>(commonName);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomSpeciesCompanion toCompanion(bool nullToAbsent) {
    return CustomSpeciesCompanion(
      id: Value(id),
      commonName: Value(commonName),
      description: Value(description),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      createdAt: Value(createdAt),
    );
  }

  factory CustomSpeciesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomSpeciesRow(
      id: serializer.fromJson<String>(json['id']),
      commonName: serializer.fromJson<String>(json['commonName']),
      description: serializer.fromJson<String>(json['description']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'commonName': serializer.toJson<String>(commonName),
      'description': serializer.toJson<String>(description),
      'photoPath': serializer.toJson<String?>(photoPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomSpeciesRow copyWith({
    String? id,
    String? commonName,
    String? description,
    Value<String?> photoPath = const Value.absent(),
    DateTime? createdAt,
  }) => CustomSpeciesRow(
    id: id ?? this.id,
    commonName: commonName ?? this.commonName,
    description: description ?? this.description,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    createdAt: createdAt ?? this.createdAt,
  );
  CustomSpeciesRow copyWithCompanion(CustomSpeciesCompanion data) {
    return CustomSpeciesRow(
      id: data.id.present ? data.id.value : this.id,
      commonName: data.commonName.present
          ? data.commonName.value
          : this.commonName,
      description: data.description.present
          ? data.description.value
          : this.description,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomSpeciesRow(')
          ..write('id: $id, ')
          ..write('commonName: $commonName, ')
          ..write('description: $description, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, commonName, description, photoPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomSpeciesRow &&
          other.id == this.id &&
          other.commonName == this.commonName &&
          other.description == this.description &&
          other.photoPath == this.photoPath &&
          other.createdAt == this.createdAt);
}

class CustomSpeciesCompanion extends UpdateCompanion<CustomSpeciesRow> {
  final Value<String> id;
  final Value<String> commonName;
  final Value<String> description;
  final Value<String?> photoPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CustomSpeciesCompanion({
    this.id = const Value.absent(),
    this.commonName = const Value.absent(),
    this.description = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomSpeciesCompanion.insert({
    required String id,
    required String commonName,
    this.description = const Value.absent(),
    this.photoPath = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       commonName = Value(commonName),
       createdAt = Value(createdAt);
  static Insertable<CustomSpeciesRow> custom({
    Expression<String>? id,
    Expression<String>? commonName,
    Expression<String>? description,
    Expression<String>? photoPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commonName != null) 'common_name': commonName,
      if (description != null) 'description': description,
      if (photoPath != null) 'photo_path': photoPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomSpeciesCompanion copyWith({
    Value<String>? id,
    Value<String>? commonName,
    Value<String>? description,
    Value<String?>? photoPath,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CustomSpeciesCompanion(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commonName.present) {
      map['common_name'] = Variable<String>(commonName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomSpeciesCompanion(')
          ..write('id: $id, ')
          ..write('commonName: $commonName, ')
          ..write('description: $description, ')
          ..write('photoPath: $photoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpotsTable spots = $SpotsTable(this);
  late final $OutingsTable outings = $OutingsTable(this);
  late final $HarvestsTable harvests = $HarvestsTable(this);
  late final $CustomSpeciesTable customSpecies = $CustomSpeciesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spots,
    outings,
    harvests,
    customSpecies,
  ];
}

typedef $$SpotsTableCreateCompanionBuilder = SpotsCompanion Function({
  required String id,
  required String name,
  required double latitude,
  required double longitude,
  Value<String?> forestType,
  Value<String?> notes,
  Value<bool> isFavorite,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SpotsTableUpdateCompanionBuilder = SpotsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double> latitude,
  Value<double> longitude,
  Value<String?> forestType,
  Value<String?> notes,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SpotsTableFilterComposer extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forestType => $composableBuilder(
    column: $table.forestType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forestType => $composableBuilder(
    column: $table.forestType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get forestType => $composableBuilder(
    column: $table.forestType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SpotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpotsTable,
          Spot,
          $$SpotsTableFilterComposer,
          $$SpotsTableOrderingComposer,
          $$SpotsTableAnnotationComposer,
          $$SpotsTableCreateCompanionBuilder,
          $$SpotsTableUpdateCompanionBuilder,
          (Spot, BaseReferences<_$AppDatabase, $SpotsTable, Spot>),
          Spot,
          PrefetchHooks Function()
        > {
  $$SpotsTableTableManager(_$AppDatabase db, $SpotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String?> forestType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpotsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                forestType: forestType,
                notes: notes,
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double latitude,
                required double longitude,
                Value<String?> forestType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SpotsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                forestType: forestType,
                notes: notes,
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpotsTable, Spot>(table),
                  BaseReferences<_$AppDatabase, $SpotsTable, Spot>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpotsTable,
      Spot,
      $$SpotsTableFilterComposer,
      $$SpotsTableOrderingComposer,
      $$SpotsTableAnnotationComposer,
      $$SpotsTableCreateCompanionBuilder,
      $$SpotsTableUpdateCompanionBuilder,
      (Spot, BaseReferences<_$AppDatabase, $SpotsTable, Spot>),
      Spot,
      PrefetchHooks Function()
    >;
typedef $$OutingsTableCreateCompanionBuilder = OutingsCompanion Function({
  required String id,
  Value<String?> spotId,
  required DateTime startedAt,
  Value<int?> durationMin,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$OutingsTableUpdateCompanionBuilder = OutingsCompanion Function({
  Value<String> id,
  Value<String?> spotId,
  Value<DateTime> startedAt,
  Value<int?> durationMin,
  Value<String?> notes,
  Value<int> rowid,
});

class $$OutingsTableFilterComposer
    extends Composer<_$AppDatabase, $OutingsTable> {
  $$OutingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutingsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutingsTable> {
  $$OutingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutingsTable> {
  $$OutingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spotId =>
      $composableBuilder(column: $table.spotId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$OutingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutingsTable,
          Outing,
          $$OutingsTableFilterComposer,
          $$OutingsTableOrderingComposer,
          $$OutingsTableAnnotationComposer,
          $$OutingsTableCreateCompanionBuilder,
          $$OutingsTableUpdateCompanionBuilder,
          (Outing, BaseReferences<_$AppDatabase, $OutingsTable, Outing>),
          Outing,
          PrefetchHooks Function()
        > {
  $$OutingsTableTableManager(_$AppDatabase db, $OutingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> spotId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutingsCompanion(
                id: id,
                spotId: spotId,
                startedAt: startedAt,
                durationMin: durationMin,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> spotId = const Value.absent(),
                required DateTime startedAt,
                Value<int?> durationMin = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutingsCompanion.insert(
                id: id,
                spotId: spotId,
                startedAt: startedAt,
                durationMin: durationMin,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutingsTable, Outing>(table),
                  BaseReferences<_$AppDatabase, $OutingsTable, Outing>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutingsTable,
      Outing,
      $$OutingsTableFilterComposer,
      $$OutingsTableOrderingComposer,
      $$OutingsTableAnnotationComposer,
      $$OutingsTableCreateCompanionBuilder,
      $$OutingsTableUpdateCompanionBuilder,
      (Outing, BaseReferences<_$AppDatabase, $OutingsTable, Outing>),
      Outing,
      PrefetchHooks Function()
    >;
typedef $$HarvestsTableCreateCompanionBuilder = HarvestsCompanion Function({
  required String id,
  required String outingId,
  required String speciesId,
  Value<int?> quantityCount,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$HarvestsTableUpdateCompanionBuilder = HarvestsCompanion Function({
  Value<String> id,
  Value<String> outingId,
  Value<String> speciesId,
  Value<int?> quantityCount,
  Value<String?> notes,
  Value<int> rowid,
});

class $$HarvestsTableFilterComposer
    extends Composer<_$AppDatabase, $HarvestsTable> {
  $$HarvestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outingId => $composableBuilder(
    column: $table.outingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantityCount => $composableBuilder(
    column: $table.quantityCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HarvestsTableOrderingComposer
    extends Composer<_$AppDatabase, $HarvestsTable> {
  $$HarvestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outingId => $composableBuilder(
    column: $table.outingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantityCount => $composableBuilder(
    column: $table.quantityCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HarvestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HarvestsTable> {
  $$HarvestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get outingId =>
      $composableBuilder(column: $table.outingId, builder: (column) => column);

  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<int> get quantityCount => $composableBuilder(
    column: $table.quantityCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$HarvestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HarvestsTable,
          Harvest,
          $$HarvestsTableFilterComposer,
          $$HarvestsTableOrderingComposer,
          $$HarvestsTableAnnotationComposer,
          $$HarvestsTableCreateCompanionBuilder,
          $$HarvestsTableUpdateCompanionBuilder,
          (Harvest, BaseReferences<_$AppDatabase, $HarvestsTable, Harvest>),
          Harvest,
          PrefetchHooks Function()
        > {
  $$HarvestsTableTableManager(_$AppDatabase db, $HarvestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HarvestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HarvestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HarvestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> outingId = const Value.absent(),
                Value<String> speciesId = const Value.absent(),
                Value<int?> quantityCount = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HarvestsCompanion(
                id: id,
                outingId: outingId,
                speciesId: speciesId,
                quantityCount: quantityCount,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String outingId,
                required String speciesId,
                Value<int?> quantityCount = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HarvestsCompanion.insert(
                id: id,
                outingId: outingId,
                speciesId: speciesId,
                quantityCount: quantityCount,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HarvestsTable, Harvest>(table),
                  BaseReferences<_$AppDatabase, $HarvestsTable, Harvest>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HarvestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HarvestsTable,
      Harvest,
      $$HarvestsTableFilterComposer,
      $$HarvestsTableOrderingComposer,
      $$HarvestsTableAnnotationComposer,
      $$HarvestsTableCreateCompanionBuilder,
      $$HarvestsTableUpdateCompanionBuilder,
      (Harvest, BaseReferences<_$AppDatabase, $HarvestsTable, Harvest>),
      Harvest,
      PrefetchHooks Function()
    >;
typedef $$CustomSpeciesTableCreateCompanionBuilder =
    CustomSpeciesCompanion Function({
      required String id,
      required String commonName,
      Value<String> description,
      Value<String?> photoPath,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CustomSpeciesTableUpdateCompanionBuilder =
    CustomSpeciesCompanion Function({
      Value<String> id,
      Value<String> commonName,
      Value<String> description,
      Value<String?> photoPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CustomSpeciesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomSpeciesTable> {
  $$CustomSpeciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomSpeciesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomSpeciesTable> {
  $$CustomSpeciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomSpeciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomSpeciesTable> {
  $$CustomSpeciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomSpeciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomSpeciesTable,
          CustomSpeciesRow,
          $$CustomSpeciesTableFilterComposer,
          $$CustomSpeciesTableOrderingComposer,
          $$CustomSpeciesTableAnnotationComposer,
          $$CustomSpeciesTableCreateCompanionBuilder,
          $$CustomSpeciesTableUpdateCompanionBuilder,
          (
            CustomSpeciesRow,
            BaseReferences<
              _$AppDatabase,
              $CustomSpeciesTable,
              CustomSpeciesRow
            >,
          ),
          CustomSpeciesRow,
          PrefetchHooks Function()
        > {
  $$CustomSpeciesTableTableManager(_$AppDatabase db, $CustomSpeciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomSpeciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomSpeciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomSpeciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> commonName = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomSpeciesCompanion(
                id: id,
                commonName: commonName,
                description: description,
                photoPath: photoPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String commonName,
                Value<String> description = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CustomSpeciesCompanion.insert(
                id: id,
                commonName: commonName,
                description: description,
                photoPath: photoPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomSpeciesTable, CustomSpeciesRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomSpeciesTable,
                    CustomSpeciesRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomSpeciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomSpeciesTable,
      CustomSpeciesRow,
      $$CustomSpeciesTableFilterComposer,
      $$CustomSpeciesTableOrderingComposer,
      $$CustomSpeciesTableAnnotationComposer,
      $$CustomSpeciesTableCreateCompanionBuilder,
      $$CustomSpeciesTableUpdateCompanionBuilder,
      (
        CustomSpeciesRow,
        BaseReferences<_$AppDatabase, $CustomSpeciesTable, CustomSpeciesRow>,
      ),
      CustomSpeciesRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpotsTableTableManager get spots =>
      $$SpotsTableTableManager(_db, _db.spots);
  $$OutingsTableTableManager get outings =>
      $$OutingsTableTableManager(_db, _db.outings);
  $$HarvestsTableTableManager get harvests =>
      $$HarvestsTableTableManager(_db, _db.harvests);
  $$CustomSpeciesTableTableManager get customSpecies =>
      $$CustomSpeciesTableTableManager(_db, _db.customSpecies);
}
