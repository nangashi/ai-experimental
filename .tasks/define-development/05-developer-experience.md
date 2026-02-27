# 開発者体験（Developer Experience）

## 決定事項一覧（サマリテーブル）

| # | 決定事項 | 主な選択肢 | 決定の影響度 |
|---|---------|-----------|-------------|
| 1 | ローカル開発環境セットアップ | Dev Containers / Docker Compose / 直接インストール | 高：オンボーディング速度・環境差異に直結 |
| 2 | ホットリロード・HMR 設定 | Vite HMR / Next.js Fast Refresh / webpack HMR | 中：開発フィードバックループの速度 |
| 3 | デバッグ環境 | VS Code launch.json / ブラウザ DevTools / Node.js inspector | 中：バグ調査の効率 |
| 4 | AI コーディング支援の設定 | Claude Code / GitHub Copilot / Cursor / 併用 | 高：開発生産性への直接的影響 |
| 5 | テンプレート/スキャフォールド | Plop / Hygen / カスタムスクリプト | 低〜中：コード一貫性・新規作成の効率 |
| 6 | 開発用モックサーバー/データ | MSW / Mirage JS / JSON Server / カスタムモック | 中：フロントエンド開発の独立性 |
| 7 | 依存関係の更新戦略 | Renovate / Dependabot / 手動管理 | 中：セキュリティ・技術的負債の管理 |
| 8 | ドキュメント戦略 | README / CONTRIBUTING / API docs / AI 向け指示 | 中：チーム拡大時の生産性維持 |

## 各項目の詳細

### 1. ローカル開発環境セットアップ

- **何を決めるか**: 開発者がプロジェクトを開始するまでの手順と、環境の統一方法
- **選択肢**:
  - **Dev Containers（推奨）**: `.devcontainer/devcontainer.json` でコンテナ化された開発環境を定義。VS Code Remote Containers で利用
    - 全チームメンバーが同一環境で開発。Node.js バージョン、システム依存等の差異が解消
    - エディタ拡張、設定もコンテナに含められる
  - **Docker Compose**: アプリケーションの依存サービス（DB, Redis, etc.）をコンテナ化。アプリ本体はホストで実行
  - **直接インストール**: Node.js（nvm/fnm/volta でバージョン管理）+ パッケージマネージャを直接インストール
  - **ハイブリッド**: アプリ本体はホスト実行、依存サービスは Docker Compose、環境定義は Dev Container で統一
- **選定基準**:
  - オンボーディング速度：Dev Container はクローン後すぐに開発開始可能（`git clone` → VS Code で開く → 自動セットアップ）
  - パフォーマンス：ホスト実行が最速。Docker 内実行はファイル I/O のオーバーヘッド（特に macOS）
  - CI との一致度：Dev Container は CI 環境と同一イメージを使用可能
  - チームの Docker 習熟度：Docker 未経験者が多い場合は直接インストール + バージョン管理ツールが導入しやすい
- **トレードオフ・注意点**:
  - Dev Container: macOS + Docker Desktop の組み合わせでファイルシステムのパフォーマンス問題あり（対策: named volume, VirtioFS）
  - Dev Container: WSL2 環境ではホットリロードのファイルウォッチャーが正常動作しない場合がある（inotify の制限）
  - 直接インストール: `volta` または `fnm` で Node.js バージョンを固定（`.node-version` または `package.json` の `engines`）
  - プロジェクトルートに `Makefile` または `package.json` の `scripts` でセットアップコマンドを提供（`make setup` or `npm run setup`）
  - `.tool-versions`（asdf）または `.node-version` をコミットして Node.js バージョンを共有
- **2025-2026年のトレンド**:
  - Dev Containers 仕様が VS Code 以外のエディタ（JetBrains, Neovim 等）にも対応拡大
  - GitHub Codespaces / Gitpod によるクラウド開発環境の採用が増加。ローカルセットアップ自体を不要にする方向
  - Docker Desktop の代替（OrbStack, Podman, Rancher Desktop）が macOS で採用増。特に OrbStack はパフォーマンスで優勢
  - Devbox（Nix ベース）が Docker 不要の再現可能な開発環境として注目
  - `volta` が Node.js バージョン管理のデファクトに成長（nvm からの移行が進行）

