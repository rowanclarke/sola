// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bible_entry_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BibleEntryModel _$BibleEntryModelFromJson(Map<String, dynamic> json) =>
    BibleEntryModel(
      code: json['code'] as String,
      id: json['id'] as String,
      fcbhId: json['fcbh_id'] as String,
      lang: json['lang'] as String,
      langEn: json['lang_en'] as String,
      dialect: json['dialect'] as String,
      domain: json['domain'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      redistributable: json['redistributable'] as bool,
      copyright: json['copyright'] as String,
      lastUpdated: json['last_updated'] as String,
      ot: (json['ot'] as num).toInt(),
      nt: (json['nt'] as num).toInt(),
      dc: (json['dc'] as num).toInt(),
      certified: json['certified'] as bool,
      downloadable: json['downloadable'] as bool,
      script: json['script'] as String,
      textDirection: json['text_direction'] as String,
      date: json['date'] as String,
      url: json['url'] as String,
    );

Map<String, dynamic> _$BibleEntryModelToJson(BibleEntryModel instance) =>
    <String, dynamic>{
      'code': instance.code,
      'id': instance.id,
      'fcbh_id': instance.fcbhId,
      'lang': instance.lang,
      'lang_en': instance.langEn,
      'dialect': instance.dialect,
      'domain': instance.domain,
      'title': instance.title,
      'description': instance.description,
      'redistributable': instance.redistributable,
      'copyright': instance.copyright,
      'last_updated': instance.lastUpdated,
      'ot': instance.ot,
      'nt': instance.nt,
      'dc': instance.dc,
      'certified': instance.certified,
      'downloadable': instance.downloadable,
      'script': instance.script,
      'text_direction': instance.textDirection,
      'date': instance.date,
      'url': instance.url,
    };
