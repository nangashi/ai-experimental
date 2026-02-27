# プロジェクト構成

## 決定事項一覧（サマリテーブル）

| # | 決定事項 | 主な選択肢 | 決定の影響度 |
|---|---------|-----------|-------------|
| 1 | モノレポ vs ポリレポ | モノレポ（Turborepo/Nx/pnpm workspace） / ポリレポ | 高：CI/CD、共有コード、チーム構造全体に影響 |
| 2 | ディレクトリ構成パターン | Feature-based / Layer-based / Hybrid | 高：開発者の認知負荷とスケーラビリティに直結 |
| 3 | フロントエンド/バックエンドの分割単位 | 同一レポ内 apps/ 分割 / BFF パターン / 完全分離 | 中：デプロイ戦略・チーム分担に影響 |
| 4 | 共有コードの管理方法 | internal package / shared ディレクトリ / npm private package | 高：型安全性・重複排除・ビルド戦略に影響 |
| 5 | モジュール境界の設計 | Barrel exports / Package boundaries / ESLint boundaries | 中：依存関係の制御・ビルドパフォーマンスに影響 |
| 6 | 設定ファイルの管理 | .env 戦略 / 環境別分割 / Secret Manager 連携 | 中：セキュリティ・運用に影響 |
| 7 | エイリアスパス設定 | tsconfig paths / bundler alias / import map | 低：DX 改善だが設定不整合リスクあり |

## 各項目の詳細

### 1. モノレポ vs ポリレポ

- **何を決めるか**: プロジェクト内の複数アプリケーション・パッケージを単一リポジトリで管理するか、リポジトリを分割するか
- **選択肢**:
  - **モノレポ**: 単一リポジトリに全コードを格納。ツール選択が必要
    - **Turborepo**: pnpm/yarn/npm workspace 上で動作するタスクランナー。既存プロジェクトに10分以内で導入可能。アーキテクチャ管理機能は持たない
    - **Nx**: 包括的なモノレポ管理ツール。タスク実行に加え、依存グラフ解析・コード生成・循環依存検出を提供。Rust コアで Turborepo 比 7倍以上高速（大規模レポベンチマーク）
    - **pnpm workspace**: パッケージマネージャレベルのワークスペース機能。Turborepo/Nx と組み合わせて使用
  - **ポリレポ**: サービス/パッケージごとに独立リポジトリ
- **選定基準**:
  - チーム規模：5人以下の小規模チームではモノレポの管理オーバーヘッドが相対的に大きい。ただし共有コードがある場合はモノレポの恩恵が上回る
  - コード共有度：フロントエンド・バックエンド間で型定義やバリデーションを共有する場合はモノレポが有利
  - デプロイ独立性：サービスごとに完全に独立したデプロイサイクルが必要な場合はポリレポが適合
  - CI/CD 投資余力：モノレポは affected ビルド・キャッシュ戦略等の CI 最適化が前提
- **トレードオフ・注意点**:
  - モノレポ: CI 時間の増大（対策: affected analysis, remote caching）、リポジトリサイズの肥大化、全チームへのツール習熟コスト
  - ポリレポ: 横断的変更（shared library の breaking change 等）の原子的適用が困難、バージョン同期のオーバーヘッド
  - Turborepo はアーキテクチャ管理を提供しないため、循環依存防止やコード生成は別途対応が必要
  - Nx は機能豊富だが学習コストが高く、Nx 固有の概念（project.json, generators 等）への依存が発生する
- **2025-2026年のトレンド**:
  - Turborepo + pnpm workspace が新規プロジェクトの主流構成。軽量さと段階的導入のしやすさが支持されている
  - Nx は大規模エンタープライズや100k+ 行のモノレポで採用が増加。Rust コアへの移行で性能が大幅に改善
  - pnpm がパッケージマネージャのデファクトに定着。npm/yarn からの移行が加速
  - ポリレポは依然としてマイクロサービスアーキテクチャで採用されるが、フルスタック TypeScript プロジェクトではモノレポが優勢

