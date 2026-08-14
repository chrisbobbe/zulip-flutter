// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: constant_identifier_names, unnecessary_cast

part of 'drafts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetDraftsResult _$GetDraftsResultFromJson(Map<String, dynamic> json) =>
    GetDraftsResult(
      count: (json['count'] as num).toInt(),
      drafts: (json['drafts'] as List<dynamic>)
          .map((e) => Draft.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GetDraftsResultToJson(GetDraftsResult instance) =>
    <String, dynamic>{'count': instance.count, 'drafts': instance.drafts};

CreateDraftsResult _$CreateDraftsResultFromJson(Map<String, dynamic> json) =>
    CreateDraftsResult(
      ids: (json['ids'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$CreateDraftsResultToJson(CreateDraftsResult instance) =>
    <String, dynamic>{'ids': instance.ids};
