class LoginStateDto {
  LoginStateDto({
    required this.signedIn,
    this.name,
    this.discriminator,
    this.avatar,
  });

  final bool signedIn;
  final String? name;
  final String? discriminator;
  final String? avatar;

  factory LoginStateDto.fromJson(Map<String, dynamic> json) => LoginStateDto(
        signedIn: json['signedIn'] as bool,
        name: json['name'] as String?,
        discriminator: json['discriminator'] as String?,
        avatar: json['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'signedIn': signedIn,
        'name': name,
        'discriminator': discriminator,
        'avatar': avatar,
      };
}