### 2. ディレクトリ構成パターン

- **何を決めるか**: src/ 配下のファイル・フォルダの編成方針
- **選択肢**:
  - **Feature-based**: 機能単位でフォルダを分割。各 feature フォルダに UI・ロジック・型・テストを同居
    ```
    src/
      features/
        user/
          components/
          hooks/
          api/
          types.ts
        product/
          components/
          hooks/
          api/
          types.ts
      shared/
        components/
        utils/
      core/
        auth/
        config/
    ```
  - **Layer-based**: 技術レイヤーでフォルダを分割（components/, hooks/, services/, types/ 等）
    ```
    src/
      components/
      hooks/
      services/
      types/
      utils/
    ```
  - **Hybrid**: Feature-based を基本に、横断的な共有コードを shared/ や core/ に配置
    ```
    src/
      app/          # ルーティング・エントリポイント
      features/     # 機能単位
      shared/       # 再利用可能な UI・ユーティリティ
      core/         # アプリ全体の基盤（認証、設定等）
    ```
- **選定基準**:
  - プロジェクト規模：小規模（10画面以下）では Layer-based で十分。中〜大規模では Feature-based が認知負荷を低減
  - チーム構成：機能チーム制なら Feature-based がオーナーシップと一致する
  - 変更の局所性：1つの機能変更が1つのフォルダ内で完結するかどうか
- **トレードオフ・注意点**:
  - Feature-based: 機能間で共有するコードの置き場所の判断が必要（shared/ への移動タイミング）。機能の粒度をチームで合意する必要がある
  - Layer-based: 小規模では分かりやすいが、規模拡大に伴い各フォルダが肥大化し、関連ファイルの探索コストが増大
  - Hybrid: 柔軟だが「どこに置くか」の判断基準が曖昧になりやすい。明文化されたルールが必須
- **2025-2026年のトレンド**:
  - Feature-based（または Feature-Sliced Design）が2025年のデフォルト構成として定着
  - Next.js App Router では app/ をルーティング専用にし、ビジネスロジックを features/ に分離するパターンが主流
  - Angular の Standalone Components 導入により Feature-based 構成がさらに推進されている
  - 「pages はスクリーンの組み立て、features はビジネスロジック、shared は再利用可能な部品」という3層分離が共通認識に

### 3. フロントエンド/バックエンドの分割単位

- **何を決めるか**: フロントエンドとバックエンドをどの粒度で分離し、どのようにデプロイするか
- **選択肢**:
  - **モノレポ内 apps/ 分割**: `apps/web`, `apps/api` として同一リポジトリ内に配置。共有パッケージを `packages/` に格納
  - **BFF（Backend for Frontend）パターン**: フロントエンド専用の中間サーバーを設置。Next.js の Server Actions / Route Handlers が実質的な BFF として機能
  - **完全分離**: フロントエンド・バックエンドを別リポジトリで管理。独立したデプロイサイクル
- **選定基準**:
  - 型共有の必要性：フルスタック TypeScript ならモノレポ内分割が型安全性の面で最も有利
  - チーム構成：フロント/バック別チームなら完全分離が自然。フルスタックチームならモノレポ内分割
  - デプロイ戦略：独立スケーリングが必要ならサービス単位の分割を検討
- **トレードオフ・注意点**:
  - モノレポ内分割: 共有コードの変更が両方に影響するため、CI でのクロスビルドテストが必須
  - BFF: レイヤーが増えることによる複雑性。ただし Next.js 等のフレームワーク組み込み BFF は追加インフラ不要
  - 完全分離: API スキーマの同期コスト（OpenAPI / GraphQL スキーマの共有が必要）
