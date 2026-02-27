# CI/CD・インフラ

## 決定事項一覧（サマリテーブル）

| # | 決定項目 | 主な選択肢 | 決定の影響範囲 |
|---|---------|-----------|--------------|
| 1 | CI/CDプラットフォーム | GitHub Actions / GitLab CI / CircleCI / Jenkins | 開発ワークフロー全体、自動化の範囲 |
| 2 | CIパイプライン構成 | lint → test → build → deploy の設計と最適化 | ビルド時間、品質担保レベル |
| 3 | CDの戦略 | 自動デプロイ / 手動承認 / ロールバック方式 | リリース速度、安全性 |
| 4 | ホスティングプラットフォーム | Vercel / Cloudflare Pages / Fly.io / Railway / AWS等 | コスト、スケーラビリティ、DX |
| 5 | コンテナ化の採否 | Docker / docker-compose / コンテナなし | 環境再現性、デプロイ方式 |
| 6 | IaC（Infrastructure as Code）の採否 | Terraform / Pulumi / SST / 不採用 | インフラ管理の再現性・自動化 |
| 7 | 環境管理 | dev / staging / prod の分離戦略 | テスト信頼性、コスト、運用複雑度 |
| 8 | ドメイン・DNS管理 | Cloudflare / Route 53 / プラットフォーム統合 | ルーティング、可用性 |
| 9 | SSL/TLS証明書管理 | 自動（Let's Encrypt / プラットフォーム提供） / 手動 | セキュリティ、運用負荷 |
| 10 | CDN設定 | Cloudflare / Vercel Edge / CloudFront / 不要 | パフォーマンス、グローバル配信 |
| 11 | シークレット管理（CI/CD内） | GitHub Secrets / 外部Vault / 環境変数 | セキュリティ、運用安全性 |

## 各項目の詳細

### 1. CI/CDプラットフォーム

- **何を決めるか**: CI/CDの実行基盤。ワークフロー定義の方法、実行環境、コスト構造。
- **選択肢**:
  - **GitHub Actions**: GitHub ネイティブ統合。YAML ベースのワークフロー定義。豊富なMarketplace。無料枠: パブリックリポジトリ無制限、プライベートリポジトリ2,000分/月。
  - **GitLab CI/CD**: GitLab 統合。`.gitlab-ci.yml` で定義。Auto DevOps 機能。400分/月の無料枠。
  - **CircleCI**: 高速なビルド。Docker レイヤーキャッシュ。6,000分/月の無料枠。
  - **Jenkins**: 完全セルフホスト。1,800+プラグイン。無料だがインフラ管理コストが発生。
- **選定基準**:
  - コードホスティングとの統合（GitHub使用→GitHub Actions が最も自然）
  - 無料枠の範囲（個人開発ではコスト重要）
  - カスタマイズ性の要求度（極度のカスタマイズ→Jenkins、標準的→GitHub Actions）
  - セルフホストランナーの要否（特殊なビルド環境→自前ランナー）
- **トレードオフ・注意点**:
  - GitHub Actions はパブリックリポジトリでは無制限だが、プライベートリポジトリでは分数制限がある
  - Jenkins は運用・メンテナンスコスト（アップデート、セキュリティ、プラグイン互換性）が高い
  - セルフホストランナーをパブリックリポジトリで使用すると、悪意のあるコードがパイプラインに注入されるリスクがある
  - Marketplace のサードパーティActionのセキュリティリスク（2025年3月の tj-actions/changed-files インシデント: 23,000+リポジトリのシークレットが漏洩）
- **2025-2026年のトレンド**:
  - GitHub Actions が CI/CD のデファクトスタンダードに。GitHub ユーザー間での採用率が最も高い
  - Agentic CI/CD の登場: GitHubがAIエージェントをCI/CDループに統合。Issueイベントをトリガーにエージェントがワークフローを自動実行
  - Dagger（ポータブルCI/CDエンジン）やEarthly（コンテナベースビルド）など、CI/CDの抽象化レイヤーも注目されている
  - セキュリティ・シフトレフト: CI パイプライン内にSAST/DAST/依存関係スキャンを組み込むのが標準に