### 2. ホットリロード・HMR 設定

- **何を決めるか**: コード変更時のブラウザ/サーバーの自動更新方法
- **選択肢**:
  - **Vite HMR**: ESM ベースの高速 HMR。React / Vue / Svelte 等に対応
  - **Next.js Fast Refresh**: React コンポーネントの状態を保持したまま更新
  - **webpack HMR**: 設定の柔軟性は高いが、Vite に比べ低速
  - **Node.js --watch**: Node.js 18+ 組み込みのファイルウォッチ（バックエンド用）
  - **tsx watch / nodemon**: TypeScript バックエンドのホットリロード
- **選定基準**:
  - フレームワーク選定に依存：Next.js なら Fast Refresh が自動、Vite ベースなら Vite HMR
  - バックエンドの技術選定：Express/Fastify/Hono は `tsx watch` や `node --watch` で対応
  - 状態保持の必要性：React の Fast Refresh はコンポーネント状態を保持。フルリロードでは状態が失われる
- **トレードオフ・注意点**:
  - Docker / Dev Container 内でのファイルウォッチ：ホストのファイル変更がコンテナに反映されるまでの遅延に注意
  - WSL2 環境：Windows 側のファイルシステムの変更は WSL 内のファイルウォッチャーが検知しない場合がある。プロジェクトを WSL 内に配置する
  - CSS Modules / Tailwind CSS の変更は HMR 対応。ただし PostCSS プラグインの変更はフルリロードが必要
  - `.env` ファイルの変更はフルリロード（サーバー再起動）が必要
- **2025-2026年のトレンド**:
  - Vite が開発サーバーのデファクトスタンダードに。CRA（Create React App）は公式に非推奨化
  - Next.js の Turbopack（Rust 製バンドラー）が安定版に移行中。webpack HMR を置き換え
  - `node --watch`（Node.js 22 で安定化）が nodemon の代替として定着
  - `tsx`（TypeScript Execute）がバックエンド TypeScript のリアルタイム実行で普及

### 3. デバッグ環境

- **何を決めるか**: フロントエンド・バックエンドのデバッグ方法と設定の標準化
- **選択肢**:
  - **VS Code launch.json**: ブレークポイント、ステップ実行、変数ウォッチをエディタ内で実行
  - **ブラウザ DevTools**: Chrome DevTools + React DevTools / Vue DevTools 拡張
  - **Node.js Inspector**: `--inspect` フラグ + Chrome DevTools または VS Code デバッガー接続
  - **Server-side ログ**: 構造化ログ（Pino, Winston）+ ログレベル制御
- **選定基準**:
  - 開発者のワークフロー：VS Code ユーザーが多数なら launch.json の共有が効果的
  - フレームワーク対応：Next.js は `.vscode/launch.json` の公式テンプレートを提供
  - リモートデバッグの必要性：Docker/Dev Container 内のプロセスをデバッグする場合はポートマッピングが必要
- **トレードオフ・注意点**:
  - `.vscode/launch.json` はリポジトリにコミットし、チームで共有する
  - Source Map の設定：開発時は `eval-source-map`（高速）、ステージングは `source-map`（高品質）
  - React DevTools Profiler でパフォーマンスボトルネックを特定するワークフローを確立
  - バックエンドのログは構造化 JSON 形式（Pino 推奨）。開発時は `pino-pretty` で人間可読な出力
  - `console.log` デバッグは開発中のみ許容。コミット前に削除する規約（`eslint-plugin-no-console` で検出）
- **2025-2026年のトレンド**:
  - VS Code のデバッグ機能が Dev Container 内のプロセスにシームレスに接続可能に
  - React DevTools が Server Components のデバッグに対応拡大
  - OpenTelemetry による分散トレーシングがローカル開発環境にも導入される事例が増加
  - Sentry / Datadog 等のエラートラッキングの開発環境統合が進み、本番と同じ可観測性をローカルで実現

### 4. AI コーディング支援の設定

