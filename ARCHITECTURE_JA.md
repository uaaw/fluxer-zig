# アーキテクチャ概要

この文書は、Zig製のFluxerチャットプラットフォームAPIクライアントライブラリ「`fluxer-zig`」の高レベルアーキテクチャ（Architecture Overview）を説明します。

## 設計目標

- Zig 0.13+ を対象とする
- 明示的なアロケータ（allocator）使用によるメモリ安全性
- ノンブロッキングI/Oを伴うスレッドベースの並行処理（Thread-based concurrency）
- WebSocket（Gateway）とREST APIの両方をサポート
- 関心事の明確な分離によるモジュール化設計
- JSONベースの通信

## アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                         User Code                            │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      Client (client.zig)                     │
│  - Gateway + HTTP + Cache を統合する高レベルファサード        │
│  - ユーザー提供ハンドラへのイベントディスパッチ               │
│  - ライフサイクル管理（接続、再接続、シャットダウン）         │
└─────────────────────────────────────────────────────────────┘
             │                      │                  │
             ▼                      ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Gateway          │  │ REST             │  │ Cache            │
│ (gateway/)       │  │ (rest/)          │  │ (cache/)         │
│ - WebSocket      │  │ - REST requests  │  │ - In-memory      │
│   connection     │  │ - Rate limiting  │  │   object store   │
│ - Heartbeat      │  │ - Request/       │  │ - Guilds, users, │
│ - Payload RX/TX  │  │   Response       │  │   channels, msgs │
└──────────────────┘  └──────────────────┘  └──────────────────┘
             │                      │                  │
             ▼                      ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Shard Manager    │  │ Rate Limiter     │  │ Models           │
