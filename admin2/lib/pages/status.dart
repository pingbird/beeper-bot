import 'package:admin2/connection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat.yMMMMd().format(date);
String formatDatePrecise(DateTime date) => DateFormat.jms().format(date);

class StatusPage extends StatelessWidget {
  const StatusPage({
    Key? key,
    required this.statuses,
    required this.info,
  }) : super(key: key);

  final Map<String, dynamic> statuses;
  final BeeperInfo? info;

  @override
  Widget build(BuildContext context) {
    final discordStatus = statuses['/discord'];
    final discordUser = discordStatus?['user'];
    final discordGuilds = discordStatus?['guilds'];
    final dbStatus = statuses['/database'];
    final dbSize = dbStatus?['size'];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discordUser != null)
            DiscordUserTile(
              name: discordUser['name'],
              discriminator:
                  discordUser['discriminator'].toString().padLeft(4, '0'),
              avatar: discordUser['avatar'],
              online: true,
              bot: true,
              backgroundColor: const Color(0xff6a805e),
              aboutMe: info == null
                  ? {}
                  : {
                      'Online Since': formatDate(info!.started),
                      'Plugins': '${statuses.length}',
                      if (discordGuilds != null) 'Guilds': '$discordGuilds',
                      if (dbSize != null) 'DB Size': '$dbSize',
                    },
            ),
        ],
      ),
    );
  }
}

class DiscordUserTile extends StatelessWidget {
  const DiscordUserTile({
    Key? key,
    required this.name,
    required this.discriminator,
    required this.avatar,
    required this.online,
    required this.bot,
    required this.backgroundColor,
    required this.aboutMe,
  }) : super(key: key);

  final String name;
  final String? discriminator;
  final String avatar;
  final bool online;
  final bool bot;
  final Color backgroundColor;
  final Map<String, String> aboutMe;

  @override
  Widget build(BuildContext context) {
    const tileColor = Color(0xff252729);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: tileColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 46),
                child: Container(
                  width: 300,
                  height: 60,
                  color: backgroundColor,
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Stack(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: tileColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(child: Image.network(avatar)),
                    ),
                    Positioned(
                      top: 60,
                      left: 60,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: tileColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(online ? 0xff3ba55d : 0xff747f8d),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              top: 16,
              bottom: 16,
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name),
                  if (discriminator != null)
                    TextSpan(
                      text: '#$discriminator',
                      style: const TextStyle(
                        color: Color(0xffc9c9c9),
                      ),
                    ),
                  if (bot)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff5865f2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 4,
                          top: 3,
                          bottom: 2,
                        ),
                        child: const Text(
                          'BOT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xff33353b),
            margin: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 12,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
            child: Text(
              'ABOUT ME',
              style: GoogleFonts.baloo2(
                color: const Color(0xffb9bbbe),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Column(
              children: [
                for (final entry in aboutMe.entries)
                  Row(
                    children: [
                      Text(
                        '${entry.key} ',
                        style: const TextStyle(color: Color(0xffdcdfe3)),
                      ),
                      Expanded(
                        child: Text(
                          '. ' * 40,
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xff5e626e),
                          ),
                        ),
                      ),
                      Text(
                        ' ${entry.value}',
                        style: const TextStyle(color: Color(0xffdcdfe3)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
