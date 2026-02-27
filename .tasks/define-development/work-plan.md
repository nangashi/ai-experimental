# 開発前決定事項の調査 - 作業計画

## 目的

新規開発プロジェクト（クロスデバイス対応リーディングリスト管理ツール）を安定した開発プロセスに乗せる前に決めるべき事項を網羅的に調査する。

## カテゴリ構成

調査をカテゴリ別に分割し、並列でリサーチする。

### Group A: 技術スタック・システムアーキテクチャ
- `01-technology-stack.md` — 言語、フレームワーク、DB、ランタイム、パッケージマネージャ
- `02-system-architecture.md` — アーキテクチャパターン、レイヤー分離、API設計

### Group B: プロジェクト構成・コーディング規約・DX
- `03-project-structure.md` — ディレクトリ構成、モノレポvs分割、モジュール境界
- `04-coding-standards.md` — Linter/Formatter、命名規則、型定義、コメント方針
- `05-developer-experience.md` — ローカル開発環境、デバッグ、AIコーディング支援

### Group C: 開発プロセス・CI/CD・インフラ
- `06-development-process.md` — Gitワークフロー、ブランチ戦略、コードレビュー、リリースプロセス
- `07-cicd-infrastructure.md` — CI/CDパイプライン、ホスティング、環境管理、IaC

### Group D: テスト戦略・データ管理
- `08-testing-strategy.md` — テストレベル、フレームワーク、カバレッジ、テストデータ
- `09-data-management.md` — スキーマ設計、マイグレーション、バックアップ

### Group E: セキュリティ・監視・運用
- `10-security.md` — 認証認可、シークレット管理、入力検証、依存脆弱性
- `11-monitoring-operations.md` — ログ戦略、エラー追跡、パフォーマンス監視

### Group F: フロントエンド設計・クロスデバイス・AI統合
- `12-frontend-design.md` — 状態管理、ルーティング、コンポーネント設計、スタイリング
- `13-cross-device-strategy.md` — レスポンシブ、PWA、モバイル対応
- `14-ai-integration.md` — Claude API統合パターン、プロンプト管理、コスト制御

### Group G: 失敗事例・教訓
- `15-failure-lessons.md` — AI開発・個人開発の失敗事例、決定不足による問題

### Group H: 既存スキル参照
- arch_design, process_design スキルの構造から得られる知見

## フロー

1. 作業計画作成（本ファイル）
2. Group A〜G を並列リサーチ（各カテゴリをファイル出力）
3. Group H: 既存スキル参照
4. 全カテゴリの横断レビュー（不足・重複の検出）
5. サマリ作成
