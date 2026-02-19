# TAKT (Agent Koordination Topology) 機能分析

## 概要

TAKTはYAMLベースのマルチエージェントオーケストレーションフレームワーク。AIエージェントが自律的に判断するのではなく、「誰が、いつ、どの制約で実行し、何が記録されるか」を宣言的に定義する。

- リポジトリ: https://github.com/nrslib/takt
- ライセンス: MIT
- 技術スタック: TypeScript, Node.js, Zod, Commander.js, Claude Agent SDK

---

## コアアーキテクチャ

### 音楽メタファー

| 概念 | 対応 | 説明 |
|------|------|------|
| Piece | ワークフロー定義 | 完全なタスク実行フロー（YAMLファイル） |
| Movement | 実行ステップ | ピース内の個別ステージ |
| Orchestration | エンジン | エージェント間のムーブメント遷移を制御 |

### 3フェーズ実行モデル

各ムーブメントは最大3フェーズを順次実行し、セッションは`sessionKey`で維持される:

| Phase | 目的 | ツールアクセス | 説明 |
|-------|------|-------------|------|
| Phase 1 | メイン作業 | `allowed_tools`の全ツール | コーディング、レビュー等の実作業 |
| Phase 2 | レポート生成 | 書き込みのみ | 構造化されたレポートを出力 |
| Phase 3 | ステータス判定 | なし | `[STEP:N]`タグで次ステップを判定 |

### 5段階ルール評価 (RuleEvaluator)

ステップ完了後、次のステップをカスケード方式で決定:

1. **集約ルール**: 並列ステップの`all()`/`any()`条件
2. **Phase 3タグ**: ステータス判定出力から`[STEP:N]`を抽出
3. **Phase 1タグ**: メイン出力からのフォールバックタグ検出
4. **明示的AIジャッジ**: `ai()`ラッパーの条件のみ評価
5. **AIフォールバック**: 残りの全条件をAIが評価

`RuleMatchMethod`型でどの段階でマッチしたかを追跡（オブザーバビリティ）。

---

## ファセットプロンプティング（関心の分離）

プロンプトを5つの独立した構成要素に分解し、自由に組み合わせ可能:

| ファセット | 説明 | 例 |
|-----------|------|-----|
| **Persona** | エージェントの役割・専門性 | `planner`, `coder`, `architecture-reviewer` |
| **Policy** | コーディング基準、品質基準、禁止事項 | `coding`, `review`, `ai-antipattern` |
| **Instruction** | ステップ固有の実行指示 | `plan`, `implement`, `review-arch` |
| **Knowledge** | ドメインコンテキスト、アーキテクチャ文書 | `architecture`, `backend`, `security` |
| **Output Contract** | 出力形式の宣言的定義 | レポートフォーマット |

### 組み合わせの実例（defaultピースのimplementムーブメント）

```yaml
- name: implement
  persona: coder           # Persona: コーダー
  policy:                  # Policy: コーディング+テスト基準
    - coding
    - testing
  knowledge:               # Knowledge: バックエンド+アーキテクチャ
    - backend
    - architecture
  instruction: implement   # Instruction: 実装指示
  output_contracts:        # Output Contract: スコープ宣言+判断ログ
    report:
      - name: coder-scope.md
        format: coder-scope
      - name: coder-decisions.md
        format: coder-decisions
```

---

## ワークフロー制御機構

### 並列実行

複数エージェントの同時実行と集約条件:

```yaml
- name: reviewers
  parallel:
    - name: arch-review
      persona: architecture-reviewer
      rules:
        - condition: approved
        - condition: needs_fix
    - name: security-review
      persona: security-reviewer
      rules:
        - condition: approved
        - condition: needs_fix
  rules:
    - condition: all("approved")   # 全員承認 → 次へ
      next: supervise
    - condition: any("needs_fix")  # 誰かがNG → 修正へ
      next: fix
```

### ループモニタリング

無限ループを検出・制御:

```yaml
loop_monitors:
  - cycle:
      - ai_review
      - ai_fix
    threshold: 3           # 3回繰り返しで介入
    judge:
      persona: supervisor  # スーパーバイザーが判定
      rules:
        - condition: Healthy (making progress)
          next: ai_review
        - condition: Unproductive (no improvement)
          next: reviewers
```

### 権限制御

ムーブメントごとにツールアクセスを制限:

| 設定 | 説明 |
|------|------|
| `edit: true/false` | 書き込み権限の有無 |
| `allowed_tools` | 使用可能なツールの明示的リスト |
| `required_permission_mode` | 権限モード（`edit`, `trusted`, `strict`） |
| `session: refresh` | セッションをリフレッシュ（前のコンテキストをリセット） |

---

## 組み込みピース一覧

