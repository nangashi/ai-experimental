# 参照・変数整合性分析

スキル定義ファイルの参照整合性と変数整合性を検証し、問題を構造化レポートとして出力する。

## 入力

- `{skill_path}`: スキルディレクトリの絶対パス
- `{skill_name}`: スキル名
- `{file_list_path}`: ファイルリストのパス
- `{findings_save_path}`: 結果保存先パス

## 手順

### Step 1: ファイル収集

1. `{file_list_path}` を Read してスキル内の全 .md ファイルパスを取得する
2. `{skill_path}/SKILL.md` を Read する
3. スキル内の各テンプレート・エージェントファイルを Read する

### Step 2: チェック実行

以下のチェックを順に実行する。検出した問題は findings リストに追加していく。

#### A1: 存在しないファイル参照

SKILL.md と全テンプレート内から、ファイルパスを抽出する。対象パターン:
- バッククォート内のパス（`` `path/to/file.md` ``）
- パス変数の値定義（`- {var}: path/to/file.md`）
- テンプレート参照（`templates/name.md`, `agents/name.md`）

以下のパスは検証対象から **除外** する:
- `{variable}` のみで構成されるパス（ランタイム生成。例: `{work_dir}/output.md`）
- Write/保存の出力先パス
- URL（`http://`, `https://`）

除外後の各パスについて:
- 相対パスの場合は `{skill_path}` を基準に絶対パスに解決する
- Glob または Read で存在を確認する
- 存在しないパスを finding として記録する（severity: error）

#### A2: 他スキルへの参照（コピペ残り）

SKILL.md と全テンプレート内から `.claude/skills/` を含むパスを抽出する。
対象スキル自身のパス（`.claude/skills/{skill_name}/`）以外を指すものを finding として記録する。

注意: 意図的なクロスリファレンスの可能性があるため severity は **warning** とする。

#### A3: 孤立テンプレート/エージェントファイル

1. Glob で `{skill_path}/templates/*.md` と `{skill_path}/agents/*.md` を列挙する
2. SKILL.md の内容で各ファイル名（拡張子含む）が参照されているか検索する
3. 参照されていないファイルを finding として記録する（severity: warning）

Auto: yes（ファイル削除）

#### A4: old/ ディレクトリへの参照

全ファイルの内容を検索し、`/old/` を含むパスを検出する。
検出された場合は finding として記録する（severity: warning）。

#### B1: 未定義パス変数

各テンプレートファイルについて:
1. テンプレート内の `{variable_name}` パターンを全て抽出する
2. SKILL.md 内でそのテンプレートを呼び出す Task の記述箇所を特定する（テンプレートファイル名で検索）
3. Task 記述内のパス変数定義（`- \`{variable_name}\`:` 形式のリスト）を抽出する
4. テンプレートで使用されているが Task 定義にない変数を finding として記録する

除外: テンプレート内部で定義・生成される変数（ループカウンタ、テンプレート自身の「入力」セクションで説明されている変数等）

Severity: テンプレート内でパス参照として使われている場合は error、それ以外は warning。

#### B2: 未使用パス変数

各 Task 呼び出しについて:
1. Task 定義内のパス変数（`- \`{variable_name}\`:` 形式）を抽出する
2. 呼び出し先テンプレートファイルを Read し、各変数が使用されているか検索する
3. 定義されているがテンプレート内で未使用の変数を finding として記録する（severity: warning）

Auto: yes（SKILL.md から該当パス変数行を削除）

#### B3: パス変数名の不一致

B1 で検出された未定義変数と B2 で検出された未使用変数を突合する。
以下の条件でペアを検出する:
- 共通のプレフィックスまたはサフィックスを持つ（例: `{findings_path}` vs `{findings_save_path}`）
- 一方が他方の部分文字列である
- 文字の追加・削除・置換が1-2箇所のみ

ペアが見つかった場合は finding として記録し、B1/B2 の対応する finding は統合する（severity: warning）。

Auto: yes（テンプレート側またはSKILL.md側の変数名を統一）

### Step 3: 結果出力

検出された全 finding を以下のフォーマットで `{findings_save_path}` に Write する:

```
# Findings: Reference & Variable Integrity

Total: {N} issues (errors: {N}, warnings: {N})

### SK-001: {タイトル}
- **Check**: {A1/A2/A3/A4/B1/B2/B3}
- **Severity**: {error/warning}
- **Location**: {ファイルパス}:{行番号またはセクション名}
- **Problem**: {問題の説明}
- **Fix**: {修正案の説明}
- **Auto**: {yes (具体的操作) / no}
```

ID は `SK-001` から連番で付与する。

問題が0件の場合も以下を出力する:
```
# Findings: Reference & Variable Integrity

Total: 0 issues
```

最後に「保存完了: {findings_save_path}, 検出: {N}件 (error: {N}, warning: {N})」とだけ返答する。
