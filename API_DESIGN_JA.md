# Public API Design（公開API設計書）

このドキュメントは、`fluxer-zig` ライブラリの公開インターフェイスを擬似コード / Zig風の構文で記述したものです。実装の指針となり、利用者の参考資料として機能することを目的としています。

## クライアント初期化 (Client Initialization)

```zig
const std = @import("std");
const fluxer = @import("fluxer");

const Client = fluxer.Client;
const Intents = fluxer.Intents;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const token = "my_bot_token";

    var client = try Client.init(allocator, .{
        .token = token,
        .intents = Intents.guildMessages().combine(Intents.guilds()).value,
        .cache = .{ .enabled = true },
        .num_shards = 1,
    });
    defer client.deinit();

    var my_handler: MyHandler = .{};
    const handler = fluxer.EventHandler{
        .ptr = &my_handler,
        .vtable = &MyHandler.vtable,
    };

    try client.connect(handler, &my_handler);
}
```

## クライアント設定 (Client Configuration)

```zig
pub const ClientOptions = struct {
    token: []const u8,
    auth_type: AuthType = .Bot,
    intents: u64 = 0,
    num_shards: u32 = 1,
    cache: CacheOptions = .{},
};
```

## イベントハンドラインターフェイス (Event Handler Interface)

利用者は `EventHandler` インターフェイスをVTable方式で実装し、イベントを受け取ります。

```zig
pub const EventHandler = struct {
    pub const VTable = struct {
        onReady: *const fn (ptr: *anyopaque, payload: ReadyPayload) void,
        onMessageCreate: *const fn (ptr: *anyopaque, payload: Message) void,
        onMessageUpdate: *const fn (ptr: *anyopaque, payload: Message) void,
        onMessageDelete: *const fn (ptr: *anyopaque, payload: MessageDeletePayload) void,
        onGuildCreate: *const fn (ptr: *anyopaque, payload: Guild) void,
        onGuildUpdate: *const fn (ptr: *anyopaque, payload: Guild) void,
        onGuildDelete: *const fn (ptr: *anyopaque, payload: GuildDeletePayload) void,
        onChannelCreate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onChannelUpdate: *const fn (ptr: *anyopaque, payload: Channel) void,
        onChannelDelete: *const fn (ptr: *anyopaque, payload: ChannelDeletePayload) void,
        onGuildMemberAdd: *const fn (ptr: *anyopaque, payload: GuildMember) void,
        onGuildMemberUpdate: *const fn (ptr: *anyopaque, payload: GuildMember) void,
        onGuildMemberRemove: *const fn (ptr: *anyopaque, payload: GuildMemberRemovePayload) void,
        onRawGatewayPayload: *const fn (ptr: *anyopaque, payload: GatewayPayload) void,
        onRawREST: *const fn (ptr: *anyopaque, response: Response) void,
    };

    ptr: *anyopaque,
    vtable: *const VTable,
};
```

## 認証方式 (Auth Type)

`HttpClient` および `Client` は、`AuthType` 列挙型を介して複数の認証スキームをサポートします。

```zig
pub const AuthType = enum {
    Session, // Authorization: <token>
    Bearer,  // Authorization: Bearer <token>
    Bot,     // Authorization: Bot <token>
    Admin,   // Authorization: Admin <token>
};
```

- **Session**: プレーンなセッショントークン（プレフィックスなし）。ユーザー向けエンドポイントで使用されます。
- **Bearer**: Bearerトークン。通常はOAuth2アクセストークンに使用されます。
- **Bot**: Botトークン（デフォルト）。ボットアプリケーションの主要な認証方式です。
- **Admin**: 管理用APIキー。`/admin/*` エンドポイントに限定されます。

## HTTPクライアント (HTTP Client)

高度なユースケースには、`HttpClient` を介して直接HTTPアクセスが可能です。

### ベースURL

REST APIのベースURLは `https://api.fluxer.app/v1` です。

