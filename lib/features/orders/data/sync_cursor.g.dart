// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_cursor.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncCursorModelCollection on Isar {
  IsarCollection<SyncCursorModel> get syncCursorModels => this.collection();
}

const SyncCursorModelSchema = CollectionSchema(
  name: r'SyncCursorModel',
  id: -5633630139823007711,
  properties: {
    r'lastPulledAt': PropertySchema(
      id: 0,
      name: r'lastPulledAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _syncCursorModelEstimateSize,
  serialize: _syncCursorModelSerialize,
  deserialize: _syncCursorModelDeserialize,
  deserializeProp: _syncCursorModelDeserializeProp,
  idName: r'isarId',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _syncCursorModelGetId,
  getLinks: _syncCursorModelGetLinks,
  attach: _syncCursorModelAttach,
  version: '3.3.0',
);

int _syncCursorModelEstimateSize(
  SyncCursorModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _syncCursorModelSerialize(
  SyncCursorModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastPulledAt);
}

SyncCursorModel _syncCursorModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncCursorModel();
  object.lastPulledAt = reader.readDateTimeOrNull(offsets[0]);
  return object;
}

P _syncCursorModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncCursorModelGetId(SyncCursorModel object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _syncCursorModelGetLinks(SyncCursorModel object) {
  return [];
}

void _syncCursorModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  SyncCursorModel object,
) {}

extension SyncCursorModelQueryWhereSort
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QWhere> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncCursorModelQueryWhere
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QWhereClause> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SyncCursorModelQueryFilter
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastPulledAt'),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastPulledAt'),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastPulledAt', value: value),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastPulledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastPulledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastPulledAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastPulledAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SyncCursorModelQueryObject
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {}

extension SyncCursorModelQueryLinks
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {}

extension SyncCursorModelQuerySortBy
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QSortBy> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByLastPulledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByLastPulledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledAt', Sort.desc);
    });
  }
}

extension SyncCursorModelQuerySortThenBy
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QSortThenBy> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByLastPulledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByLastPulledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledAt', Sort.desc);
    });
  }
}

extension SyncCursorModelQueryWhereDistinct
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QDistinct> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QDistinct>
  distinctByLastPulledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPulledAt');
    });
  }
}

extension SyncCursorModelQueryProperty
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QQueryProperty> {
  QueryBuilder<SyncCursorModel, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<SyncCursorModel, DateTime?, QQueryOperations>
  lastPulledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPulledAt');
    });
  }
}