### 2. CIパイプライン構成

- **何を決めるか**: パイプラインのステージ構成、各ステージの実行条件、並列化戦略、キャッシュ戦略。
- **選択肢**:
  - **基本構成**:
    ```
    lint → type-check → unit-test → integration-test → build → deploy
    ```
  - **高速化構成（並列実行）**:
    ```
    ┌─ lint
    ├─ type-check      → build → deploy
    ├─ unit-test
    └─ security-scan
    ```
  - **モノレポ構成**: 変更されたパッケージのみを対象にビルド・テスト（Turborepo, Nx）
  - **キャッシュ戦略**:
    - 依存パッケージのキャッシュ（`node_modules`, `pip cache`等）
    - ビルド成果物のキャッシュ（Next.js `.next/cache`等）
    - Docker レイヤーキャッシュ
- **選定基準**:
  - フィードバックループの速度（lint/型チェックは秒単位で返るべき）
  - テストの種類と実行時間（ユニットテスト: 高速、E2E: 低速で分離）
  - コスト（並列実行は分数を消費、キャッシュで相殺）
- **トレードオフ・注意点**:
  - 「全部直列」は安全だが遅い。「全部並列」は速いがリソース消費が多い
  - E2Eテストはマージ前に毎回走らせると時間がかかるため、mainブランチへのマージ後またはデプロイ前に限定するのも有効
  - キャッシュの無効化条件を適切に設定しないと、古いキャッシュで誤ったビルドが通るリスクがある
  - ワークフローファイルは明確でモジュラーに。`build-and-test.yml`, `deploy-prod.yml` のように分離
  - マトリクスビルド（複数のNode.jsバージョン、OS等でのテスト）は必要な範囲に限定
- **2025-2026年のトレンド**:
  - AI によるテスト影響分析（変更に関連するテストのみを実行）で CI 時間を短縮
  - Remote Build Cache (Turborepo, Nx Cloud) によるビルド時間の劇的な短縮
  - GitHub Actions の Larger Runners や Arm64 ランナーによるビルド高速化
  - セキュリティスキャン（CodeQL, Trivy, Snyk）の CI への標準組み込み
  - `actions/dependency-review-action` による依存関係の脆弱性チェックがブロッキングステップとして一般化

### 3. CDの戦略

- **何を決めるか**: デプロイのトリガー方式、環境ごとのデプロイ戦略、ロールバック手順。
- **選択肢**:
  - **デプロイトリガー**:
    - **自動デプロイ**: mainブランチへのマージで自動的に本番デプロイ
    - **手動承認付き自動デプロイ**: stagingまでは自動、本番は手動承認後にデプロイ
    - **手動トリガー**: GitHub Actions の `workflow_dispatch` やリリースタグのプッシュで手動実行
    - **GitOps**: インフラ定義の変更をGitにpushすると自動的にデプロイ（ArgoCD, Flux）
  - **デプロイ戦略**:
    - **ローリングデプロイ**: 段階的にインスタンスを更新
    - **Blue-Green デプロイ**: 新旧2つの環境を切り替え
    - **カナリアデプロイ**: 一部のトラフィックに新バージョンを配信し、問題なければ全体に展開
    - **Immutable Deploy**: 新しいデプロイのたびに新しい環境/コンテナを作成（Vercel, Cloudflare Pages のプレビューデプロイ）
  - **ロールバック**:
    - 即座に前バージョンにロールバック（Vercel の Instant Rollback等）
    - Git revert + 再デプロイ
    - Blue-Greenの切り戻し
- **選定基準**:
  - 障害時の復旧速度要件（即座→Blue-Green/Immutable、数分→ローリング）
  - プロダクトのリスクレベル（高リスク→カナリア + 手動承認、低リスク→自動デプロイ）
  - インフラの複雑度許容度