```zig
pub const HttpClient = struct {
    pub fn init(allocator: std.mem.Allocator, token: []const u8, auth_type: AuthType) !HttpClient;
    pub fn deinit(self: *HttpClient) void;

    pub fn request(self: *HttpClient, method: std.http.Method, path: []const u8, options: RequestOptions) !Response;
    pub fn get(self: *HttpClient, path: []const u8) !Response;
    pub fn post(self: *HttpClient, path: []const u8, body: ?[]const u8) !Response;
    pub fn patch(self: *HttpClient, path: []const u8, body: ?[]const u8) !Response;
    pub fn delete(self: *HttpClient, path: []const u8) !Response;
};
```

### 高レベルクライアントメソッド (High-level Client Methods)

`Client` 構造体は `HttpClient` をラップし、型付きヘルパーメソッドを提供します。

```zig
pub const Client = struct {
    // チャンネル (Channels)
    pub fn getChannel(self: *Client, id: Snowflake) !std.json.Parsed(Channel);
    pub fn modifyChannel(self: *Client, id: Snowflake, data: anytype) !std.json.Parsed(Channel);
    pub fn deleteChannel(self: *Client, id: Snowflake) !std.json.Parsed(Channel);
    pub fn getChannelMessages(self: *Client, id: Snowflake, query: ?[]const u8) !std.json.Parsed([]Message);
    pub fn getChannelMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !std.json.Parsed(Message);
    pub fn createMessage(self: *Client, channel_id: Snowflake, content: []const u8) !std.json.Parsed(Message);
    pub fn editMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake, content: []const u8) !std.json.Parsed(Message);
    pub fn deleteMessage(self: *Client, channel_id: Snowflake, message_id: Snowflake) !void;

    // ギルド (Guilds)
    pub fn getGuild(self: *Client, id: Snowflake) !std.json.Parsed(Guild);
    pub fn getGuildChannels(self: *Client, id: Snowflake) !std.json.Parsed([]Channel);
    pub fn createGuildChannel(self: *Client, id: Snowflake, name: []const u8) !std.json.Parsed(Channel);
    pub fn getGuildMember(self: *Client, guild_id: Snowflake, user_id: Snowflake) !std.json.Parsed(GuildMember);
    pub fn getGuildMembers(self: *Client, guild_id: Snowflake, limit: ?u32) !std.json.Parsed([]GuildMember);

    // ユーザー (Users)
    pub fn getCurrentUser(self: *Client) !std.json.Parsed(User);
    pub fn getUser(self: *Client, id: Snowflake) !std.json.Parsed(User);
};
```

## モデル（抜粋） (Models (Selected))

