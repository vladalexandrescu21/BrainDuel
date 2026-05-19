class TopicModel {
  final String id;
  final String nameRo;
  final String nameEn;
  final String emoji;

  const TopicModel({
    required this.id,
    required this.nameRo,
    required this.nameEn,
    required this.emoji,
  });

  String get name => nameRo; // default to Romanian; can be made dynamic

  String localizedName(bool isRomanian) => isRomanian ? nameRo : nameEn;
}
