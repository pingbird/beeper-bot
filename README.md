# Beeper - A discord bot

## Example Config

config/bot.yaml

```
development: true
modules:
  - type: database
    uri: beeper:password@server:5432/beeper
  - type: discord
    token: <discord token>
  - type: admin
    uri: localhost:4050
    assetPath: admin/build
  - type: ping
    response: pong
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

* `uri` - The ip and port for the http server to listen to.
* `assetPath` - Optional, the path to static assets (in production we use nginx to serve them instead).

#### modules/commands.dart

This module provides a command invocation and reply system for Discord and RPC.

#### modules/database.dart

This module provides a service to interact with Beeper's PostgreSQL database.

* `uri` - The username, password, host, port, and database name in URI form.

## Admin console development

To make it easier to develop the front-end, you can point the console to connect to a specific uri rather than inferring
it from the origin e.g. `http://127.0.0.1:8080/console/?connect=ws://localhost:4050/ws`.

## Code Quality

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