- **トレードオフ・注意点**:
  - 完全自動デプロイはCI/CDの信頼性（テストカバレッジ、品質ゲート）が前提
  - カナリアデプロイはトラフィック分割の仕組みが必要で、実装コストが高い
  - ロールバック手順は事前にテストしておくことが必須。未テストのロールバックは障害を拡大させるリスクがある
  - DBマイグレーションを伴うデプロイはロールバックが複雑になる。前方互換性のあるマイグレーション戦略が重要
  - Vercel/Cloudflare Pages等のプラットフォームはImmutable Deployをデフォルトで提供し、ロールバックが容易
- **2025-2026年のトレンド**:
  - PaaS/エッジプラットフォーム（Vercel, Cloudflare）のImmutable Deploy + Instant Rollbackが標準に
  - Progressive Delivery（Feature Flags + カナリア + 自動ロールバック）の統合プラットフォームの普及
  - GitOps の採用拡大（特にKubernetes環境）
  - AI による異常検知と自動ロールバックの統合

### 4. ホスティングプラットフォーム

- **何を決めるか**: アプリケーションの実行基盤。静的/SSR/API/データベースそれぞれの配置先。
- **選択肢**:
  - **Vercel**: Next.js 公式。Edge Functions。自動プレビューデプロイ。Pro: $20/user/月。個人: 無料枠あり。
  - **Cloudflare Pages/Workers**: エッジコンピューティング。Workers: 100,000リクエスト/日無料。Pages: 無制限帯域。D1(SQLite), KV, R2(S3互換)等のエッジストレージ。
  - **Fly.io**: コンテナベース。リージョン選択可能。PostgreSQL統合。$5/月のHobby Plan。
  - **Railway**: コンテナベース。DB同居可能。シンプルな料金体系（CPU/メモリ使用量課金）。$5/月のHobby。
  - **Render**: Herokuの後継的立ち位置。無料枠あり（スリープあり）。Web Service + PostgreSQL。
  - **AWS (ECS/Lambda/Amplify)**: フルマネージド〜フルコントロール。学習曲線が高い。従量課金。
  - **Google Cloud Run**: コンテナベースサーバーレス。従量課金。200万リクエスト/月無料。
- **選定基準**:
  - アプリケーションのアーキテクチャ（静的→Cloudflare Pages/Vercel、SSR→Vercel/Fly.io、API→Railway/Fly.io）
  - フレームワーク（Next.js→Vercel最適、Hono/Remix→Cloudflare Workers最適）
  - スケール要件（グローバル配信→Cloudflare/Vercel Edge、リージョン固定→Fly.io/Railway）
  - DB との親和性（同居→Railway/Fly.io、マネージドDB→各プラットフォームの付帯サービス）
  - コスト構造（チーム規模、トラフィック量、予算）
  - ベンダーロックインの許容度（低→コンテナベース(Fly.io/Railway)、許容→Vercel/Cloudflare）
- **トレードオフ・注意点**:
  - Vercel は DX が最高だが「Vercel Tax」（チームメンバー追加でコスト増、2人目から$40/月）がある
  - Cloudflare Workers は V8 Isolate ベースのため、Node.js API の一部が使えない。エコシステムの互換性確認が必要
  - Fly.io はコンテナ運用の知識（イメージ、ボリューム、ネットワーク）が必要
  - Railway はコスト予測が容易だが、大規模トラフィックでのコスト最適化は AWS に劣る
  - PaaS からの移行コストを考慮する。標準的なコンテナ/Dockerfileベースなら移行が容易
- **2025-2026年のトレンド**:
  - エッジコンピューティングの主流化。Cloudflare Workers/Vercel Edge Functions でのサーバーサイド処理が拡大
  - Cloudflare のフルスタック化（D1, R2, KV, Queues, AI等）が急速に進展。「Cloudflare で完結する」アーキテクチャが現実的に
  - Railway の人気急上昇。「Heroku の正統後継」として開発者コミュニティで支持
  - マルチクラウド/ハイブリッドよりも「一つのプラットフォームで完結」する志向が強い
  - Vercel は Next.js 以外のフレームワーク対応を強化（Remix, SvelteKit, Nuxt等）
  - コスト最適化の観点から、初期は PaaS で始めて規模拡大時にコンテナ/クラウドに移行するパスが推奨