```zig
pub const Snowflake = struct {
    value: u64,

    pub const Epoch: u64 = 1420070400000;

    pub fn fromU64(id: u64) Snowflake;
    pub fn toU64(self: Snowflake) u64;
    pub fn timestamp(self: Snowflake) u64;
    pub fn workerId(self: Snowflake) u64;
    pub fn processId(self: Snowflake) u64;
    pub fn increment(self: Snowflake) u64;
    pub fn parse(str: []const u8) !Snowflake;
    pub fn format(self: Snowflake, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void;
    pub fn eql(self: Snowflake, other: Snowflake) bool;
    pub fn hash(self: Snowflake) u64;
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Snowflake;
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !Snowflake;
    pub fn jsonStringify(self: Snowflake, jw: anytype) !void;
};

pub const User = struct {
    id: Snowflake,
    username: []const u8,
    discriminator: ?[]const u8 = null,
    global_name: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    bot: bool = false,
    system: bool = false,
    // Fluxer固有フィールド
    pronouns: ?[]const u8 = null,
    bio: ?[]const u8 = null,
    accent_color: ?u32 = null,
    avatar_color: ?u32 = null,
    traits: ?[]const u8 = null,
    premium_lifetime_sequence: ?u64 = null,
};

pub const Guild = struct {
    id: Snowflake,
    name: []const u8,
    icon: ?[]const u8 = null,
    icon_hash: ?[]const u8 = null,
    splash: ?[]const u8 = null,
    discovery_splash: ?[]const u8 = null,
    owner: ?bool = null,
    owner_id: Snowflake,
    permissions: ?[]const u8 = null,
    region: ?[]const u8 = null,
    afk_channel_id: ?Snowflake = null,
    afk_timeout: u32,
    widget_enabled: ?bool = null,
    widget_channel_id: ?Snowflake = null,
    verification_level: u32,
    default_message_notifications: u32,
    explicit_content_filter: u32,
    roles: []Role,
    emojis: []Emoji,
    features: [][]const u8,
    mfa_level: u32,
    application_id: ?Snowflake = null,
    system_channel_id: ?Snowflake = null,
    system_channel_flags: u32,
    rules_channel_id: ?Snowflake = null,
    max_presences: ?u32 = null,
    max_members: ?u32 = null,
    vanity_url_code: ?[]const u8 = null,
    description: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    premium_tier: u32,
    premium_subscription_count: ?u32 = null,
    preferred_locale: []const u8,
    public_updates_channel_id: ?Snowflake = null,
    max_video_channel_users: ?u32 = null,
    approximate_member_count: ?u32 = null,
    approximate_presence_count: ?u32 = null,
    welcome_screen: ?WelcomeScreen = null,
    nsfw_level: u32,
    stickers: ?[]Sticker = null,
    premium_progress_bar_enabled: bool,
    channels: ?[]Channel = null,
    members: ?[]GuildMember = null,
    // Fluxer固有フィールド
    disabled_operations: ?u64 = null,
    message_history_cutoff: ?[]const u8 = null,
    splash_card_alignment: ?u32 = null,
};

pub const Channel = struct {
    id: Snowflake,
    type: ChannelType,
    guild_id: ?Snowflake = null,
    position: ?i32 = null,
    name: ?[]const u8 = null,
    topic: ?[]const u8 = null,
    nsfw: ?bool = null,
    last_message_id: ?Snowflake = null,
    bitrate: ?u32 = null,
    user_limit: ?u32 = null,
    rate_limit_per_user: ?u32 = null,
    recipients: ?[]User = null,
    icon: ?[]const u8 = null,
    owner_id: ?Snowflake = null,
    application_id: ?Snowflake = null,
    parent_id: ?Snowflake = null,
    last_pin_timestamp: ?[]const u8 = null,
    permission_overwrites: ?[]PermissionOverwrite = null,
    // Fluxer固有フィールド
    url: ?[]const u8 = null,
};

pub const PermissionOverwrite = struct {
    id: Snowflake,
    type: PermissionOverwriteType,
    allow: Permissions,
    deny: Permissions,
};

pub const PermissionOverwriteType = enum(u8) {
    Role = 0,
    Member = 1,
};

pub const Message = struct {
    id: Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    author: User,
    content: []const u8,
    timestamp: []const u8,
    edited_timestamp: ?[]const u8 = null,
    tts: bool,
    mention_everyone: bool,
    mentions: []User,
    mention_roles: []Snowflake,
    attachments: []Attachment,
    embeds: []Embed,
    reactions: ?[]Reaction = null,
    pinned: bool,
    type: MessageType,
    flags: ?u64 = null,
    // Fluxer固有フィールド
    message_snapshots: ?[]MessageSnapshot = null,
    call: ?CallInfo = null,
};

pub const MessageSnapshot = struct {
    message_id: Snowflake,
    channel_id: Snowflake,
    guild_id: ?Snowflake = null,
    content: []const u8,
    created_at: []const u8,
};

pub const CallInfo = struct {
    participants: []Snowflake,
    ended_timestamp: ?[]const u8 = null,
};

pub const MessageFlags = struct {
    pub const Crossposted = 1;
    pub const IsCrosspost = 1 << 1;
    pub const SuppressEmbeds = 1 << 2;
    pub const SourceMessageDeleted = 1 << 3;
    pub const Urgent = 1 << 4;
    pub const HasThread = 1 << 5;
    pub const Ephemeral = 1 << 6;
    pub const Loading = 1 << 7;
    pub const FailedToMentionSomeRolesInThread = 1 << 8;
    pub const SuppressNotifications = 1 << 12;
    // Fluxer固有
    pub const VoiceMessage = 1 << 13;
    pub const CompactAttachments = 1 << 14;
};

pub const GuildMember = struct {
    user: ?User = null,
    nick: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    roles: []Snowflake,
    joined_at: []const u8,
    premium_since: ?[]const u8 = null,
    deaf: bool,
    mute: bool,
    flags: ?u64 = null,
    pending: ?bool = null,
    permissions: ?[]const u8 = null,
    communication_disabled_until: ?[]const u8 = null,
    // Fluxer固有フィールド
    profile_flags: ?u64 = null,
    hoist_position: ?u32 = null,
    guild_id: ?Snowflake = null,
};

pub const Role = struct {
    id: Snowflake,
    name: []const u8,
    color: u32,
    hoist: bool,
    icon: ?[]const u8 = null,
    unicode_emoji: ?[]const u8 = null,
    position: i32,
    permissions: Permissions,
    managed: bool,
    mentionable: bool,
    tags: ?RoleTags = null,
};

pub const RoleTags = struct {
    bot_id: ?Snowflake = null,
    integration_id: ?Snowflake = null,
    premium_subscriber: ?bool = null,
};

pub const Embed = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    url: ?[]const u8 = null,
    color: ?u32 = null,
    fields: ?[]EmbedField = null,
};

pub const EmbedField = struct {
    name: []const u8,
    value: []const u8,
    @"inline": bool = false,
};

pub const Attachment = struct {
    id: Snowflake,
    filename: []const u8,
    description: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    size: u64,
    url: []const u8,
    proxy_url: []const u8,
    height: ?u32 = null,
    width: ?u32 = null,
    ephemeral: ?bool = null,
};

pub const Reaction = struct {
    count: u32,
    me: bool,
    emoji: ReactionEmoji,
};

pub const ReactionEmoji = struct {
    id: ?Snowflake = null,
    name: ?[]const u8 = null,
};

pub const Emoji = struct {
    id: ?Snowflake = null,
    name: ?[]const u8 = null,
    roles: ?[]Snowflake = null,
    user: ?User = null,
    require_colons: ?bool = null,
    managed: ?bool = null,
    animated: ?bool = null,
    available: ?bool = null,
};

pub const Sticker = struct {
    id: Snowflake,
    pack_id: ?Snowflake = null,
    name: []const u8,
    description: ?[]const u8 = null,
    tags: []const u8,
    type: u32,
    format_type: u32,
    available: ?bool = null,
    guild_id: ?Snowflake = null,
    user: ?User = null,
    sort_value: ?u32 = null,
};

pub const WelcomeScreen = struct {
    description: ?[]const u8 = null,
    welcome_channels: []WelcomeScreenChannel,
};

pub const WelcomeScreenChannel = struct {
    channel_id: Snowflake,
    description: []const u8,
    emoji_id: ?Snowflake = null,
    emoji_name: ?[]const u8 = null,
};
```

