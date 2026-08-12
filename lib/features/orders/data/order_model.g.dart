// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOrderModelCollection on Isar {
  IsarCollection<OrderModel> get orderModels => this.collection();
}

const OrderModelSchema = CollectionSchema(
  name: r'OrderModel',
  id: 3315151259962091397,
  properties: {
    r'amountToCharge': PropertySchema(
      id: 0,
      name: r'amountToCharge',
      type: IsarType.double,
    ),
    r'assignedCadeteId': PropertySchema(
      id: 1,
      name: r'assignedCadeteId',
      type: IsarType.string,
    ),
    r'clientName': PropertySchema(
      id: 2,
      name: r'clientName',
      type: IsarType.string,
    ),
    r'clientPhone': PropertySchema(
      id: 3,
      name: r'clientPhone',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 4,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdBy': PropertySchema(
      id: 5,
      name: r'createdBy',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 6,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deliveredAt': PropertySchema(
      id: 7,
      name: r'deliveredAt',
      type: IsarType.dateTime,
    ),
    r'deliveryAddress': PropertySchema(
      id: 8,
      name: r'deliveryAddress',
      type: IsarType.string,
    ),
    r'deliveryProblem': PropertySchema(
      id: 9,
      name: r'deliveryProblem',
      type: IsarType.string,
    ),
    r'id': PropertySchema(id: 10, name: r'id', type: IsarType.string),
    r'items': PropertySchema(
      id: 11,
      name: r'items',
      type: IsarType.objectList,

      target: r'OrderItemModel',
    ),
    r'latitude': PropertySchema(
      id: 12,
      name: r'latitude',
      type: IsarType.double,
    ),
    r'longitude': PropertySchema(
      id: 13,
      name: r'longitude',
      type: IsarType.double,
    ),
    r'notes': PropertySchema(id: 14, name: r'notes', type: IsarType.string),
    r'paymentMethod': PropertySchema(
      id: 15,
      name: r'paymentMethod',
      type: IsarType.byte,
      enumMap: _OrderModelpaymentMethodEnumValueMap,
    ),
    r'paymentStatus': PropertySchema(
      id: 16,
      name: r'paymentStatus',
      type: IsarType.byte,
      enumMap: _OrderModelpaymentStatusEnumValueMap,
    ),
    r'pendingBalance': PropertySchema(
      id: 17,
      name: r'pendingBalance',
      type: IsarType.double,
    ),
    r'resolvedCity': PropertySchema(
      id: 18,
      name: r'resolvedCity',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 19,
      name: r'status',
      type: IsarType.byte,
      enumMap: _OrderModelstatusEnumValueMap,
    ),
    r'syncStatus': PropertySchema(
      id: 20,
      name: r'syncStatus',
      type: IsarType.byte,
      enumMap: _OrderModelsyncStatusEnumValueMap,
    ),
    r'updatedAt': PropertySchema(
      id: 21,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _orderModelEstimateSize,
  serialize: _orderModelSerialize,
  deserialize: _orderModelDeserialize,
  deserializeProp: _orderModelDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'syncStatus': IndexSchema(
      id: 8239539375045684509,
      name: r'syncStatus',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'syncStatus',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'updatedAt': IndexSchema(
      id: -6238191080293565125,
      name: r'updatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'OrderItemModel': OrderItemModelSchema},

  getId: _orderModelGetId,
  getLinks: _orderModelGetLinks,
  attach: _orderModelAttach,
  version: '3.3.0',
);

int _orderModelEstimateSize(
  OrderModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.assignedCadeteId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clientName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clientPhone;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.createdBy.length * 3;
  bytesCount += 3 + object.deliveryAddress.length * 3;
  {
    final value = object.deliveryProblem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.items.length * 3;
  {
    final offsets = allOffsets[OrderItemModel]!;
    for (var i = 0; i < object.items.length; i++) {
      final value = object.items[i];
      bytesCount += OrderItemModelSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolvedCity;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _orderModelSerialize(
  OrderModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.amountToCharge);
  writer.writeString(offsets[1], object.assignedCadeteId);
  writer.writeString(offsets[2], object.clientName);
  writer.writeString(offsets[3], object.clientPhone);
  writer.writeDateTime(offsets[4], object.createdAt);
  writer.writeString(offsets[5], object.createdBy);
  writer.writeDateTime(offsets[6], object.deletedAt);
  writer.writeDateTime(offsets[7], object.deliveredAt);
  writer.writeString(offsets[8], object.deliveryAddress);
  writer.writeString(offsets[9], object.deliveryProblem);
  writer.writeString(offsets[10], object.id);
  writer.writeObjectList<OrderItemModel>(
    offsets[11],
    allOffsets,
    OrderItemModelSchema.serialize,
    object.items,
  );
  writer.writeDouble(offsets[12], object.latitude);
  writer.writeDouble(offsets[13], object.longitude);
  writer.writeString(offsets[14], object.notes);
  writer.writeByte(offsets[15], object.paymentMethod.index);
  writer.writeByte(offsets[16], object.paymentStatus.index);
  writer.writeDouble(offsets[17], object.pendingBalance);
  writer.writeString(offsets[18], object.resolvedCity);
  writer.writeByte(offsets[19], object.status.index);
  writer.writeByte(offsets[20], object.syncStatus.index);
  writer.writeDateTime(offsets[21], object.updatedAt);
}

OrderModel _orderModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OrderModel(
    amountToCharge: reader.readDoubleOrNull(offsets[0]),
    assignedCadeteId: reader.readStringOrNull(offsets[1]),
    clientName: reader.readStringOrNull(offsets[2]),
    clientPhone: reader.readStringOrNull(offsets[3]),
    createdAt: reader.readDateTime(offsets[4]),
    createdBy: reader.readString(offsets[5]),
    deletedAt: reader.readDateTimeOrNull(offsets[6]),
    deliveredAt: reader.readDateTimeOrNull(offsets[7]),
    deliveryAddress: reader.readString(offsets[8]),
    deliveryProblem: reader.readStringOrNull(offsets[9]),
    id: reader.readString(offsets[10]),
    items:
        reader.readObjectList<OrderItemModel>(
          offsets[11],
          OrderItemModelSchema.deserialize,
          allOffsets,
          OrderItemModel(),
        ) ??
        const <OrderItemModel>[],
    latitude: reader.readDoubleOrNull(offsets[12]),
    longitude: reader.readDoubleOrNull(offsets[13]),
    notes: reader.readStringOrNull(offsets[14]),
    paymentMethod:
        _OrderModelpaymentMethodValueEnumMap[reader.readByteOrNull(
          offsets[15],
        )] ??
        PaymentMethod.sinDefinir,
    paymentStatus:
        _OrderModelpaymentStatusValueEnumMap[reader.readByteOrNull(
          offsets[16],
        )] ??
        PaymentStatus.pendiente,
    pendingBalance: reader.readDoubleOrNull(offsets[17]),
    resolvedCity: reader.readStringOrNull(offsets[18]),
    status:
        _OrderModelstatusValueEnumMap[reader.readByteOrNull(offsets[19])] ??
        OrderStatus.pendiente,
    syncStatus:
        _OrderModelsyncStatusValueEnumMap[reader.readByteOrNull(offsets[20])] ??
        SyncStatus.pending,
    updatedAt: reader.readDateTime(offsets[21]),
  );
  return object;
}

P _orderModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readObjectList<OrderItemModel>(
                offset,
                OrderItemModelSchema.deserialize,
                allOffsets,
                OrderItemModel(),
              ) ??
              const <OrderItemModel>[])
          as P;
    case 12:
      return (reader.readDoubleOrNull(offset)) as P;
    case 13:
      return (reader.readDoubleOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (_OrderModelpaymentMethodValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              PaymentMethod.sinDefinir)
          as P;
    case 16:
      return (_OrderModelpaymentStatusValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              PaymentStatus.pendiente)
          as P;
    case 17:
      return (reader.readDoubleOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (_OrderModelstatusValueEnumMap[reader.readByteOrNull(offset)] ??
              OrderStatus.pendiente)
          as P;
    case 20:
      return (_OrderModelsyncStatusValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              SyncStatus.pending)
          as P;
    case 21:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _OrderModelpaymentMethodEnumValueMap = {
  'efectivo': 0,
  'transferencia': 1,
  'sinDefinir': 2,
};
const _OrderModelpaymentMethodValueEnumMap = {
  0: PaymentMethod.efectivo,
  1: PaymentMethod.transferencia,
  2: PaymentMethod.sinDefinir,
};
const _OrderModelpaymentStatusEnumValueMap = {'pendiente': 0, 'cobrado': 1};
const _OrderModelpaymentStatusValueEnumMap = {
  0: PaymentStatus.pendiente,
  1: PaymentStatus.cobrado,
};
const _OrderModelstatusEnumValueMap = {
  'pendiente': 0,
  'asignado': 1,
  'entregado': 2,
  'cancelado': 3,
  'enCamino': 4,
};
const _OrderModelstatusValueEnumMap = {
  0: OrderStatus.pendiente,
  1: OrderStatus.asignado,
  2: OrderStatus.entregado,
  3: OrderStatus.cancelado,
  4: OrderStatus.enCamino,
};
const _OrderModelsyncStatusEnumValueMap = {
  'pending': 0,
  'synced': 1,
  'failed': 2,
};
const _OrderModelsyncStatusValueEnumMap = {
  0: SyncStatus.pending,
  1: SyncStatus.synced,
  2: SyncStatus.failed,
};

Id _orderModelGetId(OrderModel object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _orderModelGetLinks(OrderModel object) {
  return [];
}

void _orderModelAttach(IsarCollection<dynamic> col, Id id, OrderModel object) {}

extension OrderModelByIndex on IsarCollection<OrderModel> {
  Future<OrderModel?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  OrderModel? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<OrderModel?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<OrderModel?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(OrderModel object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(OrderModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<OrderModel> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<OrderModel> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension OrderModelQueryWhereSort
    on QueryBuilder<OrderModel, OrderModel, QWhere> {
  QueryBuilder<OrderModel, OrderModel, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhere> anyStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'status'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhere> anySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'syncStatus'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension OrderModelQueryWhere
    on QueryBuilder<OrderModel, OrderModel, QWhereClause> {
  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> isarIdEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> isarIdNotEqualTo(
    Id isarId,
  ) {
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

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> isarIdGreaterThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> isarIdLessThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> isarIdBetween(
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

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> idEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'id', value: [id]),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> idNotEqualTo(
    String id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> statusEqualTo(
    OrderStatus status,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: [status]),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> statusNotEqualTo(
    OrderStatus status,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> statusGreaterThan(
    OrderStatus status, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [status],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> statusLessThan(
    OrderStatus status, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [],
          upper: [status],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> statusBetween(
    OrderStatus lowerStatus,
    OrderStatus upperStatus, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [lowerStatus],
          includeLower: includeLower,
          upper: [upperStatus],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> syncStatusEqualTo(
    SyncStatus syncStatus,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'syncStatus', value: [syncStatus]),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> syncStatusNotEqualTo(
    SyncStatus syncStatus,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncStatus',
                lower: [],
                upper: [syncStatus],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncStatus',
                lower: [syncStatus],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncStatus',
                lower: [syncStatus],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncStatus',
                lower: [],
                upper: [syncStatus],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> syncStatusGreaterThan(
    SyncStatus syncStatus, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'syncStatus',
          lower: [syncStatus],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> syncStatusLessThan(
    SyncStatus syncStatus, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'syncStatus',
          lower: [],
          upper: [syncStatus],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> syncStatusBetween(
    SyncStatus lowerSyncStatus,
    SyncStatus upperSyncStatus, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'syncStatus',
          lower: [lowerSyncStatus],
          includeLower: includeLower,
          upper: [upperSyncStatus],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> updatedAtEqualTo(
    DateTime updatedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'updatedAt', value: [updatedAt]),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> updatedAtNotEqualTo(
    DateTime updatedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> updatedAtGreaterThan(
    DateTime updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [updatedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> updatedAtLessThan(
    DateTime updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [],
          upper: [updatedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterWhereClause> updatedAtBetween(
    DateTime lowerUpdatedAt,
    DateTime upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [lowerUpdatedAt],
          includeLower: includeLower,
          upper: [upperUpdatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension OrderModelQueryFilter
    on QueryBuilder<OrderModel, OrderModel, QFilterCondition> {
  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'amountToCharge'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'amountToCharge'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'amountToCharge',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amountToCharge',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amountToCharge',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  amountToChargeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amountToCharge',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'assignedCadeteId'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'assignedCadeteId'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'assignedCadeteId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'assignedCadeteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'assignedCadeteId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'assignedCadeteId', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  assignedCadeteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'assignedCadeteId', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'clientName'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'clientName'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> clientNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> clientNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'clientName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'clientName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> clientNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'clientName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'clientName', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'clientName', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'clientPhone'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'clientPhone'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'clientPhone',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'clientPhone',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'clientPhone',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'clientPhone', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  clientPhoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'clientPhone', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  createdByGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdBy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  createdByStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'createdBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> createdByMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'createdBy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  createdByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdBy', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  createdByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'createdBy', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> deletedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deletedAt', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deletedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> deletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deletedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deliveredAt'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deliveredAt'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deliveredAt', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deliveredAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deliveredAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveredAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deliveredAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deliveryAddress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'deliveryAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'deliveryAddress',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deliveryAddress', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'deliveryAddress', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deliveryProblem'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deliveryProblem'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deliveryProblem',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'deliveryProblem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'deliveryProblem',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deliveryProblem', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  deliveryProblemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'deliveryProblem', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> isarIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> isarIdBetween(
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

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  itemsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, true, length, true);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> itemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, 0, true);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  itemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, false, 999999, true);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  itemsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, length, include);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  itemsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, include, 999999, true);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  itemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> latitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'latitude'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  latitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'latitude'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> latitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  latitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> latitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> latitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'latitude',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  longitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'longitude'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  longitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'longitude'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> longitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  longitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> longitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> longitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'longitude',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentMethodEqualTo(PaymentMethod value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'paymentMethod', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentMethodGreaterThan(PaymentMethod value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'paymentMethod',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentMethodLessThan(PaymentMethod value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'paymentMethod',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentMethodBetween(
    PaymentMethod lower,
    PaymentMethod upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'paymentMethod',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentStatusEqualTo(PaymentStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'paymentStatus', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentStatusGreaterThan(PaymentStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'paymentStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentStatusLessThan(PaymentStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'paymentStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  paymentStatusBetween(
    PaymentStatus lower,
    PaymentStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'paymentStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pendingBalance'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pendingBalance'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pendingBalance',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pendingBalance',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pendingBalance',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  pendingBalanceBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pendingBalance',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'resolvedCity'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'resolvedCity'),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'resolvedCity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'resolvedCity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'resolvedCity',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'resolvedCity', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  resolvedCityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'resolvedCity', value: ''),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> statusEqualTo(
    OrderStatus value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> statusGreaterThan(
    OrderStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> statusLessThan(
    OrderStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> statusBetween(
    OrderStatus lower,
    OrderStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> syncStatusEqualTo(
    SyncStatus value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncStatus', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  syncStatusGreaterThan(SyncStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'syncStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  syncStatusLessThan(SyncStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'syncStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> syncStatusBetween(
    SyncStatus lower,
    SyncStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'syncStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension OrderModelQueryObject
    on QueryBuilder<OrderModel, OrderModel, QFilterCondition> {
  QueryBuilder<OrderModel, OrderModel, QAfterFilterCondition> itemsElement(
    FilterQuery<OrderItemModel> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'items');
    });
  }
}

extension OrderModelQueryLinks
    on QueryBuilder<OrderModel, OrderModel, QFilterCondition> {}

extension OrderModelQuerySortBy
    on QueryBuilder<OrderModel, OrderModel, QSortBy> {
  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByAmountToCharge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountToCharge', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  sortByAmountToChargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountToCharge', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByAssignedCadeteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedCadeteId', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  sortByAssignedCadeteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedCadeteId', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByClientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByClientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByClientPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByClientPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeliveredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveredAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeliveredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveredAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeliveryAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  sortByDeliveryAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByDeliveryProblem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryProblem', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  sortByDeliveryProblemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryProblem', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByPaymentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByPaymentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByPendingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBalance', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  sortByPendingBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBalance', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByResolvedCity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedCity', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByResolvedCityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedCity', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension OrderModelQuerySortThenBy
    on QueryBuilder<OrderModel, OrderModel, QSortThenBy> {
  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByAmountToCharge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountToCharge', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  thenByAmountToChargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountToCharge', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByAssignedCadeteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedCadeteId', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  thenByAssignedCadeteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedCadeteId', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByClientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByClientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByClientPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByClientPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeliveredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveredAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeliveredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveredAt', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeliveryAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  thenByDeliveryAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryAddress', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByDeliveryProblem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryProblem', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  thenByDeliveryProblemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryProblem', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByPaymentMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentMethod', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByPaymentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByPaymentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentStatus', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByPendingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBalance', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy>
  thenByPendingBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBalance', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByResolvedCity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedCity', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByResolvedCityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedCity', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension OrderModelQueryWhereDistinct
    on QueryBuilder<OrderModel, OrderModel, QDistinct> {
  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByAmountToCharge() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountToCharge');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByAssignedCadeteId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'assignedCadeteId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByClientName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByClientPhone({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientPhone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByCreatedBy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByDeliveredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deliveredAt');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByDeliveryAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'deliveryAddress',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByDeliveryProblem({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'deliveryProblem',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latitude');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longitude');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByNotes({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByPaymentMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paymentMethod');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByPaymentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paymentStatus');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByPendingBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingBalance');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByResolvedCity({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedCity', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus');
    });
  }

  QueryBuilder<OrderModel, OrderModel, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension OrderModelQueryProperty
    on QueryBuilder<OrderModel, OrderModel, QQueryProperty> {
  QueryBuilder<OrderModel, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<OrderModel, double?, QQueryOperations> amountToChargeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountToCharge');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations>
  assignedCadeteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedCadeteId');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations> clientNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientName');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations> clientPhoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientPhone');
    });
  }

  QueryBuilder<OrderModel, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<OrderModel, String, QQueryOperations> createdByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdBy');
    });
  }

  QueryBuilder<OrderModel, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<OrderModel, DateTime?, QQueryOperations> deliveredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveredAt');
    });
  }

  QueryBuilder<OrderModel, String, QQueryOperations> deliveryAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryAddress');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations>
  deliveryProblemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryProblem');
    });
  }

  QueryBuilder<OrderModel, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OrderModel, List<OrderItemModel>, QQueryOperations>
  itemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'items');
    });
  }

  QueryBuilder<OrderModel, double?, QQueryOperations> latitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latitude');
    });
  }

  QueryBuilder<OrderModel, double?, QQueryOperations> longitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longitude');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<OrderModel, PaymentMethod, QQueryOperations>
  paymentMethodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentMethod');
    });
  }

  QueryBuilder<OrderModel, PaymentStatus, QQueryOperations>
  paymentStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentStatus');
    });
  }

  QueryBuilder<OrderModel, double?, QQueryOperations> pendingBalanceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingBalance');
    });
  }

  QueryBuilder<OrderModel, String?, QQueryOperations> resolvedCityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedCity');
    });
  }

  QueryBuilder<OrderModel, OrderStatus, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<OrderModel, SyncStatus, QQueryOperations> syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<OrderModel, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const OrderItemModelSchema = Schema(
  name: r'OrderItemModel',
  id: 3320497907544385651,
  properties: {
    r'productName': PropertySchema(
      id: 0,
      name: r'productName',
      type: IsarType.string,
    ),
    r'quantity': PropertySchema(id: 1, name: r'quantity', type: IsarType.long),
    r'sourceVentaId': PropertySchema(
      id: 2,
      name: r'sourceVentaId',
      type: IsarType.string,
    ),
  },

  estimateSize: _orderItemModelEstimateSize,
  serialize: _orderItemModelSerialize,
  deserialize: _orderItemModelDeserialize,
  deserializeProp: _orderItemModelDeserializeProp,
);

int _orderItemModelEstimateSize(
  OrderItemModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.productName.length * 3;
  {
    final value = object.sourceVentaId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _orderItemModelSerialize(
  OrderItemModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.productName);
  writer.writeLong(offsets[1], object.quantity);
  writer.writeString(offsets[2], object.sourceVentaId);
}

OrderItemModel _orderItemModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OrderItemModel(
    productName: reader.readStringOrNull(offsets[0]) ?? '',
    quantity: reader.readLongOrNull(offsets[1]) ?? 0,
    sourceVentaId: reader.readStringOrNull(offsets[2]),
  );
  return object;
}

P _orderItemModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension OrderItemModelQueryFilter
    on QueryBuilder<OrderItemModel, OrderItemModel, QFilterCondition> {
  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'productName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'productName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productName', value: ''),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  productNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'productName', value: ''),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  quantityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'quantity', value: value),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  quantityGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantity',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  quantityLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantity',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  quantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceVentaId'),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceVentaId'),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceVentaId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceVentaId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceVentaId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceVentaId', value: ''),
      );
    });
  }

  QueryBuilder<OrderItemModel, OrderItemModel, QAfterFilterCondition>
  sourceVentaIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceVentaId', value: ''),
      );
    });
  }
}

extension OrderItemModelQueryObject
    on QueryBuilder<OrderItemModel, OrderItemModel, QFilterCondition> {}