### 5. コンテナ化の採否

- **何を決めるか**: Docker/コンテナを開発・デプロイに採用するかどうか。採用する場合のスコープ。
- **選択肢**:
  - **フルコンテナ化**: 開発環境（docker-compose） + CI/CD + 本番デプロイすべてをコンテナ化
  - **デプロイのみコンテナ化**: ローカル開発はネイティブ、デプロイ時のみDockerイメージをビルド
  - **開発環境のみコンテナ化**: ローカル開発のDB/Redis等の依存サービスをdocker-compose、アプリ本体はネイティブ
  - **コンテナなし**: PaaS（Vercel, Cloudflare Pages等）にフレームワークネイティブでデプロイ
  - **Dev Containers**: VS Code / GitHub Codespaces 用の開発環境コンテナ
- **選定基準**:
  - デプロイ先の要件（コンテナ必須のプラットフォーム→Fly.io, Cloud Run、不要→Vercel, Cloudflare）
  - 開発環境の再現性要件（チーム開発→高い、個人開発→低い）
  - 依存サービスの複雑さ（DB + Redis + キュー→docker-compose有効、単純構成→不要）
  - 学習コストの許容度
- **トレードオフ・注意点**:
  - Docker はビルド時間とイメージサイズの管理が必要。マルチステージビルド、最小ベースイメージ（Alpine/Distroless）の使用が推奨
  - PaaS プラットフォーム（Vercel, Cloudflare）ではコンテナ不要で、フレームワークのビルドコマンドだけで完結する
  - ローカル開発でDockerを使うと、ファイルシステム同期のパフォーマンス問題（特にmacOS）がある
  - セキュリティ: rootユーザーを避ける、Trivy/Docker Scoutでイメージスキャン、シークレットをイメージに埋め込まない
  - 各コンテナは1つの関心事のみを扱う（Single Responsibility）
- **2025-2026年のトレンド**:
  - 92%のIT組織がコンテナを利用。Docker の開発者採用率は約71%
  - ただし Webアプリ開発では「コンテナ不要」のPaaS/エッジプラットフォームが台頭し、コンテナを意識しないデプロイが増加
  - Dev Containers + GitHub Codespaces による開発環境の標準化が拡大
  - Docker のAI統合（docker ai コマンド、Docker MCP Toolkit）
  - Distroless / Chainguard イメージによるセキュリティ強化が標準プラクティスに

### 6. IaC（Infrastructure as Code）の採否

- **何を決めるか**: インフラ構成をコードで管理するかどうか。採用する場合のツール選定。
- **選択肢**:
  - **Terraform**: HCL（独自DSL）。3,000+プロバイダー。市場シェア32.8%（2026年）。最大のエコシステム。
  - **OpenTofu**: Terraform のOSSフォーク（HashiCorpライセンス変更への対応）。Terraform互換。Linux Foundation管理。
  - **Pulumi**: TypeScript/Python/Go等の汎用言語でインフラ定義。1,800+プロバイダー。年45%成長。
  - **SST (Serverless Stack)**: TypeScript特化。AWSサーバーレスに最適化。高レベル抽象化（Next.jsデプロイ=1リソース宣言）。
  - **AWS CDK**: TypeScript/Python等。AWS専用。CloudFormationに変換。
  - **不採用**: PaaS のダッシュボード/CLI で管理。小規模プロジェクトでは十分な場合もある。
- **選定基準**:
  - インフラの複雑さ（単純→PaaS管理で十分、複雑→IaC必須）
  - チームの言語スキル（TypeScript→Pulumi/SST、HCL習得可→Terraform）
  - クラウドプロバイダー（AWS専用→SST/CDK、マルチクラウド→Terraform/Pulumi）
  - エコシステムの成熟度要件（最大→Terraform、モダン→Pulumi）
  - ベンダーロックインの許容度