- **2025-2026年のトレンド**:
  - Next.js / Nuxt のサーバー機能活用により、フロントエンドプロジェクトが実質的に BFF を包含する構成が増加
  - tRPC による型安全な API 通信がモノレポ内フルスタック TypeScript で普及
  - Hono がバックエンド軽量フレームワークとして急成長。Cloudflare Workers 等のエッジ環境での採用が増加

### 4. 共有コードの管理方法

- **何を決めるか**: フロントエンド・バックエンド間、または複数アプリ間で共有する型定義・バリデーション・定数の管理方法
- **選択肢**:
  - **Internal package（モノレポ内パッケージ）**: `packages/shared` として管理。pnpm workspace のプロトコル（`workspace:*`）で参照
  - **shared ディレクトリ**: モノレポのルートに `shared/` を配置し、tsconfig paths で参照
  - **npm private package**: 独立したパッケージとして npm registry（private）に公開
- **選定基準**:
  - ビルド戦略：internal package は各アプリのビルドに含める（Turborepo の internal packages）か、事前ビルドするか
  - 変更頻度：頻繁に変更される共有コードは internal package が適合（即時反映）
  - 利用範囲：組織内の複数リポジトリで使う場合は npm private package
- **トレードオフ・注意点**:
  - Internal package: TypeScript の Project References 設定が複雑になりやすい。ビルド順序の管理が必要
  - shared ディレクトリ: パッケージ境界が曖昧になりやすく、意図しない依存が発生するリスク
  - npm private package: 公開・バージョニングのオーバーヘッド。ローカル開発時の即時反映には `npm link` 等の追加手順が必要
- **2025-2026年のトレンド**:
  - Zod スキーマを共有パッケージに定義し、フロントエンド・バックエンドで同一バリデーションを使用する構成が標準化
  - Turborepo の internal packages（ビルドなしで直接参照）が、事前ビルド方式に対して簡便さで優勢
  - Zodスキーマからの型推論（`z.infer<typeof schema>`）により、型定義の二重管理が解消される方向
  - Prisma スキーマから生成された型を共有パッケージ経由でフロントエンドに提供するパターンが定着

### 5. モジュール境界の設計

- **何を決めるか**: パッケージ・モジュール間の依存関係をどう制御し、公開 API をどう定義するか
- **選択肢**:
  - **Barrel exports（index.ts）**: 各モジュールのルートに index.ts を配置し、公開するものだけを re-export
  - **Package boundaries（package.json exports）**: package.json の `exports` フィールドで公開エントリポイントを制御
  - **ESLint boundaries**: `eslint-plugin-boundaries` や `@nx/enforce-module-boundaries` で依存ルールを静的解析
  - **明示的 Named exports のみ**: barrel file を使わず、直接ファイルパスからインポート。TypeScript paths でエイリアス
- **選定基準**:
  - ビルドパフォーマンス：barrel exports は tree-shaking を阻害する場合がある（`export *` の使用時）
  - 開発者の認知負荷：barrel exports は import 文が簡潔になるが、循環依存のリスクが増加
  - 強制力：ESLint ルールは CI で強制可能。barrel exports のみでは破られやすい
- **トレードオフ・注意点**:
  - Barrel exports: `export *` はバンドルサイズ増大と tree-shaking 阻害の原因。明示的な named export を推奨
  - Barrel exports: 同一ディレクトリ内のモジュール間で barrel 経由の import が発生すると循環依存が生じる
  - Package boundaries: 設定が煩雑だが、最も厳密なモジュール境界を実現
  - ESLint boundaries: ルール定義の初期コストは高いが、チームスケール時に効果を発揮
- **2025-2026年のトレンド**:
  - 大規模プロジェクトでは barrel exports を縮小・廃止し、TypeScript paths + 直接インポートに移行する動き
  - Nx の Module Federation と enforce-module-boundaries の組み合わせが大規模モノレポで採用増
  - package.json の `exports` フィールドによるエントリポイント制御が Node.js エコシステムで標準化
  - `eslint-plugin-barrel-files` 等のツールで barrel の使用を自動チェックするプラクティスが普及