| ピース | 用途 | 特徴 |
|--------|------|------|
| `default` | 標準開発 | plan → implement → ai_review → reviewers(arch+qa並列) → supervise |
| `default-mini` | 軽量修正 | 簡略化されたレビュー付き |
| `expert` | エキスパートレビュー | 4並列レビュー(arch+frontend+security+qa) |
| `expert-mini` | エキスパート軽量版 | expertの簡略版 |
| `magi` | 3視点審議 | MELCHIOR→BALTHASAR→CASPER多数決（エヴァンゲリオンのMAGIシステム） |
| `compound-eye` | マルチモデル | Claude+Codex並列実行→統合 |
| `research` | 調査 | 自律的調査（質問なし） |
| `deep-research` | 深層調査 | 計画→調査→分析の多段階 |
| `review-only` | レビュー専用 | コード変更なし、3並列レビュー |
| `structural-reform` | 構造改革 | プロジェクト全体のリファクタリング |
| `backend` / `frontend` | 特化開発 | ドメイン特化のknowledge注入 |
| `backend-cqrs` | CQRS/ES特化 | CQRS/EventSourcing専門レビュー |
| `unit-test` / `e2e-test` | テスト | テスト特化ワークフロー |
| `passthrough` | パススルー | 単純なエージェント実行 |

---

## 実行モード

### 1. インタラクティブモード（デフォルト）

```
takt → AI対話でタスク明確化 → /go → ピース選択 → worktree作成 → 実行
```

### 2. ダイレクトタスク

```bash
takt --task "認証機能にJWT検証を追加"
```

### 3. GitHub Issue連携

```bash
takt #42              # Issue #42をタスクとして実行
takt --issue 42       # 同上
```

### 4. パイプラインモード（CI/CD）

```bash
takt --pipeline --task "Fix bug" --auto-pr
```

### 5. タスクキュー

```bash
takt add              # タスクをキューに追加
takt run              # キューのタスクを実行
takt watch            # ファイル監視して自動実行
```

---

## Git統合戦略

- **共有クローン**: `git clone --shared --dissociate`を使用（worktreeではなく独立.gitディレクトリ）
- **ブランチ命名**: `takt/{timestamp}-{slug}` 形式
- **自動コミット+PR**: `--auto-pr`フラグで自動PR作成
- **ワークツリーセッション**: クローンごとの隔離

---

## 状態管理と監査証跡

| 状態カテゴリ | 保存先 | 形式 |
|-------------|--------|------|
| エージェントセッション | `.takt/agent_sessions.json` | プロバイダ変更で無効化 |
| ワークフローログ | `.takt/logs/{sessionId}.jsonl` | NDJSON（追記のみ） |
| ワークツリーセッション | `.takt/worktree-sessions/` | クローンごとの隔離 |
| 入力履歴 | `.takt/input_history` | 直近100件、重複排除 |
| レポート | `.takt/runs/{slug}/reports/` | 各ステップの構造化レポート |

---

## 設定階層（3層解決）

| 優先度 | スコープ | パス |
|--------|--------|------|
| 1 (最高) | プロジェクト | `.takt/workflows/`, `.takt/agents.yaml` |
| 2 | ユーザーグローバル | `~/.takt/workflows/`, `~/.takt/agents/` |
| 3 (最低) | ビルトイン | `resources/global/{lang}/workflows/` |

モデル解決も4段階: ステップ → エージェント → グローバル設定 → プロバイダデフォルト

---

## 組み込みペルソナの品質

### planner（計画者）

特筆すべき設計原則:
- 「推測するな、コードを読め」— 不明点はコードを調査して解決
- スコープ規律 — 明示的に要求されたことだけを計画
- 不要なコード生成の禁止 — "念のため"のコードは書かない
- 後方互換性コードの禁止（明示的指示がない限り）

### architecture-reviewer（設計レビュアー）

特筆すべき設計原則:
- 「小さな問題でも見逃さない」— 技術的負債の蓄積を防止
- 「条件付き承認」の禁止 — 問題があればリジェクト
- 具体性の強制 — 「リファクタリングが必要」は禁止、ファイル・行・修正方法を明示

### ai-antipattern-reviewer（AIアンチパターン検出）

独自の検出観点:
- ハルシネーション検出（存在しないAPIの呼び出し等）
- コピペパターン検出
- スコープクリープ検出（要求されていない機能の追加）
- デッドコード検出
- 不要な後方互換性コード検出
- フォールバック/デフォルト引数の過剰使用検出

---

## TAKTの哲学的位置づけ

公式ドキュメントが明確に述べる「TAKTではないもの」:

| ではない | 理由 |
|---------|------|
| 自律エンジニアリング | ワークフローを定義する; 人間がタスクを与える |
| Skills/Swarmの代替 | Skillsは単一エージェントの知識拡張; Swarmはエージェントの並列化; TAKTは構造化オーケストレーション |
| デフォルトで自動 | 全ステップで人間の承認が可能; 自動化はオプトイン |
