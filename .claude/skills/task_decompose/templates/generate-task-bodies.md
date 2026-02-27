以下の手順でタスクリスト構造に基づきイシュー本文を生成してください:

## 手順

### 1. 入力の読み込み

以下のファイルを全て Read で読み込む:
- {task_structure_path}（タスクリスト構造）
- {ps_path}（problem-statement.md）
- {req_path}（requirements.md）
- {arch_path}（architecture.md）
- {std_path}（standards.md）
- {dp_path}（development-process.md）

コマンドがエラーを返した場合、またはデータが空・期待する構造と異なる場合は、以降のステップを続行せず、エラー内容と影響範囲を返却に含めて即座に返却する。

### 2. 本文生成

タスクリスト構造の各タスクについて、以下のテンプレートに従い本文を生成する。

#### イシュー本文テンプレート

```markdown
## 背景

{problem_summary}を解決するため、{approach}として開発する。
本タスクは全{N}タスク中の第{M}タスクであり、{このタスクの位置づけ・目的を1-2文}。

前提: {blocked_by があれば「Task {X}（{タイトル}）が完了していること」、なければ「なし」}

## やること

- {具体的な実装ステップ。ファイルパス・コンポーネント名を明記}
- {ステップは実装順に並べる}
- {...}

## 受け入れ基準

- [ ] {SR から導出した検証可能な条件}
- [ ] {NFR から導出した検証可能な条件（該当する場合）}
- [ ] {...}

## 制約

- {architecture.md / standards.md / development-process.md から、このタスクの実装に影響する制約を抜粋}
- {命名規則、エラーハンドリングパターン、ディレクトリ配置等}
- {使用技術・ライブラリ・設定の指定}

## スコープ外

- {他タスクで扱う機能を明記（タスク番号とタイトルを参照）}
- {Nice-to-have 機能への言及がある場合はスコープ外と明記}
```

#### 本文生成の方針

- **「やること」の粒度**: architecture.md のディレクトリ構造とコンポーネント一覧に記載された情報の範囲でファイルパス・メソッドを特定する。architecture.md にメソッド定義がある場合はメソッド単位（例: 「`src/lib/repositories/article-repository.ts` に ArticleRepository クラスを実装する（create, findByUrl メソッド）」）、ない場合はコンポーネント単位（例: 「`src/lib/repositories/article-repository.ts` に ArticleRepository を実装する」）で記述する
- **「受け入れ基準」の導出**: SR の EARS 記述を「ユーザーが〜したとき、〜が表示/動作する」形式の検証可能な条件に変換する
- **「制約」の範囲**: architecture.md / standards.md / development-process.md から、このタスクの実装判断に影響するもののみ。全制約のコピーではない。AI 開発エージェントが「なぜこう実装すべきか」を理解するために必要な情報。具体的な技術名・ライブラリ名・設定値を含めること
- **「スコープ外」の目的**: AI 開発エージェントのスコープクリープ防止。「検索機能は Task 4 で実装するため、本タスクでは実装しない」のような記述

### 3. 保存

**全タスクの本文をまとめて1回の Write で {output_save_path} に書き込む**（タスクごとの個別 Write は前の内容を上書きするため不可）。

保存形式:

```markdown
# イシュー本文

## Task 1: {タイトル}

{イシュー本文}

---

## Task 2: {タイトル}

{イシュー本文}

---

...
```

### 4. 返答

以下のフォーマットで返答する:

```
result: success
tasks_generated: {生成したタスク数}
total_steps: {全タスクの「やること」ステップ合計数}
total_acceptance_criteria: {全タスクの受け入れ基準合計数}
```