- **トレードオフ・注意点**:
  - Terraform は HCL の学習コストがあるが、エコシステムが最も充実。状態管理（tfstate）の扱いに注意
  - Pulumi は汎用言語で書けるため開発者にとって敷居が低いが、コミュニティはTerraformに比べ小さい
  - SST は AWS サーバーレスに特化しており、対象が限定的。Next.js/Remix等のデプロイは非常に簡潔
  - PaaS（Vercel, Railway等）を使う場合、IaCが不要になるケースも多い
  - OpenTofu は Terraform からの移行先として注目されているが、エコシステムの分断リスクがある
  - 状態ファイルの管理（リモートバックエンド: S3, Terraform Cloud等）の設計が重要
- **2025-2026年のトレンド**:
  - Terraform が依然として市場リーダーだが、BSLライセンス変更を受けてOpenTofuへの移行が進行中
  - Pulumi の急成長（年45%）。TypeScript開発者にとっての自然な選択肢に
  - SST v3 の成熟。AWSサーバーレスアプリのデファクト IaC ツールとしての地位を確立
  - 「IaCを使わない」選択肢（PaaS依存）も小規模プロジェクトでは合理的な選択として認知
  - AI によるIaCコード生成（自然言語からインフラ定義を生成）が実用段階に

### 7. 環境管理

- **何を決めるか**: 開発（dev）・ステージング（staging）・本番（prod）の分離方法と運用ルール。
- **選択肢**:
  - **3環境分離（標準）**:
    - **dev**: ローカル開発環境。docker-compose や PaaS のプレビューデプロイ。
    - **staging**: 本番ミラー環境。本番デプロイ前の最終検証。本番と同じ構成。
    - **prod**: ユーザー向け本番環境。高可用性・スケーリング設定。
  - **2環境分離（簡易）**:
    - **dev/preview**: PRごとのプレビューデプロイ（Vercel Preview, Cloudflare Preview）
    - **prod**: 本番環境
  - **環境ごとの設定管理**:
    - 環境変数で切り替え（`.env.development`, `.env.production`）
    - プラットフォームの環境変数管理（Vercel Environment Variables, GitHub Environments）
    - Feature Flags で環境差異を吸収
- **選定基準**:
  - プロジェクトの規模とリスク（大規模/高リスク→3環境、小規模/個人→2環境）
  - コスト（staging環境の維持コスト）
  - デプロイ頻度（高頻度→Preview Deploy で staging を代替可能）
  - データの機密性（本番データをstagingで使う場合のマスキング要否）
- **トレードオフ・注意点**:
  - staging 環境を本番と完全に同一にするのはコストがかかる。差異があるとstaging通過後のprod障害が起こりうる
  - Vercel/Cloudflare Pages のプレビューデプロイは PR 単位で自動生成され、staging の代替として使える
  - 環境変数のハードコーディングは厳禁。APIキー等は必ず環境変数で注入
  - 本番データのstagingへのコピーは個人情報保護の観点から注意が必要（マスキング/匿名化）
  - IaCで環境を定義すると、同一定義から複数環境を再現できる
- **2025-2026年のトレンド**:
  - Preview Deploy（PRごとのプレビュー環境）が staging の実質的な代替になりつつある
  - Ephemeral Environments（一時的な環境を PR やブランチごとに自動生成・破棄）の普及
  - IaC + 環境変数で環境差分を最小化し、同一コードベースから全環境をデプロイ
  - Feature Flags による環境間の機能差異管理が主流に
  - docker-compose でローカル開発環境を定義し、 `docker compose up` で全依存を起動するパターンが標準

### 8. ドメイン・DNS管理

- **何を決めるか**: ドメインの取得先、DNS管理の方法、サブドメイン戦略。
- **選択肢**:
  - **ドメイン取得先**: Cloudflare Registrar / Google Domains (Squarespace) / Namecheap / AWS Route 53
  - **DNS管理**:
    - **Cloudflare DNS**: 無料。グローバルAnycast。DNSSEC対応。DDoS防御統合。
    - **AWS Route 53**: 従量課金。AWS統合。ヘルスチェック + フェイルオーバー。
    - **プラットフォーム統合DNS**: Vercel DNS, Netlify DNS（プラットフォームに最適化）
  - **サブドメイン戦略**:
    - `app.example.com`（本番）/ `staging.example.com`（ステージング）/ `api.example.com`（API）
    - ワイルドカードDNS（`*.example.com`）でプレビューデプロイに対応
