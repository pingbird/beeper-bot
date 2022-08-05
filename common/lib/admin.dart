class LoginStateDto {
  LoginStateDto({
    required this.signedIn,
    this.snowflake,
    this.name,
    this.discriminator,
    this.avatar,
  });

  final bool signedIn;
  final String? snowflake;
  final String? name;
  final String? discriminator;
  final String? avatar;

  factory LoginStateDto.fromJson(Map<String, dynamic> json) => LoginStateDto(
        signedIn: json['signedIn'] as bool,
        snowflake: json['snowflake'] as String?,
        name: json['name'] as String?,
        discriminator: json['discriminator'] as String?,
        avatar: json['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'signedIn': signedIn,
        'snowflake': snowflake,
        'name': name,
        'discriminator': discriminator,
        'avatar': avatar,
      };
}

class DiscordGuildDto {
  DiscordGuildDto({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final String icon;

  factory DiscordGuildDto.fromJson(Map<String, dynamic> json) =>
      DiscordGuildDto(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'icon': icon,
      };
}