## 列挙型 (Enums)

```zig
pub const ChannelType = enum(u16) {
    GuildText = 0,
    DM = 1,
    GuildVoice = 2,
    GroupDM = 3,
    GuildCategory = 4,
    GuildAnnouncement = 5,
    GuildStore = 6,
    GuildAnnouncementThread = 10,
    GuildPublicThread = 11,
    GuildPrivateThread = 12,
    GuildStageVoice = 13,
    GuildDirectory = 14,
    GuildForum = 15,
    // Fluxer固有
    Link = 998,
};

pub const MessageType = enum(u8) {
    Default = 0,
    RecipientAdd = 1,
    RecipientRemove = 2,
    Call = 3,
    ChannelNameChange = 4,
    ChannelIconChange = 5,
    ChannelPinnedMessage = 6,
    UserJoin = 7,
    GuildBoost = 8,
    GuildBoostTier1 = 9,
    GuildBoostTier2 = 10,
    GuildBoostTier3 = 11,
    ChannelFollowAdd = 12,
    GuildDiscoveryDisqualified = 14,
    GuildDiscoveryRequalified = 15,
    GuildDiscoveryGracePeriodInitialWarning = 16,
    GuildDiscoveryGracePeriodFinalWarning = 17,
    ThreadCreated = 18,
    Reply = 19,
    ChatInputCommand = 20,
    ThreadStarterMessage = 21,
    GuildInvitationReminder = 22,
    ContextMenuCommand = 23,
};

pub const GuildFeature = enum {
    ANIMATED_ICON,
    BANNER,
    COMMERCE,
    COMMUNITY,
    DISCOVERABLE,
    FEATURABLE,
    INVITE_SPLASH,
    MEMBER_VERIFICATION_GATE_ENABLED,
    NEWS,
    PARTNERED,
    PREVIEW_ENABLED,
    VANITY_URL,
    VERIFIED,
    VIP_REGIONS,
    WELCOME_SCREEN_ENABLED,
    TICKETED_EVENTS_ENABLED,
    MONETIZATION_ENABLED,
    MORE_STICKERS,
    THREE_DAY_THREAD_ARCHIVE,
    SEVEN_DAY_THREAD_ARCHIVE,
    PRIVATE_THREADS,
    ROLE_ICONS,
    ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE,
    ROLE_SUBSCRIPTIONS_ENABLED,
    // Fluxer固有
    VISIONARY,
    OPERATOR,
};

pub const GatewayOpcode = enum(u8) {
    dispatch = 0,
    heartbeat = 1,
    identify = 2,
    presence_update = 3,
    voice_state_update = 4,
    voice_server_ping = 5,
    resume_session = 6,
    reconnect = 7,
    request_guild_members = 8,
    invalid_session = 9,
    hello = 10,
    heartbeat_ack = 11,
    /// Fluxer固有: ゲートウェイメッセージの処理エラー（受信専用）。
    gateway_error = 12,
    /// Fluxer固有: ギルドデータのレイジーロード（送信専用）。
    lazy_request = 14,
};

pub const Intents = struct {
    value: u64,

    pub fn init() Intents;
    pub fn guilds() Intents;
    pub fn guildMembers() Intents;
    pub fn guildBans() Intents;
    pub fn guildEmojis() Intents;
    pub fn guildIntegrations() Intents;
    pub fn guildWebhooks() Intents;
    pub fn guildInvites() Intents;
    pub fn guildVoiceStates() Intents;
    pub fn guildPresences() Intents;
    pub fn guildMessages() Intents;
    pub fn guildMessageReactions() Intents;
    pub fn guildMessageTyping() Intents;
    pub fn directMessages() Intents;
    pub fn directMessageReactions() Intents;
    pub fn directMessageTyping() Intents;
    pub fn messageContent() Intents;
    pub fn guildScheduledEvents() Intents;
    pub fn autoModerationConfiguration() Intents;
    pub fn autoModerationExecution() Intents;
    pub fn combine(self: Intents, other: Intents) Intents;
    pub fn has(self: Intents, other: Intents) bool;
};

pub const Permissions = packed struct(u64) {
    // ... 標準的な権限ビット
};
```

