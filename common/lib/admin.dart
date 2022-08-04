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