- **選定基準**:
  - 他のインフラとの統合（Cloudflare利用→Cloudflare DNS、AWS利用→Route 53）
  - コスト（Cloudflare DNS: 無料、Route 53: $0.50/ゾーン/月 + クエリ課金）
  - 高度なルーティング要件（ジオロケーション、フェイルオーバー→Route 53）
  - 管理の容易さ
- **トレードオフ・注意点**:
  - ドメイン取得先とDNS管理を同じプロバイダーにすると管理が簡単
  - DNS の TTL 設定は切り替え時に影響。通常は300秒〜3600秒
  - DNSSEC の有効化を推奨（DNS応答の改ざん防止）
  - ドメインの自動更新を有効にし、期限切れを防止
- **2025-2026年のトレンド**:
  - Cloudflare が DNS + CDN + セキュリティ + エッジコンピューティングの統合プラットフォームとしてデファクトに
  - HTTPS DNS レコード（SVCB/HTTPS）の普及。HTTP/3 への即座の接続を DNS レベルで広告
  - Google Domains の Squarespace への移管後、Cloudflare Registrar への移行が増加

### 9. SSL/TLS証明書管理

- **何を決めるか**: SSL/TLS証明書の取得・更新方法、暗号化モード。
- **選択肢**:
  - **プラットフォーム自動管理**: Vercel, Cloudflare, Netlify 等が自動で証明書を発行・更新。設定不要。
  - **Let's Encrypt + certbot**: 無料。90日ごとの自動更新。自前サーバー向け。
  - **Cloudflare SSL**: 無料。4つのモード（Off / Flexible / Full / Full Strict）。オリジン証明書も無料発行。
  - **AWS ACM (Certificate Manager)**: 無料（AWS サービスとの統合時）。自動更新。
- **選定基準**:
  - ホスティングプラットフォームの提供機能（PaaS→自動管理で十分）
  - オリジンサーバーの暗号化要件（エンドツーエンド暗号化→Full Strict推奨）
  - 証明書の管理負荷を最小化したいか
- **トレードオフ・注意点**:
  - Cloudflare の Flexible モードはエッジ〜オリジン間が暗号化されないため、本番環境では Full (Strict) を推奨
  - Let's Encrypt の証明書は90日有効。自動更新の仕組みが必須（certbot timer, cron）
  - ワイルドカード証明書（`*.example.com`）はDNS認証が必要
  - PaaS を使う場合、SSL/TLS は完全に自動化されており意識する必要がほぼない
- **2025-2026年のトレンド**:
  - TLS 1.3 の採用率が急伸（エッジトラフィックの約60%）。TLS 1.2以前の廃止が進む
  - Cloudflare が自動的に量子コンピュータ耐性暗号（Post-Quantum Cryptography）を有効化。600万ドメインをアップグレード
  - 「証明書管理をゼロにする」PaaS/エッジプラットフォームの利用が主流
  - mTLS（相互TLS認証）のゼロトラストセキュリティへの統合が進展

### 10. CDN設定

- **何を決めるか**: CDNの採否、プロバイダー選定、キャッシュ戦略。
- **選択肢**:
  - **Cloudflare CDN**: 無料プランでグローバルCDN。330+拠点。HTTP/3, Brotli圧縮。キャッシュルール設定可能。
  - **Vercel Edge Network**: Vercelに統合。自動最適化。ISR (Incremental Static Regeneration) 対応。
  - **AWS CloudFront**: 従量課金。Lambda@Edge/CloudFront Functions でカスタムロジック。
  - **プラットフォーム統合**: Vercel, Cloudflare Pages, Netlify等はCDNが組み込み済み。追加設定不要。
  - **CDN不要**: ローカルアプリ、社内ツール、リージョン限定サービス