## ゲートウェイ (Gateway)

### 接続URL (Connection URL)

デフォルトのゲートウェイWebSocket URLは、fluxer API仕様に従います。

```
wss://gateway.fluxer.app/?v=1&encoding=json
```

クエリパラメータ:
- `v=1` — APIバージョン（fluxerでは必須）。
- `encoding=json` — 実質的にJSONのみサポート。

### オペコード (Opcodes)

| オペコード | 名前 | 方向 | 説明 |
|--------|------|-----------|-------------|
| 0 | `DISPATCH` | 受信 | ゲートウェイイベントのディスパッチ |
| 1 | `HEARTBEAT` | 送受信 | キープアライブピング |
| 2 | `IDENTIFY` | 送信 | 認証とセッション開始 |
| 3 | `PRESENCE_UPDATE` | 送信 | プレゼンス（状態）の更新 |
| 4 | `VOICE_STATE_UPDATE` | 送信 | ボイスチャンネルの参加/移動/退出 |
| 5 | `VOICE_SERVER_PING` | 送信 | ボイスサーバーへのping |
| 6 | `RESUME_SESSION` | 送信 | 切断後の再開 |
| 7 | `RECONNECT` | 受信 | サーバーからの再接続要求 |
| 8 | `REQUEST_GUILD_MEMBERS` | 送信 | メンバーリストの要求 |
| 9 | `INVALID_SESSION` | 受信 | セッション無効；再認証が必要 |
| 10 | `HELLO` | 受信 | ハートビート間隔付きの初期ハンドシェイク |
| 11 | `HEARTBEAT_ACK` | 受信 | ハートビートの確認応答 |
| 12 | `GATEWAY_ERROR` | 受信 | ゲートウェイメッセージ処理エラー（fluxer固有） |
| 14 | `LAZY_REQUEST` | 送信 | ギルドデータのレイジーロード（fluxer固有） |

