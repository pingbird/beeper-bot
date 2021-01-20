import 'package:beeper/modules/status.dart';
import 'package:beeper/secrets.dart';
import 'package:postgres/postgres.dart';
import 'package:meta/meta.dart';

import 'package:beeper/modules.dart';

@Metadata(name: 'database', loadable: true)
class DatabaseModule extends Module with StatusLoader {
  PostgreSQLConnection connection;

  final String host;
  final int port;
  final String user;
  final String password;
  final String database;

  DatabaseModule({
    @required this.host,
    @required this.port,
    @required this.user,
    @required this.password,
    @required this.database,
  });

  @override
  Future<void> load() async {
    await super.load();
    connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: user,
      password: decryptSecret('postgre-password', password),
    );
    await connection.open();
    log('Connected!');
  }

  @override
  void dispose() {
    super.dispose();
    connection.close();
  }
}