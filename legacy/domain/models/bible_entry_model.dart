import 'package:json_annotation/json_annotation.dart';

part 'bible_entry_model.g.dart';

@JsonSerializable()
class BibleEntryModel {
  final String code;
  final String id;
  @JsonKey(name: 'fcbh_id')
  final String fcbhId;
  final String lang;
  @JsonKey(name: 'lang_en')
  final String langEn;
  final String dialect;
  final String domain;
  final String title;
  final String description;
  final bool redistributable;
  final String copyright;
  @JsonKey(name: 'last_updated')
  final String lastUpdated;
  final int ot;
  final int nt;
  final int dc;
  final bool certified;
  final bool downloadable;
  final String script;
  @JsonKey(name: 'text_direction')
  final String textDirection;
  final String date;
  final String url;

  BibleEntryModel({
    required this.code,
    required this.id,
    required this.fcbhId,
    required this.lang,
    required this.langEn,
    required this.dialect,
    required this.domain,
    required this.title,
    required this.description,
    required this.redistributable,
    required this.copyright,
    required this.lastUpdated,
    required this.ot,
    required this.nt,
    required this.dc,
    required this.certified,
    required this.downloadable,
    required this.script,
    required this.textDirection,
    required this.date,
    required this.url,
  });

  factory BibleEntryModel.fromJson(Map<String, dynamic> json) =>
      _$BibleEntryModelFromJson(json);

  Map<String, dynamic> toJson() => _$BibleEntryModelToJson(this);
}
