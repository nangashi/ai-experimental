# AI支援開発プロセス: フェーズ設計

## ステータス

Draft

## 日付

2026-02-19

## 背景

Spec-Driven Development (SDD) の調査結果に基づき、AI支援開発における文書駆動型フェーズ分割を設計する。各フェーズがMarkdown成果物を生成し、次フェーズの入力となる構造とする。

### 設計原則

- **各セッションを純粋関数として扱う**: ファイルを入力に読み、ファイルを出力に書き、会話履歴に依存しない
- **コンテキスト境界 = フェーズ境界**: フェーズ間は成果物ファイルのみで接続
- **1タスク = 1セッション**: 実装フェーズでは steering + design + 1タスク のみをコンテキストに載せる

### 主な情報源

- Thoughtworks: Spec-Driven Development (2025年の主要エンジニアリングプラクティス)
- JetBrains: Spec-Driven Approach for AI Coding
- Google: Conductor (Context-Driven Development for Gemini CLI)
- Pimzino/claude-code-spec-workflow (Claude Code向け実装例)
- Addy Osmani: LLM Coding Workflow Going into 2026

## フェーズ一覧

```
Phase 0  要求引出        → docs/project-definition/problem-statement.md     ✅ /requirement_elicit
Phase 1  要件定義        → docs/requirements.md          ✅ /requirement_define
Phase 2  アーキテクチャ設計 → docs/design.md + docs/adr/   🆕 新規スキル
Phase 3  タスク分解       → docs/tasks.md                 🆕 新規スキル
Phase 4  実装 (per task) → コード + git commit            ⚠️ 既存を拡張
Phase 5  検証・統合       → テスト結果 + レビュー          🆕 新規スキル
```

## コンテキスト境界

| フェーズ間 | 次セッションが読む入力 | 推定サイズ | 境界の根拠 |
|-----------|---------------------|-----------|-----------|
| 0→1 | problem-statement.md | ~150行 | 要求と要件は関心事が異なる（What vs How much） |
| 1→2 | requirements.md | ~250行 | アーキテクチャ設計は要件全体を参照。技術選定は別セッションに委譲 |
| 2→3 | design.md | ~200行 | 設計文書からタスクを導出。要件は設計に内包済み |
| 3→4 | design.md + 1タスク | ~250行 | **最も重要な境界**。各タスクが独立セッション |
| 4→5 | design.md + テスト計画 | ~300行 | 実装完了後の検証は別関心事 |

## 各フェーズ詳細

### Phase 0: 要求引出 (`/requirement_elicit` — 既存)

- **入力**: ユーザーとの対話
- **出力**: `docs/project-definition/problem-statement.md`
- **処理内容**: AI駆動の対話で6カテゴリの要求を深掘り
- **コンテキスト設計**: 対話ベースのため1セッション内で完結

### Phase 1: 要件定義 (`/requirement_define` — 既存)

- **入力**: `docs/project-definition/problem-statement.md`
- **出力**: `docs/requirements.md`
- **処理内容**: ギャップ分析 → システム境界 → 機能要件(EARS) → NFR定量化 → IF要件 → 品質ゲート
- **コンテキスト設計**: 6段階の品質ゲートを含むため1セッションのコンテキストを相応に消費

### Phase 2: アーキテクチャ設計 (`/arch_design` — 新規)

- **入力**: `docs/requirements.md`
- **出力**: `docs/design.md` + `docs/adr/`（技術選定ADR群、副産物）
- **処理内容**:
  1. 要件を読み込み、ユーザーと対話しながらアーキテクチャを設計
  2. 技術選定が必要な判断ポイントに到達したら、制約を含む `/adr_create` コマンドをユーザーに提示し、別セッションでの実行を促す
     - 例: 「以下のコマンドを別セッションで実行してください: `/adr_create DB選定。制約: イベントソーシングパターンを採用予定、書き込み負荷が高い、月額$50以下`」
  3. ADR結果（`docs/adr/*.md`）を読み込み、技術決定を前提として設計を継続
  4. データモデル定義（ER図/スキーマ）
  5. コンポーネント分割とインターフェース契約
  6. ディレクトリ構造の設計
  7. 多観点レビュー（既存の `issue_design` Phase 3 のレビューパターンを再利用）
