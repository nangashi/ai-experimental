以下の手順で受け入れ基準の充足を検証してください:

## 手順

### 1. 受け入れ基準の収集

以下の2つのソースから受け入れ基準を収集する:

**Source A: Issue の受け入れ基準**
{issue_body} から受け入れ基準（Acceptance Criteria / 完了条件）セクションを抽出する。

**Source B: requirements.md の受け入れ基準**
{requirements_path} を Read で読み込み、「受け入れ基準」セクションを抽出する。

### 2. 統合受け入れ基準リストの作成

Source A と Source B の基準を統合する:
- 重複する基準はマージする（同じ意味の基準が異なる表現で記載されている場合）
- Source A にのみ存在する基準も含める（Issue側で後から追加された可能性がある）
- 各基準に連番を付与する（AC-001, AC-002, ...）

### 3. 実装との照合

{design_path} を Read で設計内容を把握し、{diff_path} を Read で実装差分を確認する。

変更されたファイルのうち主要なものを Read で確認し、実際のコードを把握する。

各受け入れ基準について以下を判定する:
- **satisfied**: 設計・実装で充足されている（根拠を記載）
- **partially_satisfied**: 一部は満たされているが不完全（不足箇所を明記）
- **not_satisfied**: 満たされていない（理由を明記）
- **not_verifiable**: コードレビューだけでは検証できない（手動テスト・E2E等が必要）

### 4. 結果の保存

{verification_save_path} に Write で保存する:

```markdown
# 受け入れ基準検証結果

## サマリ

- 充足: {satisfied_count}件
- 一部充足: {partially_count}件
- 未充足: {not_satisfied_count}件
- 検証不可: {not_verifiable_count}件
- 判定: {pass / needs_action}

## 詳細

### AC-001: {基準内容}
- 判定: {satisfied / partially_satisfied / not_satisfied / not_verifiable}
- 根拠: {判定の根拠}
- ソース: {Issue / requirements.md / both}

（全基準について繰り返す）

## 未充足・一部充足の基準（要対応）

{not_satisfied と partially_satisfied の基準を一覧。なければ「なし」}
```

判定基準:
- not_satisfied が 1件以上 → `needs_action`
- それ以外 → `pass`

### 5. 返答

以下のフォーマットで返答する:

```
result: {pass / needs_action}
satisfied: {satisfied_count}
partially: {partially_count}
not_satisfied: {not_satisfied_count}
not_verifiable: {not_verifiable_count}
summary: {検証結果の1行サマリ}
```
