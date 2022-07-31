import 'package:beeper/beeper.dart';
import 'package:beeper/discord/server.dart';
import 'package:beeper/modules/discord.dart';
import 'package:test/test.dart';

void main() {
  test('Integration test', () async {
    final mockEndpoint = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 8046,
    );

    const mockToken = '12345678aaaaaaaa';

    final mockServer = DiscordServer(
      uri: mockEndpoint,
      validAuthorization: 'Bot $mockToken',
    );

    await mockServer.start();

    final bot = Bot(config: <String, dynamic>{
      'modules': <dynamic>[
        {
          'type': 'database',
          'host': '127.0.0.1',
          'port': 5432,
          'user': 'beeper_test',
          'password': 'test123',
          'database': 'beeper_test',
        },
        {
          'type': 'discord',
          'token': mockToken,
          'endpoint': '$mockEndpoint',
        },
        {
          'type': 'ping',
          'response': 'pong',
        },
      ],
    });

    await bot.start();

    final discord = bot.scope.get<DiscordModule>().discord;

    await discord.connectionStates.where((event) => event.isConnected).first;

    bot.dispose();
  });
}