- **何を決めるか**: AI コーディングアシスタントの選定、プロジェクト固有の設定方法
- **選択肢**:
  - **Claude Code**: CLI ベースの AI コーディングエージェント。`CLAUDE.md` でプロジェクト指示を定義、`.claude/` 配下でスキル・設定を管理
  - **GitHub Copilot**: VS Code / JetBrains 統合。コード補完 + Agent Mode（自律的なコード修正）。`.github/copilot-instructions.md` で指示を定義
  - **Cursor**: AI ファーストのエディタ。`.cursorrules` でプロジェクトルールを定義
  - **併用**: Claude Code（タスク実行・大規模変更）+ GitHub Copilot（インラインコード補完）
- **選定基準**:
  - ワークフロー：インライン補完メインなら Copilot、タスクベースの自律的コーディングなら Claude Code
  - チームの統一性：AI 設定ファイル（`CLAUDE.md`, `.github/copilot-instructions.md`）はリポジトリにコミットし、チーム全体で共有
  - コスト：Copilot Pro+ は月額39ドル（Claude モデル含む）。Claude Code は API 使用量に応じた従量課金
  - セキュリティ：企業環境での AI ツールの利用ポリシーとの整合性
- **トレードオフ・注意点**:
  - `CLAUDE.md` には以下を記載：プロジェクトの概要、ディレクトリ構造、コーディング規約、テスト実行方法、デプロイ手順
  - `.github/copilot-instructions.md` には Copilot への指示（使用する技術スタック、コーディングスタイル、避けるべきパターン等）を記載
  - AI のコード生成結果は必ずレビューする。特にセキュリティ関連（認証、入力バリデーション）は人間による確認が必須
  - AI の quota 消費に注意：Claude Code は Copilot Agent Mode より多くのリクエストを消費する傾向
  - `.claude/` ディレクトリにスキル定義やカスタムコマンドを格納し、プロジェクト固有の AI ワークフローを構築可能
- **2025-2026年のトレンド**:
  - GitHub の Agent HQ に Claude、Codex 等の複数 AI エージェントが統合。マルチエージェント環境が現実化
  - Claude Code の SWE-bench スコア 72.5%（2025年1月時点）で業界最高水準。自律的なコーディング能力が実用レベルに
  - AI 向けプロジェクト説明ファイル（`CLAUDE.md`, `.cursorrules` 等）がプロジェクトのドキュメンテーション標準の一部に
  - AI コードレビュー（PR レビューの自動化）が CI パイプラインに組み込まれるケースが増加
  - 2026年にかけて AI エージェントがテスト作成・リファクタリング・ドキュメント生成を自律的に実行する「AI-native 開発フロー」が確立しつつある

### 5. テンプレート/スキャフォールド

- **何を決めるか**: 新規コンポーネント・ページ・API エンドポイント等の定型コード生成方法
- **選択肢**:
  - **Plop**: JSON 設定でジェネレーターを定義。Handlebars テンプレート。最もシンプルで導入が容易
  - **Hygen**: ファイルベースのテンプレート（YAML フロントマター + EJS）。プロジェクト内で管理。CLI が直感的
  - **Nx Generators**: Nx モノレポ内蔵のジェネレーター。TypeScript で記述可能
  - **カスタムスクリプト**: Node.js スクリプトで独自のコード生成。最大の柔軟性
  - **AI ベース生成**: Claude Code / Copilot に「このパターンで新規ファイルを作成して」と指示
- **選定基準**:
  - 生成するファイルの複雑度：単一ファイル生成なら Plop/Hygen で十分。複数ファイル + 既存ファイル更新なら Nx Generators やカスタムスクリプト
  - チームの使い勝手：Plop は対話式プロンプトで初心者にも分かりやすい。Hygen はコマンドラインから一発実行
  - メンテナンス性：テンプレートが頻繁に変わる場合はファイルベース（Hygen）の方が管理しやすい
- **トレードオフ・注意点**:
  - テンプレートのメンテナンスコスト：プロジェクトのコーディング規約が変わるたびにテンプレートも更新が必要
  - 過度なテンプレート化は避ける。頻繁に生成するパターン（3回以上手動作成する見込み）のみテンプレート化
  - 生成されるコードに含まれるべき要素：基本的なファイル構造、import 文、型定義、テストファイルのスケルトン
  - `npm run generate` or `pnpm generate` で実行できるように package.json に登録
