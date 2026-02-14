# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 の agent_bench 連携参照を削除、Phase 1 返答解析を明示化、Phase 1/2 の暗黙的主経路を明示化、Phase 0 でエージェント定義の Read を削除、Phase 0 で audit-approved.md 削除を追加、検証失敗時の Phase 3 出力を追加 | C-1, I-1, I-2, I-3, I-4, I-5, I-7, I-8 |
| 2 | agents/shared/instruction-clarity.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 3 | agents/evaluator/criteria-effectiveness.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 4 | agents/evaluator/scope-alignment.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 5 | agents/evaluator/detection-coverage.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 6 | agents/producer/workflow-completeness.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 7 | agents/producer/output-format.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |
| 8 | agents/unclassified/scope-alignment.md | 修正 | アンチパターンカタログ参照の Read をパス変数化 | I-6 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1（スキルディレクトリ外への参照）、I-1（agent_bench 連携のデータフロー検証欠落）、I-2（Phase 1サブエージェント返答解析の脆弱性）、I-3（Phase 1部分失敗時の主経路不明）、I-4（Phase 2 Step 2a「残りすべて承認」後の動作）、I-5（Phase 2検証失敗時の「いいえ」選択後の動作）、I-7（エージェント定義の重複 Read）、I-8（Phase 2 audit-approved.md再実行時の扱い）

**変更内容**:

#### C-1, I-1: 外部参照の削除（行174付近）
- **現在の記述**: `Phase 1 で .agent_audit/{agent_name}/audit-*.md を参照している`（構造分析ドキュメントの記述箇所）
- **改善後の記述**: この記述は構造分析（analysis.md）の「外部参照の検出」セクションにあり、SKILL.md 自体には存在しない可能性がある。実際の SKILL.md には agent_bench への参照は含まれていなかったため、**変更不要**（既に解決済み）

#### I-2: Phase 1 返答解析の明示化（行141-146）
- **現在の記述**: `分析完了後、以下の1行フォーマット**のみ**で返答してください（他の出力を含めないこと）: dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
- **改善後の記述**: 以下を追加:
```markdown
全サブエージェントの完了を待ち、各返答サマリを収集する。

**返答の解析方法**:
- 各サブエージェントの返答から `dim: ` で始まる行を抽出する
- フォーマット不正（該当行が見つからない、またはパース失敗）の場合、該当次元を失敗扱いとし findings ファイルの存在で最終判定する
```

#### I-3: Phase 1 部分失敗時の主経路明示化（行148-160）
- **現在の記述**: `全て失敗した場合: 「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了する。` の直後
- **改善後の記述**: 以下のセクションを追加:
```markdown
部分失敗（一部成功）の場合: 「⚠ 一部の次元が失敗しました: {失敗次元リスト}。成功した次元で続行します。」と警告出力し、Phase 2 へ進む。
```

#### I-4: Phase 2 Step 2a「残りすべて承認」後の動作明示化（行189-206）
- **現在の記述**: 選択肢リストの最後の項目 `**「残りすべて承認」**: この指摘を含め、未確認の全指摘を承認としてループを終了する`
- **改善後の記述**: 以下を追加:
```markdown
「残りすべて承認」選択時の処理:
1. 現在の finding を承認リストに追加する
2. 未確認の全 findings を承認リストに追加する（ループせずに一括承認）
3. Step 3（承認結果の保存）へ進む
```

#### I-5: Phase 2 検証失敗時の Phase 3 出力追加（行263-305）
- **現在の記述**: Phase 3 の出力フォーマットには検証失敗警告のケースが定義されていない
- **改善後の記述**: Phase 3 の「Phase 2 が実行された場合」セクションの最後に以下を追加:
```markdown
検証失敗時の追加情報（検証失敗かつロールバック拒否の場合）:
```
- ⚠ 検証失敗: {問題リスト}
  手動確認を推奨します（ロールバックは実行されていません）
```
```

#### I-7: Phase 0 のエージェント定義 Read 削除（行79, 255）
- **変更箇所1（Phase 0 Step 2）**: 現在の記述を削除
  - **削除**: `2. Read で `agent_path` のファイルを読み込み、`{agent_content}` として保持する。読み込み失敗時はエラー出力して終了`
  - **削除**: グループ分類ステップ（Step 4）での `{agent_content}` 参照
  - **改善後**: グループ分類を Grep ベースに変更:
```markdown
2. Bash で `ls {agent_path}` を実行し、ファイルの存在を確認する。存在しない場合はエラー出力して終了
```

- **変更箇所2（グループ分類 Step 4）**:
  - **現在の記述**: `4. {agent_content} を分析し、{agent_group} を以下の基準で判定する:`
  - **改善後の記述**:
```markdown
4. Grep で `{agent_path}` の特徴パターンを検出し、`{agent_group}` を以下の基準で判定する:

   **Evaluator 特徴の検出**（Grep で以下のパターンを検索）:
   - 評価基準・チェックリスト: `pattern: "(criteria|checklist|detection rule|evaluation standard)"` → ヒット数を記録
   - 問題点出力: `pattern: "(finding|issue|problem|improvement|recommendation)"` → ヒット数を記録
   - 重要度分類: `pattern: "(severity|critical|significant|priority)"` → ヒット数を記録
   - 評価スコープ: `pattern: "(scope|in-scope|out-of-scope|boundary)"` → ヒット数を記録

   **Producer 特徴の検出**（Grep で以下のパターンを検索）:
   - ステップ・ワークフロー: `pattern: "(step|phase|workflow|procedure)"` → ヒット数を記録
   - 成果物出力: `pattern: "(output|generate|create|produce|file)"` → ヒット数を記録
   - 変換・加工: `pattern: "(transform|convert|process|modify)"` → ヒット数を記録
   - ツール操作: `pattern: "(Read|Write|Edit|Bash|Glob|Grep)"` → ヒット数を記録

   **判定ルール**:
   - evaluator 特徴が3つ以上検出（ヒット数 > 0）**かつ** producer 特徴が3つ以上検出 → **hybrid**
   - evaluator 特徴が3つ以上検出 → **evaluator**
   - producer 特徴が3つ以上検出 → **producer**
   - 上記いずれにも該当しない → **unclassified**

   この判定はメインコンテキストで直接行う（サブエージェント不要）。