- **コンテキスト設計**: 技術選定の重い処理（Web検索・候補比較）は別セッションの `/adr_create` に委譲するため、本セッションはADRの結論部分のみ読み込めばよくコンテキスト効率が良い。レビューは5観点並列サブエージェントで行い親のコンテキストは軽く保つ

### Phase 3: タスク分解 (`/task_plan` — 新規)

- **入力**: `docs/design.md`
- **出力**: `docs/tasks.md`（順序付き実装タスクリスト）
- **処理内容**:
  1. design.md のコンポーネント・インターフェースから実装単位を導出
  2. 依存関係の分析と実装順序の決定
  3. 各タスクに「完了条件」「参照すべきdesign.mdセクション」「推定影響ファイル」を付与
  4. タスク粒度の調整（1タスク = 1セッションで完了可能なサイズ）
- **コンテキスト設計**: design.md (~200行) を全量読んで分解するため、1セッションで完結する軽量スキル

### Phase 4: 実装 (`/task_implement` — 新規 or `/issue_implement` 拡張)

- **入力**: `docs/design.md` + `docs/tasks.md` の1タスク
- **出力**: コード + git commit
- **処理内容**:
  1. タスク1つを読み込み、関連するdesign.mdセクションを参照
  2. 既存コードベースの調査
  3. 実装 + テスト作成
  4. commit + タスク完了マーク
- **コンテキスト設計**: **1タスク = 1セッション** がSDDの核心。design.md全体 + 1タスクの説明だけをコンテキストに載せ、他タスクの知識は不要。既存の `/issue_implement` はGitHub Issue起点だが、タスクファイル起点に変更するか別スキルにするか選択が必要

### Phase 5: 検証・統合 (`/verify` — 新規)

- **入力**: `docs/design.md` + 実装済みコード
- **出力**: テスト結果レポート + 設計との乖離レポート
- **処理内容**:
  1. 全テスト実行
  2. design.md の要件トレーサビリティチェック（SR → 実装の対応確認）
  3. NFR検証（パフォーマンス計測、セキュリティチェック）
  4. 設計と実装の乖離があればdesign.md/decisions.mdを更新
- **コンテキスト設計**: テスト実行結果がコンテキストを消費するため、NFR検証はカテゴリ別にサブエージェントに委譲

## 既存スキルとの関係

| 既存スキル | 本パイプラインでの位置 | 対応 |
|-----------|---------------------|------|
| `/requirement_elicit` | Phase 0 | そのまま使用 |
| `/requirement_define` | Phase 1 | そのまま使用 |
| `/adr_create` | Phase 2 で都度呼出 | ユーザーが別セッションで手動実行。アーキテクチャスキルが制約付きコマンドを提示 |
| `/issue_design` | Phase 2 の参考 | レビュー基盤（5観点並列レビュー）を転用 |
| `/issue_implement` | Phase 4 の参考 | GitHub Issue起点 → タスクファイル起点に適応 |
| `/dev` | Phase 4 の実行エンジン | 自律実行の品質原則を転用可能 |

## スキル化の優先度

プロジェクト進行順に合わせて順次スキル化する:

1. **Phase 2: `/arch_design`** — 最初に必要。技術選定は既存の `/adr_create` で対応
2. **Phase 3: `/task_plan`** — 比較的軽量。Phase 2の直後に実施可能
3. **Phase 4: `/task_implement`** — タスク数に比例して繰り返し実行
4. **Phase 5: `/verify`** — 実装完了後 or スプリント単位

## 未解決事項

- [ ] Phase 4 を `/issue_implement` の拡張にするか、別スキル `/task_implement` にするか
- [ ] Phase 5 の検証粒度（全体1回 vs タスク単位）
- [ ] 各フェーズのスキル定義の詳細設計