- **2025-2026年のトレンド**:
  - AI コーディングアシスタントがスキャフォールドツールの代替として台頭。「テンプレートを使う」代わりに「AI に指示する」ワークフローが増加
  - ただし AI 生成はプロジェクト規約との一貫性保証が弱いため、テンプレートツールと AI の併用が現実的
  - Plop / Hygen は引き続きシンプルな定型生成で活用。Yeoman は新規採用が減少
  - Nx Generators は Nx モノレポ採用プロジェクトで定番

### 6. 開発用モックサーバー/データ

- **何を決めるか**: バックエンド API が未完成・利用不可の状況でフロントエンドを開発するための仕組み
- **選択肢**:
  - **MSW（Mock Service Worker）**: Service Worker でネットワークリクエストをインターセプト。ブラウザの Network タブに実際の HTTP リクエストとして表示される。テストでも再利用可能
  - **Mirage JS**: インメモリ DB + ORM + シリアライザー。複雑なリレーショナルデータのモックに強い
  - **JSON Server**: `db.json` をベースに REST API を自動生成。セットアップが最も簡単
  - **カスタム Express/Hono モックサーバー**: 完全な制御が可能だがメンテナンスコストが高い
- **選定基準**:
  - データの複雑さ：リレーショナルデータ（ユーザー → 投稿 → コメント等）が必要なら Mirage JS
  - テストとの共有：同じモック定義をユニットテスト・E2E テストでも使いたいなら MSW
  - リアリズム：Network タブでリクエストを確認したいなら MSW（Service Worker でインターセプト）
  - チームの学習コスト：JSON Server が最も簡単。MSW は中程度。Mirage JS は ORM 概念の理解が必要
- **トレードオフ・注意点**:
  - MSW: ブラウザ環境では Service Worker、Node.js 環境では `setupServer` と異なるセットアップが必要
  - MSW: リクエストハンドラーの定義が API 仕様と乖離するリスク。OpenAPI スキーマからのハンドラー自動生成を検討
  - Mirage JS: バンドルサイズに影響するため、本番ビルドから確実に除外する
  - モックデータの管理：Factory パターン（Faker.js + 固定シード）でテストデータの再現性を確保
  - フィーチャーフラグでモックモードを切り替え可能にする（`NEXT_PUBLIC_USE_MOCK=true` 等）
- **2025-2026年のトレンド**:
  - MSW v2 が安定し、業界標準の API モッキングツールとして定着。テスト・開発の両方で同一定義を使用する構成が主流
  - OpenAPI / GraphQL スキーマからのモック自動生成ツール（MSW + openapi-msw 等）の採用が増加
  - AI がテストデータのバリエーションを自動生成する仕組みが実験的に登場
  - Mock API は「あると便利」から「フロントエンド開発の必須インフラ」に格上げ。CI でのモックテスト実行時間が20-60%削減

### 7. 依存関係の更新戦略

- **何を決めるか**: npm パッケージの依存関係を最新に保つための自動化方針
- **選択肢**:
  - **Renovate**: 高度にカスタマイズ可能な依存更新ボット。30+ パッケージマネージャ対応。GitHub / GitLab / Bitbucket 対応
  - **Dependabot**: GitHub ネイティブの依存更新ツール。セットアップが簡単。GitHub 限定
  - **手動管理**: `npm outdated` / `pnpm outdated` で定期的にチェック
- **選定基準**:
  - Git プラットフォーム：GitHub 限定なら Dependabot でも可。マルチプラットフォームなら Renovate
  - カスタマイズ性：グループ更新、自動マージ、スケジュール制御が必要なら Renovate が圧倒的に優位
  - モノレポ対応：Renovate はモノレポの複数パッケージをまとめて更新可能。Dependabot はパッケージごとに個別 PR
  - チームの運用負荷：自動マージ設定で patch/minor 更新を自動化し、major 更新のみ手動レビュー