### ハートビート (Heartbeat)

- **間隔:** `41250` ms（fluxer仕様）。
- **タイムアウト:** `45000` ms（fluxer仕様）。
- サーバーは `HELLO`（op 10）でハートビート間隔を送信します。
- クライアントは定期的に `HEARTBEAT`（op 1）を送信し、`HEARTBEAT_ACK`（op 11）を待つ必要があります。

## ゲートウェイペイロードエンベロープ (Gateway Payload Envelope)

```zig
pub const GatewayPayload = struct {
    op: GatewayOpcode,
    d: ?std.json.Value = null,
    s: ?u64 = null,
    t: ?[]const u8 = null,
};

/// GATEWAY_ERROR (op 12) のペイロード。
pub const GatewayErrorPayload = struct {
    code: i32,
    message: []const u8,
};

/// LAZY_REQUEST (op 14) のペイロード。
pub const LazyRequestPayload = struct {
    guild_id: u64,
    channel_id: u64,
    typing: bool = false,
    threads: bool = false,
    activities: bool = false,
};

pub const IdentifyProperties = struct {
    os: []const u8,
    browser: []const u8,
    device: []const u8,
};

pub const IdentifyBody = struct {
    token: []const u8,
    properties: IdentifyProperties,
    intents: u32,
    shard: ?[2]u16 = null,
    presence: ?PresenceUpdate = null,
};

pub const ResumeBody = struct {
    token: []const u8,
    session_id: []const u8,
    seq: u64,
};

pub const PresenceUpdate = struct {
    since: ?u64,
    activities: []Activity,
    status: Status,
    afk: bool,
};

pub const Status = enum {
    online,
    dnd,
    idle,
    invisible,
    offline,
};

pub const Activity = struct {
    name: []const u8,
    type: ActivityType,
    url: ?[]const u8 = null,
};

pub const ActivityType = enum(u8) {
    game = 0,
    streaming = 1,
    listening = 2,
    watching = 3,
    custom = 4,
    competing = 5,
};
```

## キャッシュインターフェイス (Cache Interface)

```zig
pub const Cache = struct {
    pub fn init(allocator: std.mem.Allocator, options: CacheOptions) !Cache;
    pub fn deinit(self: *Cache) void;

    pub fn getUser(self: *Cache, id: Snowflake) ?User;
    pub fn upsertUser(self: *Cache, user: User) !void;
    pub fn removeUser(self: *Cache, id: Snowflake) void;

    pub fn getGuild(self: *Cache, id: Snowflake) ?Guild;
    pub fn upsertGuild(self: *Cache, guild: Guild) !void;
    pub fn removeGuild(self: *Cache, id: Snowflake) void;

    pub fn getChannel(self: *Cache, id: Snowflake) ?Channel;
    pub fn upsertChannel(self: *Cache, channel: Channel) !void;
    pub fn removeChannel(self: *Cache, id: Snowflake) void;

    pub fn getMessage(self: *Cache, id: Snowflake) ?Message;
    pub fn upsertMessage(self: *Cache, message: Message) !void;
    pub fn removeMessage(self: *Cache, id: Snowflake) void;

    pub fn getMember(self: *Cache, guild_id: Snowflake, user_id: Snowflake) ?GuildMember;
    pub fn upsertMember(self: *Cache, guild_id: Snowflake, member: GuildMember) !void;
    pub fn removeMember(self: *Cache, guild_id: Snowflake, user_id: Snowflake) void;
};

pub const CacheOptions = struct {
    enabled: bool = true,
    message_limit: u32 = 100,
    disabled_events: ?[]const []const u8 = null,
};
```

## レートリミッターインターフェイス (Rate Limiter Interface)

