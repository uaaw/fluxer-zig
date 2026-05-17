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

### 1. build.zig.zon に依存を追加

```zig
.{
    .name = "your_project",
    .version = "0.0.0",
    .dependencies = .{
        .fluxer = .{
            .url = "https://github.com/your-org/fluxer-zig/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "...",
        },
    },
}
```

ローカルパスを使用する場合:

```zig
.{
    .name = "your_project",
    .version = "0.0.0",
    .dependencies = .{
        .fluxer = .{
            .path = "path/to/fluxer-zig",
        },
    },
}
```

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
        .onRawGatewayPayload = noopRawGateway,
        .onRawREST = noopRawREST,
    };

    pub fn onReady(ptr: *anyopaque, ready: fluxer.gateway.ReadyPayload) void {
        _ = ptr;
        std.log.info("Ready: {s}", .{ready.user.username});
    }

    pub fn onMessageCreate(ptr: *anyopaque, message: fluxer.models.Message) void {
        _ = ptr;
        std.log.info("{s}: {s}", .{message.author.username, message.content});
    }

    fn noopMessage(ptr: *anyopaque, payload: fluxer.models.Message) void { _ = ptr; _ = payload; }
    fn noopMessageDelete(ptr: *anyopaque, payload: fluxer.gateway.MessageDeletePayload) void { _ = ptr; _ = payload; }
    fn noopGuild(ptr: *anyopaque, payload: fluxer.models.Guild) void { _ = ptr; _ = payload; }
    fn noopGuildDelete(ptr: *anyopaque, payload: fluxer.gateway.GuildDeletePayload) void { _ = ptr; _ = payload; }
    fn noopChannel(ptr: *anyopaque, payload: fluxer.models.Channel) void { _ = ptr; _ = payload; }
    fn noopChannelDelete(ptr: *anyopaque, payload: fluxer.gateway.ChannelDeletePayload) void { _ = ptr; _ = payload; }
    fn noopGuildMember(ptr: *anyopaque, payload: fluxer.models.GuildMember) void { _ = ptr; _ = payload; }
    fn noopGuildMemberRemove(ptr: *anyopaque, payload: fluxer.gateway.GuildMemberRemovePayload) void { _ = ptr; _ = payload; }
    fn noopRawGateway(ptr: *anyopaque, payload: fluxer.gateway.GatewayPayload) void { _ = ptr; _ = payload; }
    fn noopRawREST(ptr: *anyopaque, response: fluxer.rest.Response) void { _ = ptr; _ = response; }
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

## 既知の制限事項

- **Gateway接続のTLS（wss://）は未対応です。** 現在の `Shard.connect()` は平文TCP（ポート443）を使用しており、TLS必須のエンドポイントでは拒否されます。今後のリリースで `std.crypto.tls.Client` または外部TLSライブラリを使用したTLS対応を予定しています。

## 貢献方法

バグ報告、機能提案、Pull Requestを歓迎します。詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT](LICENSE)

## 謝辞

このライブラリを作る際に参考にさせていただいたものです。
この場を借りて感謝申し上げます。

discord-nodejsライブラリ
[eris](https://github.com/abalabahaha/eris.git)