- **トレードオフ・注意点**:
  - 自動マージ戦略:
    - Patch 更新：テスト通過後に自動マージ
    - Minor 更新：テスト通過後に自動マージ（`minimumReleaseAge: "3 days"` で安全マージン）
    - Major 更新：手動レビュー必須
  - セキュリティ更新は即座に対応。`minimumReleaseAge` をセキュリティアップデートには適用しない
  - 依存更新の PR が溜まると対応が困難に。定期的（週1回等）にまとめて対処するスケジュールを設定
  - Renovate の `automerge` 設定には `minimumReleaseAge: "14 days"` を推奨（悪意のあるパッケージの検出期間を確保）
  - ロックファイル（`pnpm-lock.yaml`, `package-lock.json`）は必ずコミットする
  - 共有設定：`renovate-config` リポジトリで組織共通の設定を管理し、各リポジトリで extends する
- **2025-2026年のトレンド**:
  - Renovate が Dependabot を機能面で圧倒し、移行が加速。特にモノレポ環境では Renovate 一択の状況
  - Renovate のグループ更新機能（関連パッケージをまとめて1 PR）により、PR の数を大幅削減
  - Socket.dev 等のサプライチェーンセキュリティツールとの連携が標準化
  - 「依存を最新に保つ」ことが技術的負債管理の基本プラクティスとして再認識
  - AI による CHANGELOG 要約・更新影響分析が Renovate PR に統合される動き

### 8. ドキュメント戦略

- **何を決めるか**: プロジェクトに必要なドキュメントの種類と管理方法
- **選択肢**:
  - **README.md**: プロジェクト概要、セットアップ手順、基本的な使い方
  - **CONTRIBUTING.md**: 開発参加のガイドライン、PR プロセス、コーディング規約の概要
  - **API ドキュメント**: OpenAPI / Swagger（REST）、GraphQL Schema + Playground、TSDoc + TypeDoc
  - **AI 向けプロジェクト指示**: `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`
  - **ADR（Architecture Decision Record）**: `docs/adr/` に設計判断を記録
  - **Runbook**: 運用手順書、インシデント対応手順
- **選定基準**:
  - チーム規模：小規模（1-3人）は README + CLAUDE.md で最小限。中規模以上は CONTRIBUTING + ADR を追加
  - 外部公開：OSS や外部開発者が関わる場合は CONTRIBUTING.md が必須
  - API 消費者の存在：外部チームが API を利用する場合は OpenAPI ドキュメントが必須
  - ドキュメントの鮮度維持：自動生成できるもの（API docs, TypeDoc）は CI で自動更新
- **トレードオフ・注意点**:
  - README.md の必須セクション：
    1. プロジェクト概要（何をするプロジェクトか）
    2. 技術スタック
    3. セットアップ手順（`git clone` から開発サーバー起動まで）
    4. 主要なスクリプト一覧（`npm run dev`, `npm run test` 等）
    5. ディレクトリ構造の概要
    6. デプロイ方法
  - ドキュメントはコードと同じリポジトリで管理する（Docs as Code）。Wiki は使わない
  - 陳腐化しやすいドキュメントは自動生成に寄せる（API schema → ドキュメント、型定義 → ドキュメント）
  - ADR の番号体系：`docs/adr/0001-use-next-js.md` 形式。ステータス（proposed / accepted / deprecated / superseded）を管理
  - AI 向け指示ファイルはプロジェクト参加者全員に恩恵があるため、初期から作成・メンテナンスする
- **2025-2026年のトレンド**:
  - AI 向けプロジェクト説明ファイル（`CLAUDE.md` 等）が「開発者向けドキュメント」の新しいカテゴリとして確立
  - Docs as Code（Markdown + Git 管理）が完全に主流化。Notion / Confluence との併用は残るが、コードに近いドキュメントはリポジトリ内に
  - OpenAPI 3.1 + Scalar（旧 Stoplight Elements）による API ドキュメントの自動生成・ホスティングが普及
  - ADR の採用がスタートアップ・中小規模チームにも拡大。テンプレートツール（adr-tools, log4brains）の利用増加
  - AI がプロジェクトのコードベースを分析して README / CONTRIBUTING を自動生成する機能が実用化段階に
