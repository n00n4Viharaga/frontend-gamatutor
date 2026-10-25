import 'package:avatar_builder/avatar_builder.dart';

class AvatarConfig {
  final String topType;
  final String accessoriesType;
  final String hairColor; // hex color
  final String facialHairType;
  final String clotheType;
  final String clotheColor;
  final String eyeType;
  final String eyebrowType;
  final String mouthType;
  final String skinColor;
  final String gender;

  AvatarConfig({
    this.topType = 'shortHairShortFlat',
    this.accessoriesType = 'blank',
    this.hairColor = '#4A312C',
    this.facialHairType = 'blank',
    this.clotheType = 'hoodie',
    this.clotheColor = '#3C4F5C',
    this.eyeType = 'defaultEye',
    this.eyebrowType = 'defaultBrow',
    this.mouthType = 'smile',
    this.skinColor = '#EDB98A',
    this.gender = 'male'
  });

static String _colorToHex(int colorValue) {
    return '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  static int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Tambahkan alpha/opacity jika belum ada
    }
    return int.parse(hex, radix: 16);
  }
  // Konversi dari Avataaar (untuk disimpan)
  factory AvatarConfig.fromAvataaar(Avataaar avatar,{String gender = 'male'}) {
    return AvatarConfig(
      topType: avatar.topType.toString().split('.').last, // ★ Pakai ini
      accessoriesType: avatar.accessoriesType.toString().split('.').last,
      hairColor: _colorToHex(avatar.hairColor),
      facialHairType: avatar.facialHairType.toString().split('.').last,
      clotheType: avatar.clotheType.toString().split('.').last,
      clotheColor: _colorToHex(avatar.clotheColor),
      eyeType: avatar.eyeType.toString().split('.').last,
      eyebrowType: avatar.eyebrowType.toString().split('.').last,
      mouthType: avatar.mouthType.toString().split('.').last,
      skinColor: _colorToHex(avatar.skinColor),
      gender: gender
    );
  }

  // Konversi ke Avataaar (untuk ditampilkan)
  Avataaar toAvataaar() {
    return Avataaar(
      topType: TopType.values.firstWhere((e) => e.toString().split('.').last == topType, orElse: () => TopType.shortHairShortFlat),
      accessoriesType: AccessoriesType.values.firstWhere((e) => e.toString().split('.').last == accessoriesType, orElse: () => AccessoriesType.blank),
      hairColor: _hexToColor(hairColor),
      facialHairType: FacialHairType.values.firstWhere((e) => e.toString().split('.').last == facialHairType, orElse: () => FacialHairType.blank),
      clotheType: ClotheType.values.firstWhere((e) => e.toString().split('.').last == clotheType, orElse: () => ClotheType.hoodie),
      clotheColor: _hexToColor(clotheColor),
      eyeType: EyeType.values.firstWhere((e) => e.toString().split('.').last == eyeType, orElse: () => EyeType.defaultEye),
      eyebrowType: EyebrowType.values.firstWhere((e) => e.toString().split('.').last == eyebrowType, orElse: () => EyebrowType.defaultBrow),
      mouthType: MouthType.values.firstWhere((e) => e.toString().split('.').last == mouthType, orElse: () => MouthType.smile),
      skinColor: _hexToColor(skinColor),
      
    );
  }

  Map<String, dynamic> toJson() => {
    'topType': topType,
    'accessoriesType': accessoriesType,
    'hairColor': hairColor,
    'facialHairType': facialHairType,
    'clotheType': clotheType,
    'clotheColor': clotheColor,
    'eyeType': eyeType,
    'eyebrowType': eyebrowType,
    'mouthType': mouthType,
    'skinColor': skinColor,
    'gender': gender
  };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    return AvatarConfig(
      topType: json['topType'] ?? 'shortHairShortFlat',
      accessoriesType: json['accessoriesType'] ?? 'blank',
      hairColor: json['hairColor'] ?? '#4A312C',
      facialHairType: json['facialHairType'] ?? 'blank',
      clotheType: json['clotheType'] ?? 'hoodie',
      clotheColor: json['clotheColor'] ?? '#3C4F5C',
      eyeType: json['eyeType'] ?? 'defaultEye',
      eyebrowType: json['eyebrowType'] ?? 'defaultBrow',
      mouthType: json['mouthType'] ?? 'smile',
      skinColor: json['skinColor'] ?? '#EDB98A',
      gender: json['gender'] ?? 'male'
    );
  }

  AvatarConfig copyWith({
    String? topType,
    String? accessoriesType,
    String? hairColor,
    String? facialHairType,
    String? clotheType,
    String? clotheColor,
    String? eyeType,
    String? eyebrowType,
    String? mouthType,
    String? skinColor,
    String? gender
  }) {
    return AvatarConfig(
      topType: topType ?? this.topType,
      accessoriesType: accessoriesType ?? this.accessoriesType,
      hairColor: hairColor ?? this.hairColor,
      facialHairType: facialHairType ?? this.facialHairType,
      clotheType: clotheType ?? this.clotheType,
      clotheColor: clotheColor ?? this.clotheColor,
      eyeType: eyeType ?? this.eyeType,
      eyebrowType: eyebrowType ?? this.eyebrowType,
      mouthType: mouthType ?? this.mouthType,
      skinColor: skinColor ?? this.skinColor,
      gender: gender ?? this.gender
    );
  }
}