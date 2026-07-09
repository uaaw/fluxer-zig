# fluxer-zig

[English README](README.md)

[fluxer](https://fluxer.app) チャットアプリケーションとBotを構築するための、Zig言語の低レベルライブラリです。
[eris](https://github.com/abalabahaha/eris)を参考に、高レベルの利便性と低レベルの細かい制御の両方を提供します。

## 特徴

- REST APIクライアント（生のHTTPリクエストにも対応）
- WebSocket Gatewayクライアント（自動再接続対応）
- ルート別レートリミッター（状態監視可能）
- メモリキャッシュ（設定可能）
- 型付きイベントディスパッチャ（生ペイロードフォールバック）
- マルチシャード対応（手動制御可能）
- Fluxer API v1互換（ベースURL: `https://api.fluxer.app/v1`）
- 認証方式: Session / Bearer / Bot / Admin
- 独自WebSocketフレーム実装（RFC 6455準拠）
- 外部依存ゼロ（Zig標準ライブラリのみ使用）

## インストール

### 1. パス依存（推奨）

`build.zig.zon` にローカルパス依存を追加します:

```zig
.{
    .name = "your_project",
    .version = "0.0.0",
    .dependencies = .{
        .fluxer = .{
            .path = "path/to/fluxer-zig",
        },
    },
    .paths = .{""},
}
```

### リモート依存（任意）

リリースタグ公開後は、`zig fetch` で正しいハッシュを記録させてください（手書きの偽ハッシュは使わないでください）:

```bash
zig fetch --save https://github.com/uaaw/fluxer-zig/archive/refs/tags/v0.0.1.tar.gz
```

タグがまだない場合は、リポジトリをクローンして上記のパス依存を使ってください。

### 2. build.zig でモジュールをインポート

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "your_bot",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const fluxer_dep = b.dependency("fluxer", .{});
    exe.root_module.addImport("fluxer", fluxer_dep.module("fluxer"));

    b.installArtifact(exe);
}
```

## クイックスタート

ローカル実験では環境変数 `FLUXER_BOT_TOKEN` からBotトークンを読み込んでください（ハードコードやコミットは禁止）。Fluxer で今すぐ使える **プレフィックスコマンド** Bot の例（`!ping` / `!help`）は [`example/basic_bot.zig`](example/basic_bot.zig) を参照してください。

```zig
const std = @import("std");
const fluxer = @import("fluxer");

// イベントハンドラの定義
const Handler = struct {
    pub const VTable = fluxer.gateway.EventHandler.VTable{
        .onReady = onReady,
        .onMessageCreate = onMessageCreate,
        .onMessageUpdate = noopMessage,
        .onMessageDelete = noopMessageDelete,
        .onGuildCreate = noopGuild,
        .onGuildUpdate = noopGuild,
        .onGuildDelete = noopGuildDelete,
        .onChannelCreate = noopChannel,
        .onChannelUpdate = noopChannel,
        .onChannelDelete = noopChannelDelete,
        .onGuildMemberAdd = noopGuildMember,
        .onGuildMemberUpdate = noopGuildMember,
        .onGuildMemberRemove = noopGuildMemberRemove,
        .onMessageReactionAdd = noopReactionAdd,
        .onMessageReactionRemove = noopReactionRemove,
        .onMessageReactionRemoveAll = noopReactionRemoveAll,
        .onMessageReactionRemoveEmoji = noopReactionRemoveEmoji,
        .onMessageDeleteBulk = noopMsgDeleteBulk,
        .onGuildRoleCreate = noopRoleCreate,
        .onGuildRoleUpdate = noopRoleUpdate,
        .onGuildRoleDelete = noopRoleDelete,
        .onGuildBanAdd = noopBanAdd,
        .onGuildBanRemove = noopBanRemove,
        .onTypingStart = noopTypingStart,
        .onWebhooksUpdate = noopWebhooksUpdate,
        .onInviteCreate = noopInviteCreate,
        .onInviteDelete = noopInviteDelete,
        .onVoiceStateUpdate = noopVoiceStateUpdate,
        .onVoiceServerUpdate = noopVoiceServerUpdate,
        .onPresenceUpdate = noopPresenceUpdate,
        .onThreadCreate = noopThreadCreate,
        .onThreadUpdate = noopThreadUpdate,
        .onThreadDelete = noopThreadDelete,
        .onThreadListSync = noopThreadListSync,
        .onThreadMemberUpdate = noopThreadMemberUpdate,
        .onThreadMembersUpdate = noopThreadMembersUpdate,
        .onUserUpdate = noopUserUpdate,
        .onChannelPinsUpdate = noopPinsUpdate,
        .onGuildEmojisUpdate = noopEmojisUpdate,
        .onGuildStickersUpdate = noopStickersUpdate,
        .onGuildRoleUpdateBulk = noopRoleUpdateBulk,
        .onChannelUpdateBulk = noopChannelUpdateBulk,
        .onRawGatewayPayload = noopRawGateway,
        .onRawREST = noopRawREST,
        .onInteractionCreate = noopInteraction,
    };

    pub fn onReady(ptr: *anyopaque, ready: fluxer.gateway.ReadyPayload) void {
        _ = ptr;
        std.log.info("Ready: {s}", .{ready.user.username});
    }

    pub fn onMessageCreate(ptr: *anyopaque, message: fluxer.models.Message) void {
        _ = ptr;
        std.log.info("{s}: {s}", .{ message.author.username, message.content });
    }

    fn noopMessage(ptr: *anyopaque, payload: fluxer.models.Message) void {
        _ = ptr;
        _ = payload;
    }
    fn noopMessageDelete(ptr: *anyopaque, payload: fluxer.gateway.MessageDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopGuild(ptr: *anyopaque, payload: fluxer.models.Guild) void {
        _ = ptr;
        _ = payload;
    }
    fn noopGuildDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopChannel(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopChannelDelete(ptr: *anyopaque, payload: fluxer.gateway.ChannelDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopGuildMember(ptr: *anyopaque, payload: fluxer.models.GuildMember) void {
        _ = ptr;
        _ = payload;
    }
    fn noopGuildMemberRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildMemberRemovePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionAdd(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionAddPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemove(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemovePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemoveAll(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveAllPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopReactionRemoveEmoji(ptr: *anyopaque, payload: fluxer.gateway.MessageReactionRemoveEmojiPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopMsgDeleteBulk(ptr: *anyopaque, payload: fluxer.gateway.MessageDeleteBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleCreate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleCreatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopBanAdd(ptr: *anyopaque, payload: fluxer.gateway.GuildBanAddPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopBanRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildBanRemovePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopTypingStart(ptr: *anyopaque, payload: fluxer.gateway.TypingStartPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopWebhooksUpdate(ptr: *anyopaque, payload: fluxer.gateway.WebhooksUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopInviteCreate(ptr: *anyopaque, payload: fluxer.gateway.InviteCreatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopInviteDelete(ptr: *anyopaque, payload: fluxer.gateway.InviteDeletePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopVoiceStateUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceStateUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopVoiceServerUpdate(ptr: *anyopaque, payload: fluxer.gateway.VoiceServerUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopPresenceUpdate(ptr: *anyopaque, payload: fluxer.gateway.PresenceUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadCreate(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadUpdate(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadDelete(ptr: *anyopaque, payload: fluxer.models.Channel) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadListSync(ptr: *anyopaque, payload: fluxer.gateway.ThreadListSyncPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadMemberUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMember) void {
        _ = ptr;
        _ = payload;
    }
    fn noopThreadMembersUpdate(ptr: *anyopaque, payload: fluxer.gateway.ThreadMembersUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopUserUpdate(ptr: *anyopaque, payload: fluxer.gateway.UserUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopPinsUpdate(ptr: *anyopaque, payload: fluxer.gateway.ChannelPinsUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopEmojisUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildEmojisUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopStickersUpdate(ptr: *anyopaque, payload: fluxer.gateway.GuildStickersUpdatePayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRoleUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.GuildRoleUpdateBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopChannelUpdateBulk(ptr: *anyopaque, payload: fluxer.gateway.ChannelUpdateBulkPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRawGateway(ptr: *anyopaque, payload: fluxer.gateway.GatewayPayload) void {
        _ = ptr;
        _ = payload;
    }
    fn noopRawREST(ptr: *anyopaque, response: fluxer.rest.Response) void {
        _ = ptr;
        _ = response;
    }
    fn noopInteraction(ptr: *anyopaque, payload: fluxer.models.Interaction) void {
        _ = ptr;
        _ = payload;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // クライアント初期化
    var client = try fluxer.Client.init(allocator, .{
        .token = "YOUR_BOT_TOKEN",
        .auth_type = .Bot,
        .intents = fluxer.gateway.Intents.guildMessages().combine(fluxer.gateway.Intents.guilds()).value,
    });
    defer client.deinit();

    // イベントハンドラ登録
    var handler = Handler{};
    const eh = fluxer.gateway.EventHandler{ .ptr = &handler, .vtable = &Handler.VTable };
    try client.connect(eh, &handler);

    // 60秒間実行
    std.time.sleep(std.time.ns_per_s * 60);
    client.disconnect();
}
```

## 低レベルAPI

生のHTTPリクエストとWebSocketアクセスの例:

```zig
// 生のHTTPリクエスト
var response = try client.request(.GET, "/users/@me", .{});
defer response.deinit();
std.log.info("Status: {}", .{response.status});

// Shardの手動制御
var sm = try fluxer.gateway.ShardManager.init(
    allocator,
    2,
    "TOKEN",
    fluxer.gateway.Intents.guildMessages().value,
);
defer sm.deinit();
try sm.startAll();
defer sm.stopAll();
```

## アーキテクチャ

ライブラリのモジュール構成:

- `client` - 高レベルClient (`fluxer.Client`)。REST、Gateway、Cacheを統合し、Bot開発を簡素化します。
- `rest` - HTTPクライアント (`fluxer.rest.HttpClient`)、レートリミッター (`fluxer.rest.RateLimiter`)、リクエストビルダー (`fluxer.rest.RequestBuilder`)、レスポンス (`fluxer.rest.Response`)。
- `gateway` - WebSocket Gateway (`fluxer.gateway.Shard`)、ShardManager (`fluxer.gateway.ShardManager`)、イベントディスパッチャ (`fluxer.gateway.EventDispatcher`)。
- `websocket` - RFC 6455フレームパーサー/シリアライザー (`fluxer.websocket.parseFrame`, `fluxer.websocket.serializeFrame` など)。
- `models` - APIデータモデル（`fluxer.models.User`, `fluxer.models.Guild`, `fluxer.models.Channel`, `fluxer.models.Message`, `fluxer.models.GuildMember`, `fluxer.models.Snowflake` 等）。
- `cache` - メモリキャッシュ (`fluxer.cache.Cache`)。User / Guild / Channel / Message / GuildMember のスレッドセーフなキャッシュを提供します。

## プロジェクト状況

> **バージョン 0.0.1** - コアREST/Gateway機能を含む初回リリース。
>
> このライブラリは初期開発段階です。バージョン間でAPIが変更される可能性があります。
> 変更履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## Fluxer ライブ状況

実Botトークンでの検証結果（ローカル実験のみ）:

| 領域 | 状況 |
|------|------|
| Gateway（Ready + heartbeat） | 動作する |
| REST（`createMessage` など） | 対応ルートは動作する |
| アプリケーションスラッシュコマンド（`/applications/{id}/commands`） | **Fluxer側では未実装**（公式ドキュメントどおり。`createGlobalCommand` は 404） |

**現状おすすめのBotパターン:** スラッシュではなく **プレフィックスコマンド**。`MESSAGE_CREATE` で `{prefix}{command}[ args...]` を解析し（デモの prefix は `"!"`）、Bot作者は無視、`Client.createMessage` で返信。例: `!ping` / `!ping hello` → `pong`、`!help` → 短いヘルプ。[`example/basic_bot.zig`](example/basic_bot.zig) を参照。

ローカル実行時は環境変数でトークンを渡し、コミットしないでください:

```bash
export FLUXER_BOT_TOKEN="your_bot_token_here"
# トークン・秘密情報入り .env・トークンログは絶対にコミットしない
zig build examples
# ビルドした basic_bot バイナリを FLUXER_BOT_TOKEN を設定して実行
```

`why-error/` はローカル用サンドボックス（gitignore済み）で、公開パッケージには含まれません。

## 既知の制限事項

- **Gateway接続のTLS（wss://）に対応しました（ベータ）。** `Shard.connect()` は `std.crypto.tls.Client` を使用し、OSのCAバンドルを読み込んでTLSハンドシェイクを行います。証明書検証はデフォルトで有効です。OSのCAバンドルが読み込めない場合、TLS必須のエンドポイントでは接続に失敗する可能性があります。
- **スラッシュ / アプリケーションコマンドは Fluxer 側でまだ使えません。** `createGlobalCommand` などライブラリ側のヘルパーは Discord 互換ルート向けに用意されていますが、Fluxer が公開していないため、プラットフォーム対応までは **プレフィックスコマンド**（`!ping` など）を `MESSAGE_CREATE` で処理してください。

## 貢献方法

バグ報告、機能提案、Pull Requestを歓迎します。詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## セキュリティ

脆弱性の報告については [SECURITY.md](SECURITY.md) を参照してください。

## ライセンス

[MIT](LICENSE)

## 謝辞

このライブラリを作る際に参考にさせていただいたものです。
この場を借りて感謝申し上げます。

discord-nodejsライブラリ
[eris](https://github.com/abalabahaha/eris.git)
