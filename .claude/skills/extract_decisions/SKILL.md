---
allowed-tools: Glob, Grep, Read, Write, Edit, Task
description: 初期設計文書群から永続的価値のある設計判断記録を抽出するスキル
disable-model-invocation: true
---

初期設計文書（`docs/project-definition/` 配下）とADR（`docs/adr/` 配下）から、ソースコードに残らない「WHY」の情報（判断根拠・棄却理由・スコープ境界・運用方針等）を抽出し、`docs/design-decisions.md` を生成する。

実装完了後もメンテナンスコストが低い判断記録として機能することを目的とする。

## 使い方

```
/extract_decisions
```

引数なし。`docs/project-definition/` 配下の文書を入力として読み込む。

## 出力先

- `docs/design-decisions.md`（固定パス）

## パス変数

- `{skill_dir}`: このファイルが存在するディレクトリの絶対パス
- `{input_dir}`: `docs/project-definition/` の絶対パス
- `{adr_dir}`: `docs/adr/` の絶対パス
- `{output_path}`: `docs/design-decisions.md` の絶対パス

## ワークフロー

Phase 0（初期化・入力検証）→ 1（抽出・生成）→ 2（ユーザー確認・出力）

---

### Phase 0: 初期化・入力検証

```
## Phase 0: 初期化
```

#### Step 1: 入力ファイルの検証

1. `{input_dir}` = `docs/project-definition/` を設定する
2. `{adr_dir}` = `docs/adr/` を設定する
3. `{output_path}` = `docs/design-decisions.md` を設定する
4. 以下のファイルの存在を確認する:
   - `{input_dir}/problem-statement.md` — 不在の場合: 「problem-statement.md が見つかりません。先に `/requirement_elicit` → `/requirement_define` → `/arch_design` を実行してください」と出力して終了
   - `{input_dir}/requirements.md` — 不在の場合: 同上
   - `{input_dir}/architecture.md` — 不在の場合: 同上
5. `{adr_dir}` を Glob で確認し、ADRファイルの一覧を `{adr_files}` に保持する（0件でも続行）

テキスト出力:
```
## Phase 0 完了
- 入力: {input_dir} (3ファイル)
- ADR: {adr_dir} ({N}件)

Phase 1（抽出・生成）に進みます。
```

---

### Phase 1: 抽出・生成

```
## Phase 1: 設計判断記録の生成
```

**目的:** 初期設計文書群から永続的価値のある情報を抽出し、設計判断記録を生成する

#### Step 1: 生成（サブエージェントに委譲）

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

```
以下の手順で設計判断記録を生成してください。

## 手順

### 1. 入力ファイルの読み込み

以下のファイルを全て Read で読み込む:
- `{input_dir}/problem-statement.md`
- `{input_dir}/requirements.md`
- `{input_dir}/architecture.md`
- `{adr_dir}` 配下の全ADRファイル（{adr_files}）

### 2. 抽出と生成

以下の構成で `{output_path}` に Write で保存する。
各セクションの抽出元を参照し、ソースコードに残らない「WHY」の情報のみを抽出する。
具体的なスキーマ定義、APIエンドポイント、コンポーネント一覧等の「WHAT」の詳細は含めない。

```markdown
# 設計判断記録

## ステータス

Draft

## 日付

{今日の日付 YYYY-MM-DD}

## 入力文書

- ユーザー要求書: `docs/project-definition/problem-statement.md` ({日付})
- 要件定義書: `docs/project-definition/requirements.md` ({日付})
- アーキテクチャ設計書: `docs/project-definition/architecture.md` ({日付})
- ADR: `docs/adr/` ({N}件)

## 1. プロジェクト背景

### 1.1 問題定義
（problem-statement.mdから: 何が問題か、なぜ今か、ゴール状態を簡潔に）

### 1.2 Build vs Buy の判断
（problem-statement.mdから: 検討した代替案、採用理由、棄却理由）

### 1.3 当時の制約
（requirements.mdから: 制約テーブル）

## 2. スコープ境界

### 2.1 何を作るか
（requirements.mdから: Must スコープの1-2文要約）

### 2.2 何を作らないか・なぜか
（requirements.mdから: スコープ外リストと除外理由）

### 2.3 将来候補
（problem-statement.mdから: Nice-to-have一覧）

## 3. アーキテクチャ判断

### 3.1 アーキテクチャスタイル
（architecture.mdから: 選択したスタイルとその根拠。NFR/制約との対応を含む）

### 3.2 技術選定サマリ
（architecture.mdから: 技術スタック表。選定理由・検討した代替案と棄却理由を含む。ADRがある場合はADR番号を参照）

### 3.3 設計パターン
（architecture.mdから: 採用したパターンと採用理由）

## 4. セキュリティモデル

### 4.1 認証方式の判断
（architecture.mdから: なぜこの方式か、棄却した方式と理由）

### 4.2 認可モデルの判断
（architecture.mdから: 認可の設計判断と根拠）

### 4.3 データ保護方針
（architecture.mdから: 通信暗号化・シークレット管理等の方針と根拠）

## 5. 運用方針

### 5.1 デプロイ戦略
（architecture.mdから: デプロイ方式の方針と根拠）

### 5.2 バックアップ・リカバリ
（architecture.mdから: バックアップ方針、RPO/RTO、復旧手順の方針）

### 5.3 監視アプローチ
（architecture.mdから: ログ・監視の方針）

### 5.4 その他の運用判断
（architecture.mdから: 接続プール設計等、運用に関わる判断とその根拠）

## 6. NFR目標値

（requirements.mdから: 各NFRの目標値と測定基準のみ。詳細な測定方法・導出根拠は初期設計文書を参照）

| NFR-ID | 観点 | 目標値 |
|--------|------|--------|
| NFR-1 | {観点} | {目標値} |

## 7. 成功基準・リスク

### 7.1 成功基準
（requirements.mdから: 完了条件）

### 7.2 リスクと対策
（requirements.mdから: リスクテーブル）
```

### 3. 返答

以下のフォーマットで返答する:

```
result: success
sections: {完了セクション数}
```
```

---

### Phase 2: ユーザー確認・出力

```
## Phase 2: 確認・出力
```

#### Step 1: ユーザー確認

`{output_path}` を Read し、ユーザーにテキスト出力する:
「修正があればお知らせください。問題なければ『ok』と回答してください。」

- 修正指示あり: 内容を Edit で修正して再提示
- 承認: Step 2 へ

#### Step 2: 完了

```
## extract_decisions 完了
- 入力: {input_dir} (3ファイル) + {adr_dir} ({N}件)
- 出力: {output_path}

次のステップ: `/task_plan` でタスク分解に進んでください。
```