```zig
pub const RateLimiter = struct {
    pub fn init(allocator: std.mem.Allocator) RateLimiter;
    pub fn deinit(self: *RateLimiter) void;

    /// レート制限を考慮してリクエストを送信します。許可されるまでブロック（yield）します。
    pub fn submit(
        self: *RateLimiter,
        route: []const u8,
        execute_fn: *const fn () anyerror!Response,
    ) !Response;

    /// 指定ルートのバケット状態を返します。不明な場合は null です。
    pub fn bucketState(self: *RateLimiter, route: []const u8) ?BucketState;

    /// グローバルレート制限の残り回数を返します。
    pub fn globalLimitRemaining(self: *RateLimiter) u32;

    /// HTTPレスポンスからバケットとグローバル制限を更新します。
    pub fn updateFromResponse(self: *RateLimiter, route: []const u8, response: Response) void;
};

pub const BucketState = struct {
    limit: u32,
    remaining: u32,
    reset: i64,
    reset_after: f64,
};
```

## エラー型 (Error Types)

```zig
/// REST API 操作用のエラーセット。
pub const RestError = error{
    HttpError,
    JsonError,
    RateLimited,
    Unauthorized,
    Forbidden,
    NotFound,
    ServerError,
    UnknownError,
};

/// ゲートウェイ操作用のエラーセット。
pub const GatewayError = error{
    ConnectionClosed,
    GatewayProtocolError,
    InvalidSession,
    UnknownEvent,
    MaxReconnectAttemptsExceeded,
    InvalidWebSocketAccept,
    MissingWebSocketAccept,
    InvalidOpcode,
};

/// Fluxer API からのエラーレスポンスを表します。
pub const FluxerAPIError = struct {
    code: i32,
    message: []const u8,
    errors: ?std.json.Value,

    pub fn deinit(self: *FluxerAPIError, allocator: std.mem.Allocator) void;
};

/// ゲートウェイのクローズコードを表します。
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    no_status_received = 1005,
    abnormal_closure = 1006,
    invalid_frame_payload = 1007,
    policy_violation = 1008,
    message_too_big = 1009,
    mandatory_extension = 1010,
    internal_server_error = 1011,
    service_restart = 1012,
    try_again_later = 1013,
    bad_gateway = 1014,
    tls_handshake = 1015,
    // Fluxer固有のクローズコード
    authentication_failed = 4004,
    already_authenticated = 4005,
    invalid_seq = 4007,
    rate_limited = 4008,
    session_timed_out = 4009,
    invalid_shard = 4010,
    sharding_required = 4011,
    invalid_api_version = 4012,
    invalid_intents = 4013,
    disallowed_intents = 4014,
};
```

## 高度な利用: シャードマネージャーの直接使用 (Advanced: Shard Manager Direct Use)

```zig
pub const ShardManager = struct {
    pub fn init(allocator: std.mem.Allocator, num_shards: u32, token: []const u8, intents: u64) !ShardManager;
    pub fn deinit(self: *ShardManager) void;

    pub fn startAll(self: *ShardManager) !void;
    pub fn stopAll(self: *ShardManager) void;

    pub fn getShard(self: *ShardManager, guild_id: Snowflake) *Shard;
    pub fn shardStatus(self: ShardManager) ![]ShardStatus;
};

pub const Shard = struct {
    id: u16,
    total_shards: u16,
    status: ShardStatus,
    token: []const u8,
    intents: u32,
    reconnect_attempts: u32,
    max_reconnect_attempts: u32,
    reconnect_delay_ms: u64,
    session_id: ?[]const u8,
    sequence: ?u64,

    pub fn init(allocator: std.mem.Allocator, id: u16, total_shards: u16, token: []const u8) Shard;
    pub fn deinit(self: *Shard) void;

    pub fn connect(self: *Shard) !void;
    pub fn disconnect(self: *Shard) void;
    pub fn sendRaw(self: *Shard, text: []const u8) !void;
    pub fn handlePayload(self: *Shard, op: GatewayOpcode, data: ?std.json.Value) !void;
    pub fn shouldReconnect(self: Shard) bool;
    pub fn isTimedOut(self: Shard) bool;
    pub fn processCloseCode(self: *Shard, close_code: ?u16) !void;
    pub fn tryReconnect(self: *Shard) !void;
    pub fn resetReconnectState(self: *Shard) void;
    pub fn sendIdentify(self: *Shard) IdentifyBody;
    pub fn sendResume(self: *Shard) !ResumeBody;
};

pub const ShardStatus = enum {
    disconnected,
    connecting,
    identifying,
    ready,
    resuming,
};
```

## 生のHTTP API (Raw HTTP API)

高度なユースケース向けの生のHTTPアクセス。