│ (shard_manager.zig)│ │ (rest/rate_      │  │ (models/*.zig)   │
│ - Shard allocation│  │  limiter.zig)  │  │ - Structs, enums │
│ - Session resume   │  │ - Bucket tracker│  │ - JSON           │
│ - Identify queue   │  │ - Queue + delay │  │   (de)serialize  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
             │                      │
             ▼                      ▼
┌──────────────────┐  ┌──────────────────┐
│ Event Dispatcher │  │ TLS / TCP        │
│ (gateway/event_  │  │ (std.net + TLS)  │
│  dispatcher.zig) │  │ - std.net        │
│ - Parse payload  │  │ - std.crypto.tls │
│ - Route events   │  │ - std.http.Client│
│ - User callbacks │  │                  │
└──────────────────┘  └──────────────────┘
             │
             ▼
┌──────────────────┐
│ WebSocket        │
│ (websocket/)     │
│ - RFC 6455 frame │
│   parser/        │
│   serializer     │
└──────────────────┘
```

## モジュール構成

### 1. client.zig（クライアント）
ライブラリ利用者のための主要なエントリーポイント。Gateway層とHTTP層の上に統一されたインターフェースを提供します。

責務:
- ユーザーから渡されたアロケータ（allocator）の初期化と所有
- インテント（intent: Gatewayイベント購読設定）の構成
- Gateway接続とバックグラウンドタスクの開始/停止
- `sendMessage`、`getGuild` などの高レベルヘルパーの公開
- ユーザー登録ハンドラへのイベントディスパッチ
- オプションのCacheおよびShardManagerインスタンスの所有

### 2. gateway/（ゲートウェイ）
Fluxer GatewayへのWebSocket接続を管理します。

ファイル:
- `gateway/mod.zig` — 公開再エクスポート
- `gateway/shard.zig` — 単一WebSocket接続、受信ループ、再接続ロジック
- `gateway/shard_manager.zig` — 複数シャードのライフサイクル管理
- `gateway/heartbeat.zig` — ハートビート（heartbeat）タイミング、ACK監視、ゾンビ検出
- `gateway/payload.zig` — Gatewayペイロード構造体（オペコード、IDENTIFY、RESUMEなど）
- `gateway/event_dispatcher.zig` — ディスパッチイベントをユーザーハンドラに振り分け、キャッシュと連携
- `gateway/ready_payload.zig` — READYイベントのデータモデル
- `gateway/delete_payloads.zig` — 削除イベントペイロード（MessageDelete、GuildDeleteなど）
- `gateway/intents.zig` — ゲートウェイインテント（Gateway Intent）のビットフラグ
- `gateway/errors.zig` — ゲートウェイ固有のエラーセット（error set）とクローズコード（close code）

責務:
- `websocket/` 経由でWebSocket接続を開設・維持
- ハートビートの送信とハートビートACKの検証
- 送信ペイロードのシリアライズと受信ペイロードのデシリアライズ
- クローズコードの処理と再接続（指数関数的バックオフ付き）
- 解析済みゲートウェイイベントのストリーム公開
- マルチシャードボット向けのシャードマネージャー（Shard Manager）連携

### 3. gateway/shard_manager.zig（シャードマネージャー）
大規模ボット向けに複数のゲートウェイシャードを管理します。

責務:
- 初期化時に指定された固定数のシャードの管理
- シャード単位のゲートウェイタスクの生成と監視
- ギルドIDから対応シャードへの割り当て（mapping）
- すべてのシャード状態の統一的な提供
- 注: 動的シャード数計算、IDENTIFYレート制限の調整、およびリバランス（rebalance）は将来対応予定であり、現時点では未実装

### 4. rest/（RESTクライアント）
低レベルおよび中レベルのREST APIクライアント。

ファイル:
- `rest/mod.zig` — 公開再エクスポート
- `rest/client.zig` — `getChannel`、`sendMessage` などの高レベルヘルパーを持つ `HttpClient`
- `rest/request_builder.zig` — 上級ユーザーが生のリクエストを独立して構築するための流暢API（fluent API）`RequestBuilder`（高レベルヘルパーからは使用されない）
- `rest/rate_limiter.zig` — バケット追跡付きのルート別レート制限（per-route rate limiting）
- `rest/bucket.zig` — 個別バケットの状態とメタデータ
- `rest/response.zig` — ステータス、ヘッダー、ボディ、`json()` ヘルパーを持つHTTPレスポンスラッパー
- `rest/errors.zig` — `RestError` エラーセット（error set）と `fromStatus` マッピング

責務:
- HTTPリクエスト（GET、POST、PATCH、DELETE）の構築と実行
- 認可ヘッダーとユーザーエージェントの注入
- すべてのリクエスト前にレートリミッター（rate limiter）と連携
- 一時的障害時の再試行（retry）の処理
- 適切な場所で解析済みモデル構造体または生JSONを返す

### 5. rest/rate_limiter.zig（レートリミッター）
ルート別のレート制限（per-route rate limit）への準拠。

責務:
- メジャーパラメータ（route + guild_id、channel_id など）をキーとするレート制限バケットの追跡
- バケットごとの remaining / reset / reset-after メタデータの維持
- 現在の制限を超えたリクエストのキューイングと遅延
- グローバルレート制限（429レスポンス）の処理

### 6. cache/（キャッシュ）
Gateway由来のオブジェクトを格納するオプションのインメモリキャッシュ。

ファイル:
- `cache/mod.zig` — 公開再エクスポート（`Cache`、`CacheOptions`）
- `cache/cache.zig` — `std.AutoHashMap` でバックされたインメモリストア

責務:
- ギルド、チャンネル、ユーザー、ロール、メッセージ、ボイス状態の保存
- ゲートウェイイベント（作成、更新、削除）に応じたエントリの更新
- IDによるO(1)またはO(log n)の複雑度での検索提供
- ユーザーがキャッシュを無効化したり制限（例: 最大キャッシュメッセージ数）を構成できるようにする
- メモリは同じ明示的アロケータによってバックされる
- すべての操作は内部 `std.Thread.Mutex` によって保護される
- 注: `Cache.deinit()` はHashMapコンテナ自体の解放のみを行います。キャッシュされたモデル構造体内部の動的アロケーションされたスライス（例: `Guild.roles`）の再帰的解放は、現時点の実装では行われていません

### 7. gateway/event_dispatcher.zig（イベントディスパッチャー）
ゲートウェイペイロードとユーザーコード間のルーティング層。

責務:
- オペコード + イベント名から内部イベント構造体へのマッピング
- VTable（`EventHandler.VTable`）を介したユーザーのイベントハンドラのレジストリ維持
- ゲートウェイスレッド上でハンドラを呼び出す。重い処理は別途 `std.Thread.spawn` で実行すべき
- 関連イベントでのキャッシュの upsert/remove 連携
- 生ゲートウェイペイロードと生RESTレスポンスのコールバック対応

### 8. models/（モデル）
APIエンティティを表すデータ構造。

ファイル:
- `models/mod.zig` — 公開再エクスポート
- `models/snowflake.zig` — タイムスタンプ抽出ヘルパーを持つ64ビットスノーフレークID（Snowflake ID）
- `models/user.zig` — ユーザーの構造体（id、username、avatar、botフラグなど）
- `models/guild.zig` — ギルドの構造体（name、owner_id、verification_level、roles、featuresなど）
- `models/channel.zig` — チャンネルの構造体（type、guild_id、name、positionなど）
- `models/message.zig` — メッセージの構造体（id、channel_id、author、content、embedsなど）
- `models/guild_member.zig` — ギルドメンバーの構造体（user、nick、roles、joined_atなど）
- `models/permissions.zig` — 権限ビットフラグ（Permission bitflags）とヘルパー関数

責務:
- すべてのAPIオブジェクト（User、Guild、Channel、Messageなど）の構造体定義
- 標準ライブラリの自動シリアライズをデフォルトとし、必要時のみカスタム `jsonParse`/`jsonStringify` を使用
- 定数の列挙型定義（チャンネル型、権限、インテント、オペコード）
- モデルを純粋に保つ（I/Oなし、隠されたアロケーションなし）

### 9. websocket/（WebSocket）
RFC 6455準拠のWebSocketフレームパーサーおよびシリアライザー。

ファイル:
- `websocket/mod.zig` — 公開再エクスポート（`Frame`、`Opcode`、`parseFrame`、`serializeFrame`、`serializeText`、`serializeClose`）
- `websocket/frame.zig` — フレームの解析/シリアライズ、マスキング、クローズフレーム

責務:
- `std.io.AnyReader` からの受信WebSocketフレームの解析
- テキスト、バイナリ、ping、pong、クローズフレームの送信シリアライズ
- RFC 6455に基づくペイロード長エンコーディング（7/16/64ビット）の処理
- クライアント→サーバー用フレームのXORマスキングの適用と解除
- 小さなペイロードには呼び出し元提供のバッファを使用。必要な場合のみヒープアロケーションを実行
- 注: TLS暗号化は現時点では未実装です。現状ではプレーンTCPが使用されており、`std.crypto.tls.Client` は将来のリリースで対応予定です

### 10. root.zig（ライブラリルート）
公開再エクスポートとライブラリのエントリーポイント。

責務:
- ライブラリバージョンの宣言
- すべての公開モジュール（`models`、`rest`、`gateway`、`cache`、`websocket`）の再エクスポート
- ライブラリ利用者向けに `Client` と `ClientOptions` を再エクスポート

## データフロー

### Gateway受信経路
```
Shard.receiveLoop ──► websocket.parseFrame ──► GatewayPayload
                                                      │
                                                      ▼
                                          gateway/event_dispatcher.zig
                                            EventDispatcher.dispatch
                                                      │
                                    ┌─────────────────┴─────────────────┐
                                    ▼                                   ▼
                              Cache.update                        User Handler
                              (upsert/remove)                     (VTable callbacks)
```

### HTTPリクエスト経路
```
Client.getChannel ──► HttpClient.request ──► RequestOptions
                                                       │
                                                       ▼
                                           rest/rate_limiter.zig
                                                RateLimiter.submit
                                                       │
                                                       ▼
                                                std.http.Client
                                                       │
                                                       ▼
                                                  Fluxer API
```

### Gateway送信経路（User → HTTP）
```
User ──► Client.createMessage ──► HttpClient.post ──► HttpClient.request
                                                              │
                                                              ▼
                                                     rest/rate_limiter.zig
                                                          RateLimiter
                                                              │
                                                              ▼
                                                       std.http.Client
                                                              │
                                                              ▼
                                                         Fluxer API
```

## 並行処理モデル

Zig 0.13+では `async/await` が削除されたため、スレッドベースの並行処理（Thread-based concurrency）を使用します:
- `Client` は `Shard.receiveLoop` 用の専用 `std.Thread` を生成する
- 各シャードは別スレッド上で独自の読み書きループを実行する
- HTTPリクエストは `std.http.Client` を使用し、呼び出しスレッドを完了までブロックする
- ユーザーのイベントハンドラはゲートウェイスレッド上で同期的に実行される。重いハンドラは、受信ループをブロックしないよう独自の `std.Thread.spawn` を使うべき
- すべての共有状態（キャッシュ、レートリミッター）は `std.Thread.Mutex` によって保護される

メモリ安全性は以下によって確保される:
- すべての公開APIが明示的な `std.mem.Allocator` を受け取る
- 隠されたグローバルアロケータは存在しない
- 明確な所有権: 誰がアロケートし、誰が解放するか

## メモリ管理方針

`fluxer-zig` は厳密な明示的メモリポリシーに従います:

- **init/deinitペアの徹底**: 初期化時にアロケーションを行うすべての構造体は、対応する `deinit` を提供します。
  例: `Client.init` ↔ `Client.deinit`、`Cache.init` ↔ `Cache.deinit`、`HttpClient.init` ↔ `HttpClient.deinit`。

- **errdeferによるロールバック**: 複雑な初期化シーケンスでは `errdefer` を使い、失敗時に部分的なアロケーションを解放します。
  `Client.init` の例: `token` を先に複製し、`HttpClient.init` が失敗した場合、`errdefer allocator.free(token)` が実行されてからエラーが伝播されます。

- **アロケータの所有権**: 最上位の `Client` はユーザーから提供されたアロケータを所有し、サブシステム（HttpClient、Cache、ShardManager）に渡します。サブシステムはアロケータ自体を所有しませんが、内部アロケーションにそれを使用し、`deinit` でクリーンアップする必要があります。

- **スライス所有権ルール**: 新しくアロケーションされたスライスを返す関数（例: `std.fmt.allocPrint`、`std.json.stringifyAlloc`）は所有権を文書化します。呼び出し側は `defer free` するか、明示的に所有権を譲渡する必要があります。

- **レスポンスライフサイクル**: `rest/response.zig` はボディバッファとヘッダーを所有します。呼び出し側は使用後に `response.deinit()` を呼ぶ必要があります。

- **フレームペイロードライフサイクル**: `websocket/frame.zig` は小さなペイロードにスタックバッファを使用し、必要な場合のみヒープアロケーションを行います。`Frame.deinit()` は `owned == true` の場合のみ解放するため、呼び出し側のクリーンアップは両方のケースで安全です。

## エラーハンドリング戦略

- すべての失敗しうる操作にはZigのエラー和型（error union `!T`）を使用します。
- 単一の包括的エラーセットではなく、ドメイン固有のエラーセットを定義します:
  - `RestError`（`rest/errors.zig`）: HTTPレベルの失敗（`HttpError`、`Unauthorized`、`Forbidden`、`NotFound`、`RateLimited`、`ServerError`、`JsonError`）をカバー。
  - `GatewayError`（`gateway/errors.zig`）: WebSocketおよびゲートウェイレベルの失敗（`ConnectionClosed`、`InvalidSession`、`MaxReconnectAttemptsExceeded`、`InvalidWebSocketAccept`、`InvalidOpcode`）をカバー。

- **リトライ戦略**:
  - `ConnectionClosed` / `ConnectionResetByPeer`: シャードが指数関数的バックオフで `tryReconnect()` をトリガー（最大5回、上限60秒）。
  - `RateLimited`（`429`）: `RateLimiter.submit` が `retry-after` 秒待ってからリクエストを再発行。
  - `InvalidSession`: シャードは `session_id` をリセットして再開（resume）ではなく再識別（re-identify）します。
  - HTTP `5xx`（`ServerError`）: 現時点ではRESTクライアント側で自動再試行は実装されていません。必要な場合は呼び出し側が再試行を行う必要があります。

- **エラー伝播ルール**:
  - 一時的なネットワークエラーは可能な限りゲートウェイ/リトライ層で吸収されます。
  - 致命的なエラー（例: `MaxReconnectAttemptsExceeded`）は呼び出し元に伝播されます。
  - 無効なペイロードはログ出力後にスキップされ、接続を維持します。

## JSON戦略

- 標準ライブラリの自動シリアライズ（`std.json`）をデフォルトとし、必要な場合のみカスタム `jsonParse`/`jsonStringify` を使用します。
- 解析には `std.json` を使用します。未知のフィールドはデフォルトで無視され、API追加による破壊を防ぎます。
- ゲートウェイペイロードは `op`、`d`、`s`、`t` フィールドを持つ標準的なエンベロープ構造体を使用します。

## 拡張性

- ユーザーは `EventHandler` VTable を介してコールバックを持つカスタムイベントハンドラ構造体を提供できます。
- キャッシュは同じインターフェースを実装することで置き換えまたはラップできます。
- HTTPクライアントはカスタムTLSコンテキストまたはプロキシ設定で構成できます。
- 追加のシャードはシャードマネージャーを介してホット追加できます。

## 設計決定事項

### なぜ自前WebSocketを実装したか
Zigの標準ライブラリにはWebSocketクライアントが含まれていません。`websocket/` においてRFC 6455準拠のフレームパーサー/シリアライザーを実装し、フレーミング、マスキング、クローズハンドシェイクの動作を外部依存なしで完全に制御しています。

### なぜVTable方式のEventHandlerか
Zigには言語レベルのインターフェースが存在しません。VTable（`EventHandler.VTable`）はZigにおける慣用的なインターフェースパターンです。これにより、具体的なハンドラ構造体に対するコンパイル時の型安全性（compile-time type safety）と、関数ポインタを介した実行時のポリモーフィズム（runtime polymorphism）の両立が実現されます。

### なぜper-route RateLimiterか
Discord/Fluxer APIはルート別（method + major parameter）にレートリミット（rate limit）を適用します。`RateLimiter` は各ルートに独立した `Bucket` インスタンスを追跡し、erisの `SequentialBucket` デザインを参考にしています。これにより、関連性のないエンドポイント間で不必要なスロットリングを生じさせることなく準拠が確保されます。

### なぜstd.Threadベースか
Zig 0.13で `async/await` が削除されました。すべての並行処理は `std.Thread` と共有状態用の `std.Thread.Mutex` で実装されています。これは明示的で予測可能であり、すべての対象プラットフォームで動作します。

### なぜstd.jsonを標準とするか
Zig 0.13の `std.json` はAPIクライアント用途に十分に強力です。デフォルトで自動解析（`std.json.parseFromSlice`）を使用し、JSON形状が構造体レイアウトから逸脱する場合のみ（例: Snowflakeの文字列↔整数強制変換）カスタム `jsonParse`/`jsonStringify` を記述します。

## 低レベル設計

このセクションは、高レベルAPIを動かす低レベル層について説明します。すべての高レベルAPIはこれらのプリミティブの薄いラッパーであり、上級ユーザーは直接操作できます。

### RawHTTPモジュール（rest/）

生のHTTPリクエスト/レスポンスの仕組みに直接アクセスします。

責務:
- `RequestBuilder` はメソッド、URL、ヘッダー、ボディを自由に構築
- `Response` はステータス、ヘッダー、生ボディ、`json()` ヘルパーを公開
- `HttpClient.request(method, path, options)` は高レベルラッパーなしでFluxer APIを直接叩く
- すべてのRESTヘルパー内部で使用され、パワーユーザー向けに公開

### RawGatewayモジュール（gateway/）

生のGatewayペイロードと手動シャード制御に直接アクセスします。

責務:
- `Shard.sendRaw(payload)` は生のJSON/オペコードペイロードを送信
- `EventDispatcher` はVTableを介して生ゲートウェイペイロードと生RESTレスポンスのコールバックを公開
- `Shard.connect()`、`Shard.disconnect()`、`Shard.status()` は手動のライフサイクル制御を提供
- イベントディスパッチャー内部で使用され、パワーユーザー向けに公開

### RESTクライアント内部構造

```
HttpClient -> RequestOptions -> RateLimiter -> std.http.Client -> Fluxer API
```

- `HttpClient` は高レベルメソッド（`getChannel`、`sendMessage` など）を実装
- すべての高レベルメソッドは `RequestOptions` を使って `request()` をパスとボディを事前設定してラップ
- `RequestBuilder`（低レベル）は上級ユーザーが独立してリクエストを構築するために使用され、高レベルヘルパーからは使用されない

### Gatewayクライアント内部構造

```
ShardManager -> Shard -> Heartbeat -> websocket/ -> std.net / std.crypto.tls
```

- `Shard` は単一のWebSocket接続を管理
- `ShardManager` は複数シャードのライフサイクルを統括
- `Heartbeat` はシャードごとに動作し、ジッター、ACK監視、ゾンビ検出を処理
- `websocket/` はシャード層の下でRFC 6455フレーミングを処理

### RateLimiter内部構造

erisのSequentialBucketに影響を受けたルート別バケット管理。

責務:
- `RateLimiter.submit(request)` は内部でリクエストをキューイング
- `RateLimiter.bucketState(route)` はバケットメタデータを参照用に公開
- `x-ratelimit-limit`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-reset-after` を追跡
- グローバルレート制限（`x-ratelimit-global` 付き429）を処理

### Cache内部構造

パフォーマンスチューニングのための細粒度キャッシュ制御。

責務:
- 初期化時にキャッシュのオン/オフを切り替え
- 部分キャッシュ: 特定イベントを無効化し、選択されたペイロードのみをキャッシュ
- プラガブルバックエンドインターフェース: デフォルトのインメモリストアを差し替え可能
- `CacheOptions` は `enabled`、`message_limit`、`disabled_events` を制御
- メンバーキーは一意な検索のために `guild_id` と `user_id` から構成される