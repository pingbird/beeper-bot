import 'package:admin2/connection.dart';
import 'package:beeper_common/admin.dart';
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
    final discordGuildsData = discordStatus?['guilds'];
    final discordGuilds = discordGuildsData == null
        ? null
        : [
            for (final guild in discordGuildsData)
              DiscordGuildDto.fromJson(guild),
          ];
    final dbStatus = statuses['/database'];
    final dbSize = dbStatus?['size'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (discordUser != null)
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: DiscordUserTile(
                name: discordUser['name'],
                discriminator: discordUser['discriminator'],
                avatar: discordUser['avatar'],
                online: true,
                bot: true,
                backgroundColor: const Color(0xff6a805e),
                aboutMe: info == null
                    ? {}
                    : {
                        'Online Since': formatDate(info!.started),
                        'Plugins': '${statuses.length}',
                        if (discordUser != null)
                          'Snowflake': discordUser['snowflake'],
                        if (discordGuilds != null)
                          'Guilds': '${discordGuilds.length}',
                        if (dbSize != null) 'DB Size': '$dbSize',
                      },
              ),
            ),
          ),
        if (discordGuilds != null)
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.only(
                      bottom: 16,
                      top: 32,
                      left: 16,
                    ),
                    child: Text(
                      'Guilds',
                      style: GoogleFonts.baloo2(fontSize: 24),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return DiscordGuildTile(guild: discordGuilds[index]);
                    },
                    childCount: discordGuilds.length,
                  ),
                )
              ],
            ),
          )
      ],
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
    const tileColor = Color(0xff303336);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: tileColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

class DiscordGuildTile extends StatelessWidget {
  const DiscordGuildTile({
    Key? key,
    required this.guild,
  }) : super(key: key);

  final DiscordGuildDto guild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(8),
          ),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.only(
              top: 8,
              left: 16,
              bottom: 8,
              right: 8,
            ),
            child: Row(
              children: [
                AvatarBubble(
                  size: 48,
                  child: Image.network(
                    guild.icon,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  guild.name,
                  style: GoogleFonts.baloo2(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    Key? key,
    required this.child,
    required this.size,
  }) : super(key: key);

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            spreadRadius: 4,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: size,
        child: child,
      ),
    );
  }
}
