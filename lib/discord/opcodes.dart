abstract class Op {
  Op._();
  static const int dispatch = 0;
  static const int heartbeat = 1;
  static const int identify = 2;
  static const int presenceUpdate = 3;
  static const int voiceStateUpdate = 4;
  static const int voiceGuildPing = 5;
  static const int resume = 6;
  static const int reconnect = 7;
  static const int requestGuildMembers = 8;
  static const int invalidSession = 9;
  static const int hello = 10;
  static const int heartbeatAck = 11;
}

abstract class Intents {
  Intents._();
  static const int guilds = 1;
  static const int guildMembers = 1 << 1;
  static const int guildBans = 1 << 2;
  static const int guildEmojis = 1 << 3;
  static const int guildIntegrations = 1 << 4;
  static const int guildWebhooks = 1 << 5;
  static const int guildInvites = 1 << 6;
  static const int guildVoiceStates = 1 << 7;
  static const int guildPresences = 1 << 8;
  static const int guildMessages = 1 << 9;
  static const int guildMessageReactions = 1 << 10;
  static const int guildMessageTyping = 1 << 11;
  static const int directMessages = 1 << 12;
  static const int directMessageReactions = 1 << 13;
  static const int directMessageTyping = 1 << 14;
}