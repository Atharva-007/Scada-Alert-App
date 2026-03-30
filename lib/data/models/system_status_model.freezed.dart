// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_status_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SystemStatusModel _$SystemStatusModelFromJson(Map<String, dynamic> json) {
  return _SystemStatusModel.fromJson(json);
}

/// @nodoc
mixin _$SystemStatusModel {
  String get componentName => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get lastHeartbeat => throw _privateConstructorUsedError;
  String? get version => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this SystemStatusModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SystemStatusModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemStatusModelCopyWith<SystemStatusModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemStatusModelCopyWith<$Res> {
  factory $SystemStatusModelCopyWith(
    SystemStatusModel value,
    $Res Function(SystemStatusModel) then,
  ) = _$SystemStatusModelCopyWithImpl<$Res, SystemStatusModel>;
  @useResult
  $Res call({
    String componentName,
    String status,
    DateTime lastHeartbeat,
    String? version,
    Map<String, dynamic>? metadata,
  });
}

/// @nodoc
class _$SystemStatusModelCopyWithImpl<$Res, $Val extends SystemStatusModel>
    implements $SystemStatusModelCopyWith<$Res> {
  _$SystemStatusModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemStatusModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? componentName = null,
    Object? status = null,
    Object? lastHeartbeat = null,
    Object? version = freezed,
    Object? metadata = freezed,
  }) {
    return _then(
      _value.copyWith(
            componentName: null == componentName
                ? _value.componentName
                : componentName // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            lastHeartbeat: null == lastHeartbeat
                ? _value.lastHeartbeat
                : lastHeartbeat // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            version: freezed == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String?,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SystemStatusModelImplCopyWith<$Res>
    implements $SystemStatusModelCopyWith<$Res> {
  factory _$$SystemStatusModelImplCopyWith(
    _$SystemStatusModelImpl value,
    $Res Function(_$SystemStatusModelImpl) then,
  ) = __$$SystemStatusModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String componentName,
    String status,
    DateTime lastHeartbeat,
    String? version,
    Map<String, dynamic>? metadata,
  });
}

/// @nodoc
class __$$SystemStatusModelImplCopyWithImpl<$Res>
    extends _$SystemStatusModelCopyWithImpl<$Res, _$SystemStatusModelImpl>
    implements _$$SystemStatusModelImplCopyWith<$Res> {
  __$$SystemStatusModelImplCopyWithImpl(
    _$SystemStatusModelImpl _value,
    $Res Function(_$SystemStatusModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SystemStatusModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? componentName = null,
    Object? status = null,
    Object? lastHeartbeat = null,
    Object? version = freezed,
    Object? metadata = freezed,
  }) {
    return _then(
      _$SystemStatusModelImpl(
        componentName: null == componentName
            ? _value.componentName
            : componentName // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        lastHeartbeat: null == lastHeartbeat
            ? _value.lastHeartbeat
            : lastHeartbeat // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        version: freezed == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String?,
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SystemStatusModelImpl implements _SystemStatusModel {
  const _$SystemStatusModelImpl({
    required this.componentName,
    required this.status,
    required this.lastHeartbeat,
    this.version,
    final Map<String, dynamic>? metadata,
  }) : _metadata = metadata;

  factory _$SystemStatusModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SystemStatusModelImplFromJson(json);

  @override
  final String componentName;
  @override
  final String status;
  @override
  final DateTime lastHeartbeat;
  @override
  final String? version;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'SystemStatusModel(componentName: $componentName, status: $status, lastHeartbeat: $lastHeartbeat, version: $version, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemStatusModelImpl &&
            (identical(other.componentName, componentName) ||
                other.componentName == componentName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastHeartbeat, lastHeartbeat) ||
                other.lastHeartbeat == lastHeartbeat) &&
            (identical(other.version, version) || other.version == version) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    componentName,
    status,
    lastHeartbeat,
    version,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of SystemStatusModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemStatusModelImplCopyWith<_$SystemStatusModelImpl> get copyWith =>
      __$$SystemStatusModelImplCopyWithImpl<_$SystemStatusModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SystemStatusModelImplToJson(this);
  }
}

abstract class _SystemStatusModel implements SystemStatusModel {
  const factory _SystemStatusModel({
    required final String componentName,
    required final String status,
    required final DateTime lastHeartbeat,
    final String? version,
    final Map<String, dynamic>? metadata,
  }) = _$SystemStatusModelImpl;

  factory _SystemStatusModel.fromJson(Map<String, dynamic> json) =
      _$SystemStatusModelImpl.fromJson;

  @override
  String get componentName;
  @override
  String get status;
  @override
  DateTime get lastHeartbeat;
  @override
  String? get version;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of SystemStatusModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemStatusModelImplCopyWith<_$SystemStatusModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DashboardSummary {
  int get activeCritical => throw _privateConstructorUsedError;
  int get activeWarning => throw _privateConstructorUsedError;
  int get acknowledgedCount => throw _privateConstructorUsedError;
  int get clearedLast24h => throw _privateConstructorUsedError;
  List<SystemStatusModel> get systemStatuses =>
      throw _privateConstructorUsedError;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardSummaryCopyWith<DashboardSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardSummaryCopyWith<$Res> {
  factory $DashboardSummaryCopyWith(
    DashboardSummary value,
    $Res Function(DashboardSummary) then,
  ) = _$DashboardSummaryCopyWithImpl<$Res, DashboardSummary>;
  @useResult
  $Res call({
    int activeCritical,
    int activeWarning,
    int acknowledgedCount,
    int clearedLast24h,
    List<SystemStatusModel> systemStatuses,
  });
}

/// @nodoc
class _$DashboardSummaryCopyWithImpl<$Res, $Val extends DashboardSummary>
    implements $DashboardSummaryCopyWith<$Res> {
  _$DashboardSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeCritical = null,
    Object? activeWarning = null,
    Object? acknowledgedCount = null,
    Object? clearedLast24h = null,
    Object? systemStatuses = null,
  }) {
    return _then(
      _value.copyWith(
            activeCritical: null == activeCritical
                ? _value.activeCritical
                : activeCritical // ignore: cast_nullable_to_non_nullable
                      as int,
            activeWarning: null == activeWarning
                ? _value.activeWarning
                : activeWarning // ignore: cast_nullable_to_non_nullable
                      as int,
            acknowledgedCount: null == acknowledgedCount
                ? _value.acknowledgedCount
                : acknowledgedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            clearedLast24h: null == clearedLast24h
                ? _value.clearedLast24h
                : clearedLast24h // ignore: cast_nullable_to_non_nullable
                      as int,
            systemStatuses: null == systemStatuses
                ? _value.systemStatuses
                : systemStatuses // ignore: cast_nullable_to_non_nullable
                      as List<SystemStatusModel>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardSummaryImplCopyWith<$Res>
    implements $DashboardSummaryCopyWith<$Res> {
  factory _$$DashboardSummaryImplCopyWith(
    _$DashboardSummaryImpl value,
    $Res Function(_$DashboardSummaryImpl) then,
  ) = __$$DashboardSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int activeCritical,
    int activeWarning,
    int acknowledgedCount,
    int clearedLast24h,
    List<SystemStatusModel> systemStatuses,
  });
}

/// @nodoc
class __$$DashboardSummaryImplCopyWithImpl<$Res>
    extends _$DashboardSummaryCopyWithImpl<$Res, _$DashboardSummaryImpl>
    implements _$$DashboardSummaryImplCopyWith<$Res> {
  __$$DashboardSummaryImplCopyWithImpl(
    _$DashboardSummaryImpl _value,
    $Res Function(_$DashboardSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeCritical = null,
    Object? activeWarning = null,
    Object? acknowledgedCount = null,
    Object? clearedLast24h = null,
    Object? systemStatuses = null,
  }) {
    return _then(
      _$DashboardSummaryImpl(
        activeCritical: null == activeCritical
            ? _value.activeCritical
            : activeCritical // ignore: cast_nullable_to_non_nullable
                  as int,
        activeWarning: null == activeWarning
            ? _value.activeWarning
            : activeWarning // ignore: cast_nullable_to_non_nullable
                  as int,
        acknowledgedCount: null == acknowledgedCount
            ? _value.acknowledgedCount
            : acknowledgedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        clearedLast24h: null == clearedLast24h
            ? _value.clearedLast24h
            : clearedLast24h // ignore: cast_nullable_to_non_nullable
                  as int,
        systemStatuses: null == systemStatuses
            ? _value._systemStatuses
            : systemStatuses // ignore: cast_nullable_to_non_nullable
                  as List<SystemStatusModel>,
      ),
    );
  }
}

/// @nodoc

class _$DashboardSummaryImpl implements _DashboardSummary {
  const _$DashboardSummaryImpl({
    required this.activeCritical,
    required this.activeWarning,
    required this.acknowledgedCount,
    required this.clearedLast24h,
    required final List<SystemStatusModel> systemStatuses,
  }) : _systemStatuses = systemStatuses;

  @override
  final int activeCritical;
  @override
  final int activeWarning;
  @override
  final int acknowledgedCount;
  @override
  final int clearedLast24h;
  final List<SystemStatusModel> _systemStatuses;
  @override
  List<SystemStatusModel> get systemStatuses {
    if (_systemStatuses is EqualUnmodifiableListView) return _systemStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_systemStatuses);
  }

  @override
  String toString() {
    return 'DashboardSummary(activeCritical: $activeCritical, activeWarning: $activeWarning, acknowledgedCount: $acknowledgedCount, clearedLast24h: $clearedLast24h, systemStatuses: $systemStatuses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSummaryImpl &&
            (identical(other.activeCritical, activeCritical) ||
                other.activeCritical == activeCritical) &&
            (identical(other.activeWarning, activeWarning) ||
                other.activeWarning == activeWarning) &&
            (identical(other.acknowledgedCount, acknowledgedCount) ||
                other.acknowledgedCount == acknowledgedCount) &&
            (identical(other.clearedLast24h, clearedLast24h) ||
                other.clearedLast24h == clearedLast24h) &&
            const DeepCollectionEquality().equals(
              other._systemStatuses,
              _systemStatuses,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    activeCritical,
    activeWarning,
    acknowledgedCount,
    clearedLast24h,
    const DeepCollectionEquality().hash(_systemStatuses),
  );

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSummaryImplCopyWith<_$DashboardSummaryImpl> get copyWith =>
      __$$DashboardSummaryImplCopyWithImpl<_$DashboardSummaryImpl>(
        this,
        _$identity,
      );
}

abstract class _DashboardSummary implements DashboardSummary {
  const factory _DashboardSummary({
    required final int activeCritical,
    required final int activeWarning,
    required final int acknowledgedCount,
    required final int clearedLast24h,
    required final List<SystemStatusModel> systemStatuses,
  }) = _$DashboardSummaryImpl;

  @override
  int get activeCritical;
  @override
  int get activeWarning;
  @override
  int get acknowledgedCount;
  @override
  int get clearedLast24h;
  @override
  List<SystemStatusModel> get systemStatuses;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardSummaryImplCopyWith<_$DashboardSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