```

- **変更箇所3（Phase 2 検証ステップ Step 1 削除）**:
  - **削除**: `1. Read で {agent_path} を再読み込み`
  - **改善後**: 構造検証を Grep ベースに変更:
```markdown
1. **構造検証**: Grep で `{agent_path}` の構造を検証する:
   - YAML frontmatter の存在: `grep -q "^---" {agent_path}` でファイル先頭の `---` を確認
   - description フィールドの存在: `grep -q "description:" {agent_path}` を確認
```

#### I-8: Phase 0 で audit-approved.md 削除を追加（行102）
- **現在の記述**: `7a. 既存の findings ファイルを削除する: rm -f .agent_audit/{agent_name}/audit-*.md を Bash で実行する`
- **改善後の記述**: 削除対象を拡張:
```markdown
7a. 既存の findings ファイルと承認済みファイルを削除する: `rm -f .agent_audit/{agent_name}/audit-*.md` を Bash で実行する（Phase 1/2 の再実行時に重複を防ぐため、冪等性を保証する）
```
（注: `audit-*.md` パターンは `audit-approved.md` も含むため、実際には既に削除されている。変更不要の可能性）

---

### 2-8. 各次元エージェント（agents/*/\*.md）の修正

**対応フィードバック**: I-6（アンチパターンカタログの読み込みタイミング）

**変更方針**: 各次元エージェント内の以下の記述を変更する

#### 変更対象ファイルと行番号
- `agents/shared/instruction-clarity.md`: 行118
- `agents/evaluator/criteria-effectiveness.md`: 行84
- `agents/evaluator/scope-alignment.md`: 行80
- `agents/evaluator/detection-coverage.md`: 行105
- `agents/producer/workflow-completeness.md`: 行102
- `agents/producer/output-format.md`: 行110
- `agents/unclassified/scope-alignment.md`: 行74

#### 各ファイルの変更内容

**現在の記述**（例: instruction-clarity.md 行118）:
```markdown
**Antipattern Catalog**: `.claude/skills/agent_audit_new/antipatterns/instruction-clarity.md` を Read し、カタログに記載されたアンチパターンを確認する。
```

**改善後の記述**:
```markdown
**Antipattern Catalog**: `{antipattern_catalog_path}` を Read し、カタログに記載されたアンチパターンを確認する。
```

#### SKILL.md への変更追加（Phase 1 のサブエージェント起動箇所、行136-141）

**現在の記述**:
```markdown
各次元について、以下の Task prompt を使用する:

> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
> 分析対象: `{agent_path}`, agent_name: `{agent_name}`
> findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
> 分析完了後、以下の1行フォーマット**のみ**で返答してください（他の出力を含めないこと）: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```

**改善後の記述**:
```markdown
各次元について、以下の Task prompt を使用する:

> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
>
> パス変数:
> - `{agent_path}`: {実際の agent_path の絶対パス}
> - `{agent_name}`: {agent_name}
> - `{findings_save_path}`: {実際の .agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス}
> - `{antipattern_catalog_path}`: {実際の .claude/skills/agent_audit_new/antipatterns/{ID_PREFIX の対応カタログ}.md の絶対パス}
>
> 分析完了後、以下の1行フォーマット**のみ**で返答してください（他の出力を含めないこと）: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```

**antipattern_catalog_path のマッピング**（SKILL.md に追記する情報）:

| ID_PREFIX | antipattern_catalog_path |
|-----------|--------------------------|
| IC | `.claude/skills/agent_audit_new/antipatterns/instruction-clarity.md` |
| CE | `.claude/skills/agent_audit_new/antipatterns/criteria-effectiveness.md` |
| SA | `.claude/skills/agent_audit_new/antipatterns/scope-alignment.md` |
| DC | `.claude/skills/agent_audit_new/antipatterns/detection-coverage.md` |
| WC | `.claude/skills/agent_audit_new/antipatterns/workflow-completeness.md` |
| OF | `.claude/skills/agent_audit_new/antipatterns/output-format.md` |

---

## 新規作成ファイル
該当なし

---

## 削除推奨ファイル

| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| agent_bench/ 配下の全ファイル | agent_bench は別スキルとして独立ディレクトリに配置すべき。agent_audit_new スキル内に内包する必要なし | C-2 |

**注意**: 実際の削除は手動で実施すること（改善適用テンプレートはファイル削除を実行しない）

---

## 実装順序

1. **SKILL.md の Phase 0 グループ分類変更**（I-7 対応）— エージェント定義の Read 削除と Grep ベース分類への変更。この変更により Phase 0 で agent_content を保持しなくなるため、他の変更の前提条件となる
2. **SKILL.md の Phase 1 サブエージェント起動箇所変更**（I-6 対応）— antipattern_catalog_path 変数の追加。この変更により各次元エージェントに渡すパス変数が確定する
3. **各次元エージェント（agents/\*/\*.md）の修正**（I-6 対応）— アンチパターンカタログ参照のパス変数化。SKILL.md での変数定義が完了してから実施
4. **SKILL.md の Phase 1 返答解析明示化**（I-2 対応）— 返答解析ロジックの明示化
5. **SKILL.md の Phase 1 部分失敗時の主経路明示化**（I-3 対応）— 部分失敗時の動作明示化
6. **SKILL.md の Phase 2 Step 2a 動作明示化**（I-4 対応）— 「残りすべて承認」の処理フロー明示化
7. **SKILL.md の Phase 2 検証失敗時の Phase 3 出力追加**（I-5 対応）— 検証失敗時の出力フォーマット追加
8. **SKILL.md の Phase 0 audit-approved.md 削除追加**（I-8 対応）— Phase 0 の削除対象拡張（既存コードで対応済みの可能性あり、確認後に適用）

依存関係の理由:
- Step 1→2: グループ分類の Grep 化により agent_content が存在しなくなるため、他の agent_content 参照箇所の変更前提となる（今回は該当なし）
- Step 2→3: SKILL.md で antipattern_catalog_path 変数を定義してから、各次元エージェントで参照するため

---

## 注意事項

- **C-1, I-1 について**: SKILL.md には agent_bench への外部参照が存在しなかったため、既に解決済みの可能性がある。構造分析ドキュメントの記述が古い可能性を考慮
- **I-7 について**: Phase 0 での Read 削除により、グループ分類が Grep ベースに変更される。この変更は既存のワークフローに影響を与えるため、慎重にテストすること
- **I-8 について**: `rm -f .agent_audit/{agent_name}/audit-*.md` パターンは既に `audit-approved.md` を含むため、変更不要の可能性がある。ファイル名パターンを確認後に適用判断すること
- **C-2（agent_bench ディレクトリ削除）について**: 改善適用テンプレートはファイル削除を実行しないため、手動で別スキルディレクトリに移動すること
- SKILL.md の変更により、サブエージェント起動時のパス変数が増加する。Phase 1 の Task prompt 生成ロジックを確認すること
- 各次元エージェントのアンチパターンカタログ参照がパス変数化されることで、親が一括でパスを管理できるようになり、コンテキスト効率が向上する
