// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_state.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSavedStateCollection on Isar {
  IsarCollection<SavedState> get savedStates => this.collection();
}

const SavedStateSchema = CollectionSchema(
  name: r'SavedState',
  id: 2692369833036462010,
  properties: {
    r'favoriteEventIdsJson': PropertySchema(
      id: 0,
      name: r'favoriteEventIdsJson',
      type: IsarType.string,
    ),
    r'sessionSelectionsJson': PropertySchema(
      id: 1,
      name: r'sessionSelectionsJson',
      type: IsarType.string,
    ),
    r'slotSelectionsJson': PropertySchema(
      id: 2,
      name: r'slotSelectionsJson',
      type: IsarType.string,
    )
  },
  estimateSize: _savedStateEstimateSize,
  serialize: _savedStateSerialize,
  deserialize: _savedStateDeserialize,
  deserializeProp: _savedStateDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _savedStateGetId,
  getLinks: _savedStateGetLinks,
  attach: _savedStateAttach,
  version: '3.1.0+1',
);

int _savedStateEstimateSize(
  SavedState object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.favoriteEventIdsJson.length * 3;
  bytesCount += 3 + object.sessionSelectionsJson.length * 3;
  bytesCount += 3 + object.slotSelectionsJson.length * 3;
  return bytesCount;
}

void _savedStateSerialize(
  SavedState object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.favoriteEventIdsJson);
  writer.writeString(offsets[1], object.sessionSelectionsJson);
  writer.writeString(offsets[2], object.slotSelectionsJson);
}

SavedState _savedStateDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SavedState();
  object.favoriteEventIdsJson = reader.readString(offsets[0]);
  object.id = id;
  object.sessionSelectionsJson = reader.readString(offsets[1]);
  object.slotSelectionsJson = reader.readString(offsets[2]);
  return object;
}

P _savedStateDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _savedStateGetId(SavedState object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _savedStateGetLinks(SavedState object) {
  return [];
}

void _savedStateAttach(IsarCollection<dynamic> col, Id id, SavedState object) {
  object.id = id;
}

extension SavedStateQueryWhereSort
    on QueryBuilder<SavedState, SavedState, QWhere> {
  QueryBuilder<SavedState, SavedState, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SavedStateQueryWhere
    on QueryBuilder<SavedState, SavedState, QWhereClause> {
  QueryBuilder<SavedState, SavedState, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<SavedState, SavedState, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SavedStateQueryFilter
    on QueryBuilder<SavedState, SavedState, QFilterCondition> {
  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'favoriteEventIdsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'favoriteEventIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'favoriteEventIdsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'favoriteEventIdsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      favoriteEventIdsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'favoriteEventIdsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionSelectionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionSelectionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionSelectionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      sessionSelectionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionSelectionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'slotSelectionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'slotSelectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'slotSelectionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'slotSelectionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterFilterCondition>
      slotSelectionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'slotSelectionsJson',
        value: '',
      ));
    });
  }
}

extension SavedStateQueryObject
    on QueryBuilder<SavedState, SavedState, QFilterCondition> {}

extension SavedStateQueryLinks
    on QueryBuilder<SavedState, SavedState, QFilterCondition> {}

extension SavedStateQuerySortBy
    on QueryBuilder<SavedState, SavedState, QSortBy> {
  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortByFavoriteEventIdsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoriteEventIdsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortByFavoriteEventIdsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoriteEventIdsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortBySessionSelectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionSelectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortBySessionSelectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionSelectionsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortBySlotSelectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotSelectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      sortBySlotSelectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotSelectionsJson', Sort.desc);
    });
  }
}

extension SavedStateQuerySortThenBy
    on QueryBuilder<SavedState, SavedState, QSortThenBy> {
  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenByFavoriteEventIdsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoriteEventIdsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenByFavoriteEventIdsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoriteEventIdsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenBySessionSelectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionSelectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenBySessionSelectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionSelectionsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenBySlotSelectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotSelectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedState, SavedState, QAfterSortBy>
      thenBySlotSelectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotSelectionsJson', Sort.desc);
    });
  }
}

extension SavedStateQueryWhereDistinct
    on QueryBuilder<SavedState, SavedState, QDistinct> {
  QueryBuilder<SavedState, SavedState, QDistinct>
      distinctByFavoriteEventIdsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'favoriteEventIdsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedState, SavedState, QDistinct>
      distinctBySessionSelectionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionSelectionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedState, SavedState, QDistinct> distinctBySlotSelectionsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'slotSelectionsJson',
          caseSensitive: caseSensitive);
    });
  }
}

extension SavedStateQueryProperty
    on QueryBuilder<SavedState, SavedState, QQueryProperty> {
  QueryBuilder<SavedState, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SavedState, String, QQueryOperations>
      favoriteEventIdsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'favoriteEventIdsJson');
    });
  }

  QueryBuilder<SavedState, String, QQueryOperations>
      sessionSelectionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionSelectionsJson');
    });
  }

  QueryBuilder<SavedState, String, QQueryOperations>
      slotSelectionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'slotSelectionsJson');
    });
  }
}
