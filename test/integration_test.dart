import 'package:beeper/discord/discord.dart';
import 'package:beeper/discord/server.dart';
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

    final discord = Discord(
      token: mockToken,
      endpoint: mockEndpoint,
    );

    await discord.start();

    await discord.connectionStates.where((event) => event.isConnected).first;

    discord.destroy();
  });
}