# Beeper - A discord bot

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