- **選定基準**:
  - ターゲットユーザーの地理的分布（グローバル→CDN必須、国内限定→オプション）
  - 静的アセットの量と更新頻度
  - コスト（Cloudflare: 無料帯域無制限、CloudFront: 従量課金）
  - カスタムキャッシュロジックの要否
- **トレードオフ・注意点**:
  - PaaS（Vercel, Cloudflare Pages）を使う場合、CDNは自動的に含まれるため別途設定不要
  - キャッシュの無効化（パージ）戦略を事前に設計。コンテンツ更新時にキャッシュが残ると古い情報が配信される
  - Cache-Control ヘッダーの適切な設定（静的アセット: 長期キャッシュ + ハッシュ付きファイル名、API: no-cache or short TTL）
  - CDN はセキュリティ層（DDoS防御、WAF、Bot管理）としても機能する
- **2025-2026年のトレンド**:
  - CDN がプロトコル進化の先導役に。HTTP/3 採用率: CDN経由69% vs オリジン直接5%未満
  - エッジコンピューティングとCDNの融合（Cloudflare Workers, Vercel Edge Functions）
  - 画像最適化のCDN統合（Cloudflare Images, Vercel Image Optimization）が標準に
  - CDN = 「ただのキャッシュ」から「エッジアプリケーションプラットフォーム」への進化

### 11. シークレット管理（CI/CD内）

- **何を決めるか**: API キー、データベース認証情報、トークン等のシークレットの保管・注入方法。
- **選択肢**:
  - **GitHub Secrets**: GitHub に暗号化保存。リポジトリ/環境/Organization レベルで管理。`${{ secrets.NAME }}` で参照。
  - **GitHub Environments**: 環境（staging, production）ごとにシークレットを分離。手動承認ルール設定可能。
  - **外部シークレットマネージャー**: HashiCorp Vault, AWS Secrets Manager, 1Password for CI。動的シークレット生成・自動ローテーション。
  - **Doppler / Infisical**: シークレット管理SaaS。環境間の同期、変更履歴、アクセスログ。
- **選定基準**:
  - シークレットの数と複雑さ（少数→GitHub Secrets で十分、多数→外部マネージャー）
  - シークレットローテーションの要件（自動ローテーション要→外部マネージャー）
  - 監査要件（アクセスログ必要→外部マネージャー or GitHub Audit Log）
  - コスト（GitHub Secrets: 無料、外部サービス: 有料）
- **トレードオフ・注意点**:
  - GitHub Secrets はリポジトリ管理者なら誰でもシークレットを設定・変更できる。最小権限の原則を適用
  - 環境シークレット（Environment Secrets）はリポジトリシークレットより厳格なアクセス制御が可能。本番用は環境シークレットを推奨
  - **2025年3月の tj-actions/changed-files インシデント**: サードパーティ Action が侵害され、23,000+リポジトリのシークレットが漏洩。CI内のシークレットは環境変数として注入されるため、ワークフローが侵害されると抜き取られるリスクがある
  - Organization シークレットは全リポジトリに適用されるため、スコープを最小限に
  - `.env` ファイルや認証情報をGitにコミットしない（`.gitignore` の徹底）
  - GitHub Actions のログでシークレット値は自動マスクされるが、加工された値は漏洩する可能性がある
- **2025-2026年のトレンド**:
  - **Secretless Authentication（シークレットレス認証）**の台頭。保存されたシークレットの代わりに、ワークロードIDに紐づく一時的な認証情報を動的に生成。OIDC トークン認証の採用拡大
  - GitHub OIDC（`id-token: write`）で AWS / GCP / Azure にシークレットなしで認証するパターンが標準に
  - シークレットの自動ローテーションをCI/CDパイプラインに統合
  - サプライチェーンセキュリティの意識向上。サードパーティ Action のピン留め（SHA指定）が必須プラクティスに
  - Sigstore / cosign によるアーティファクト署名の標準化
