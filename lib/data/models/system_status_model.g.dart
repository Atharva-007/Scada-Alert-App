// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_status_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SystemStatusModelImpl _$$SystemStatusModelImplFromJson(
  Map<String, dynamic> json,
) => _$SystemStatusModelImpl(
  componentName: json['componentName'] as String,
  status: json['status'] as String,
  lastHeartbeat: DateTime.parse(json['lastHeartbeat'] as String),
  version: json['version'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$SystemStatusModelImplToJson(
  _$SystemStatusModelImpl instance,
) => <String, dynamic>{
  'componentName': instance.componentName,
  'status': instance.status,
  'lastHeartbeat': instance.lastHeartbeat.toIso8601String(),
  'version': instance.version,
  'metadata': instance.metadata,
};
