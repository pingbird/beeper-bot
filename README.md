# Beeper - A discord bot

## Example Config

config/bot.yaml

```
development: true
modules:
  - type: database
    host: localhost
    port: 5432
    user: beeper
    password: <database password>
    database: beeper
  - type: discord
    token: <discord token>
  - type: admin
    uri: localhost:4050
    assetPath: admin/build
  - type: ping
    response: pong
```

## Secrets

Modules can optionally use AES256 to decrypt passwords and tokens given to them, the master key for this encryption is
provided through the `BEEPER_SECRET_KEY` environment variable.

The entry point at `bin/encrypt_secret.dart` can be used to encrypt secrets:

```
$ BEEPER_SECRET_KEY=hunter2 dart bin/encrypt_secret.dart discord-token NGZjMzE3NTkyZjUzNDM3OTViM
g2JRs5ZTbcnh5/ptWJgL0gAAAAAAAAAA0Vgz2NEj/fbJ0bPoDM/9E7GUuqHzvZUmplg3V66aTRQ=
```

Likewise, you can use `bin/decrypt_secret.dart` to decrypt them:

```
$ BEEPER_SECRET_KEY=hunter2 dart bin/decrypt_secret.dart discord-token g2JRs5ZTbcnh5/ptWJgL0gAAAAAAAAAA0Vgz2NEj/fbJ0bPoDM/9E7GUuqHzvZUmplg3V66aTRQ=
NGZjMzE3NTkyZjUzNDM3OTViM
```

## Setting up database

Beeper uses postgresql, on Debian the following commands can be used to install postgre, create a user, and create a
database:

```
sudo apt install -y postgresql-13
sudo pg_ctlcluster 13 main start
export BEEPER_DB_PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32}`
sudo -u postgres bash -c "psql -c \"CREATE USER beeper WITH PASSWORD '$BEEPER_DB_PASSWORD';\""
echo Database password: $BEEPER_DB_PASSWORD
unset BEEPER_DB_PASSWORD
sudo -u postgres createdb -O beeper beeper
```

The following command will set up a beeper_test user for integration tests:

```
sudo -u postgres bash -c "psql -c \"CREATE USER beeper_test WITH PASSWORD 'test123';\""
sudo -u postgres createdb -O beeper_test beeper_test
```

## Architecture

Beeper consists of well-defined layers, each with their own library:

```
+-------------------+
| Bot               | Module and configuration system
+-------------------+
| Discord           | Public interface for interacting with the Discord API
+-------------------+
| DiscordState      | Internal interface for updating and caching entities
+-------------------+
| DiscordConnection | Handles gateway connection, dispatches events
+-------------------+
| HttpService       | HTTP authorization and rate limiting
+-------------------+
```

## Modules

#### modules/discord.dart

This module manages a connection to Discord.

* `token` - The bot's discord token.

#### modules/admin.dart

This module provides a web interface for viewing logs and managing the bot.

* `uri` - The ip and port for the http server to listen to
* `assetPath` - Optional, the path to static assets (in production we use nginx to serve them instead)

#### modules/commands.dart

This module provides a command invocation and reply system for Discord and RPC.

#### modules/database.dart

This module provides a service to interact with Beeper's PostgreSQL database.

* `host` - The hostname of the database
* `port` - The port of the database
* `user` - The user to authenticate with
* `password` - The password of the user
* `database` - The database name

## Admin console development

To make it easier to develop the front-end, you can point the console to connect to a specific uri rather than inferring
it from the origin e.g. `http://127.0.0.1:8080/console/?connect=ws://localhost:4050/ws`.

## Contributors

When in doubt refer to https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo

#### Documentation

No documentation is better than bad documentation.

This is a small project so comments don't matter too much, just make sure everybody is in the loop and the code is
understandable.

#### Tests

Code should be testable, this means extensive use of DI to access external resources like files and databases.

Basic integration tests should be added for major new features before a production release, more extensive unit testing
is reserved for core components and components that are likely to be broken.

#### Style Preferences

1. Final members assigned by the constructor should go before the constructor.
1. Prefer newline + indent over alignment for expressions that span multiple lines.
1. Package imports are in the following order: dart, external, and internal.
1. Like the Flutter style guide, returns, breaks, etc. get their own line.