### 6. 設定ファイルの管理

- **何を決めるか**: 環境別設定（開発/ステージング/本番）の管理方法、シークレットの取り扱い
- **選択肢**:
  - **dotenv（.env ファイル）**: `.env`, `.env.local`, `.env.development`, `.env.production` の環境別分割
  - **Secret Manager 連携**: AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault と連携
  - **環境変数直接設定**: CI/CD プラットフォームやコンテナオーケストレーターの環境変数機能を使用
- **選定基準**:
  - セキュリティ要件：本番シークレットは .env ファイルに保持しない。Secret Manager またはプラットフォーム環境変数を使用
  - 開発者体験：ローカル開発では .env ファイルが最も手軽
  - バリデーション：起動時に環境変数の存在と型を検証する仕組みが必要
- **トレードオフ・注意点**:
  - `.env` ファイルは必ず `.gitignore` に追加。代わりに `.env.example` をコミットして必要な変数名を共有
  - 環境変数のバリデーションには `envalid`（Node.js）や `@t3-oss/env-nextjs`（Next.js）を使用し、起動時に検証する
  - SCREAMING_SNAKE_CASE で命名を統一（例: `DATABASE_URL`, `API_BASE_URL`）
  - 環境変数のプレフィックスでスコープを明示（例: `NEXT_PUBLIC_` でクライアント公開、`DB_` でデータベース関連）
- **2025-2026年のトレンド**:
  - `@t3-oss/env-nextjs` による型安全な環境変数管理が Next.js プロジェクトで標準化
  - Infisical, Doppler 等の環境変数管理 SaaS の採用が増加。チーム間での設定共有を効率化
  - `.env` のランタイムバリデーションが「あると良い」から「必須プラクティス」に格上げ
  - 12-Factor App の原則に従い、設定をコードから完全に分離する方針が再確認されている

### 7. エイリアスパス設定

- **何を決めるか**: import 文で使用するパスエイリアスの設定方法と命名規則
- **選択肢**:
  - **tsconfig paths**: `tsconfig.json` の `compilerOptions.paths` で `@/` や `@features/` 等のエイリアスを定義
  - **Bundler alias**: Vite（`resolve.alias`）, webpack（`resolve.alias`）で設定
  - **Import map（Node.js）**: `package.json` の `imports` フィールドで `#` プレフィックスのサブパスインポートを定義
- **選定基準**:
  - ツールチェーンとの整合性：tsconfig paths を設定しても、バンドラーやテストランナーに別途設定が必要な場合がある
  - エディタサポート：tsconfig paths は VS Code の IntelliSense と自動インポートに直接反映される
  - 標準準拠：Node.js の subpath imports（`#` プレフィックス）は package.json ベースで標準的
- **トレードオフ・注意点**:
  - tsconfig paths とバンドラーの alias が乖離すると、エディタでは解決できるがビルドで失敗するケースが発生
  - Vite は `vite-tsconfig-paths` プラグインで tsconfig.json の paths を自動反映可能
  - Jest は `moduleNameMapper` での追加設定が必要。`ts-jest` の `pathsToModuleNameMapper` で自動生成可能
  - エイリアスの乱用は依存関係の把握を困難にする。`@/` はプロジェクトルート、`@features/` は features ディレクトリ等、少数に限定
- **2025-2026年のトレンド**:
  - `@/` をプロジェクト src/ ルートに対応させる設定が事実上の標準（Next.js, Nuxt が初期設定で採用）
  - Node.js の subpath imports（`#` プレフィックス）の採用が増加。package.json の `imports` フィールドは tsconfig paths 不要で動作
  - Vitest は tsconfig paths を自動認識するため追加設定不要（Vite ベースのテストランナーの利点）
  - モノレポでは各パッケージの package.json `exports` と tsconfig paths の組み合わせが推奨構成
