// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_module.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBootstrapPlaceholderCollection on Isar {
  IsarCollection<BootstrapPlaceholder> get bootstrapPlaceholders =>
      this.collection();
}

const BootstrapPlaceholderSchema = CollectionSchema(
  name: r'BootstrapPlaceholder',
  id: -7296846124585294206,
  properties: {},

  estimateSize: _bootstrapPlaceholderEstimateSize,
  serialize: _bootstrapPlaceholderSerialize,
  deserialize: _bootstrapPlaceholderDeserialize,
  deserializeProp: _bootstrapPlaceholderDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _bootstrapPlaceholderGetId,
  getLinks: _bootstrapPlaceholderGetLinks,
  attach: _bootstrapPlaceholderAttach,
  version: '3.3.0',
);

int _bootstrapPlaceholderEstimateSize(
  BootstrapPlaceholder object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _bootstrapPlaceholderSerialize(
  BootstrapPlaceholder object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {}
BootstrapPlaceholder _bootstrapPlaceholderDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BootstrapPlaceholder();
  object.id = id;
  return object;
}

P _bootstrapPlaceholderDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bootstrapPlaceholderGetId(BootstrapPlaceholder object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bootstrapPlaceholderGetLinks(
  BootstrapPlaceholder object,
) {
  return [];
}

void _bootstrapPlaceholderAttach(
  IsarCollection<dynamic> col,
  Id id,
  BootstrapPlaceholder object,
) {
  object.id = id;
}

extension BootstrapPlaceholderQueryWhereSort
    on QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QWhere> {
  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BootstrapPlaceholderQueryWhere
    on QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QWhereClause> {
  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BootstrapPlaceholderQueryFilter
    on
        QueryBuilder<
          BootstrapPlaceholder,
          BootstrapPlaceholder,
          QFilterCondition
        > {
  QueryBuilder<
    BootstrapPlaceholder,
    BootstrapPlaceholder,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    BootstrapPlaceholder,
    BootstrapPlaceholder,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    BootstrapPlaceholder,
    BootstrapPlaceholder,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    BootstrapPlaceholder,
    BootstrapPlaceholder,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BootstrapPlaceholderQueryObject
    on
        QueryBuilder<
          BootstrapPlaceholder,
          BootstrapPlaceholder,
          QFilterCondition
        > {}

extension BootstrapPlaceholderQueryLinks
    on
        QueryBuilder<
          BootstrapPlaceholder,
          BootstrapPlaceholder,
          QFilterCondition
        > {}

extension BootstrapPlaceholderQuerySortBy
    on QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QSortBy> {}

extension BootstrapPlaceholderQuerySortThenBy
    on QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QSortThenBy> {
  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension BootstrapPlaceholderQueryWhereDistinct
    on QueryBuilder<BootstrapPlaceholder, BootstrapPlaceholder, QDistinct> {}

extension BootstrapPlaceholderQueryProperty
    on
        QueryBuilder<
          BootstrapPlaceholder,
          BootstrapPlaceholder,
          QQueryProperty
        > {
  QueryBuilder<BootstrapPlaceholder, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }
}