```zig
pub const HeaderMap = std.StringArrayHashMap([]const u8);

pub const RequestOptions = struct {
    headers: ?HeaderMap = null,
    body: ?[]const u8 = null,
    query: ?[]const u8 = null,
};

pub const Response = struct {
    status: std.http.Status,
    headers: HeaderMap,
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void;
};
```

## 生のゲートウェイAPI (Raw Gateway API)

生のゲートウェイペイロードアクセスと手動シャード制御。

```zig
pub const GatewayPayload = struct {
    op: GatewayOpcode,
    d: ?std.json.Value = null,
    s: ?u64 = null,
    t: ?[]const u8 = null,
};

// シャードの手動操作
pub const Shard = struct {
    pub fn connect(self: *Shard) !void;
    pub fn disconnect(self: *Shard) void;
    pub fn sendRaw(self: *Shard, text: []const u8) !void;
};
```

## WebSocketフレームAPI (WebSocket Frame API)

低レベルのWebSocketフレーム解析とシリアライズ。

```zig
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

pub const Frame = struct {
    fin: bool,
    rsv1: bool,
    rsv2: bool,
    rsv3: bool,
    opcode: Opcode,
    masked: bool,
    payload: []const u8,
    allocator: std.mem.Allocator,
    owned: bool,

    pub fn deinit(self: *Frame) void;
};

/// `reader` から単一のWebSocketフレームを解析します。
/// `buffer` は小さなペイロード用に使用され、大きなペイロードは `allocator` でヒープ割り当てされます。
/// 呼び出し側は `frame.deinit()` を呼び出して割り当てられたペイロードを解放する必要があります。
pub fn parseFrame(
    reader: std.io.AnyReader,
    allocator: std.mem.Allocator,
    buffer: []u8,
) !Frame;

/// フレームを `writer` にシリアライズします。
/// クライアント→サーバーでは常に FIN=1、MASK=1 を設定し、ランダムなマスクキーを生成します。
pub fn serializeFrame(
    writer: std.io.AnyWriter,
    opcode: Opcode,
    payload: []const u8,
) !void;

/// テキストフレームをシリアライズする便利関数。
pub fn serializeText(writer: std.io.AnyWriter, text: []const u8) !void;

/// オプションのステータスコードと理由付きでクローズフレームをシリアライズします。
/// 理由は123バイトを超えてはならず、合計ペイロードは125以下である必要があります。
pub fn serializeClose(
    writer: std.io.AnyWriter,
    code: ?u16,
    reason: ?[]const u8,
) !void;
```

## リクエストビルダーAPI (RequestBuilder API)

HTTPリクエストを構築するための流暢API（Fluent API）。

```zig
pub const RequestBuilder = struct {
    pub fn init(allocator: std.mem.Allocator) RequestBuilder;
    pub fn setMethod(self: *RequestBuilder, m: std.http.Method) *RequestBuilder;
    pub fn setPath(self: *RequestBuilder, p: []const u8) *RequestBuilder;
    pub fn header(self: *RequestBuilder, k: []const u8, v: []const u8) *RequestBuilder;
    pub fn bodyJson(self: *RequestBuilder, value: anytype) !*RequestBuilder;
    pub fn queryParam(self: *RequestBuilder, k: []const u8, v: []const u8) *RequestBuilder;
    pub fn build(self: *RequestBuilder) void;
    pub fn deinit(self: *RequestBuilder) void;
};
```

## 低レベルイベントシステム (Low-Level Event System)

高レベルのDiscordイベントに加えて、以下の低レベルイベントが発行されます。

- `onRawGatewayPayload`: すべての生の受信ゲートウェイペイロードに対して発火
- `onRawREST`: すべての生のRESTレスポンスに対して発火

これらをリッスンすることで、パース前のプロトコルレベルトラフィックを監視できます。

## 設計思想 (Design Philosophy)

- すべての高レベルAPIは低レベルAPIのラッパーです。
- 利用者は常に生のHTTPおよびWebSocketトラフィックにアクセスできます。
- 内部構造（レートリミッターバケット、シャード状態など）は観測可能です。
- デフォルトは利便性を最適化していますが、高度な利用者はすべてをオーバーライドできます。