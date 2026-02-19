# Agent Audit Findings: dim1-criteria-effectiveness

- 分析モード: 静的
- 分析日: 2026-02-12
- eval_mode: scenario

## 1. 基準有効性 (Criteria Effectiveness)

### 基準別評価テーブル
| 基準 | S/N比 | 実行可能性 | 費用対効果 | 判定 |
|------|-------|-----------|-----------|------|
| 手順1: ファイル読み込み指示 | H | E | H | 有効 |
| 手順2: 分析モード決定ロジック | H | E | H | 有効 |
| 手順3: audit-criteria.md 参照指示 | M | D | M | 有効性未確認 |
| 手順4: Finding フォーマット要件 | H | E | H | 有効 |
| 手順5: Write 出力要件 | H | E | H | 有効 |
| 手順6: サマリ返答要件 | H | E | H | 有効 |

### 分析結果サマリ
テンプレートの構造は概ね明確だが、外部参照の曖昧さ、「基準」の定義不足、severity判定基準の欠如が改善機会として特定された。

## Findings

### CE-01: 外部ファイル参照の曖昧さ [severity: improvement]
- 内容: 手順3「audit-criteria.md『次元 1: 基準有効性』の分析方法に従い」は参照指示のみで、具体的分析手順が本テンプレートに含まれていない。サブエージェントは audit-criteria.md のどのセクションをどう適用するか推論する必要がある。
- 根拠: 静的分析の4観点（指示の具体性、S/N比、実行可能性、費用対効果）が手順3で参照されるが、これらをどのステップで実行するかが明示されていない。手順2で分析モードを決定した後、手順3-4間でこれらの観点を適用すると推測される。
- 推奨: 手順3を以下のように具体化する：「3. 静的分析の場合、エージェント定義の各評価基準を以下の4観点で評価する: a.指示の具体性, b.S/N比(H/M/L), c.実行可能性(E/D/I), d.費用対効果(H/M/L)。データ駆動分析の場合、knowledge.md の知見と照合して各基準の寄与証拠を確認する。」
- 運用特性: S/N=M, 実行可能性=D, 費用対効果=M

### CE-02: 「基準」の定義が不明確 [severity: improvement]
- 内容: 手順3で「エージェント定義の各評価基準を分析する」とあるが、何を「基準」とみなすかの定義がない。セクション見出しか、箇条書き項目か、段落単位か、チェックリスト項目かが曖昧。
- 根拠: 出力テンプレート（手順5）では「基準別評価テーブル」に「{基準名}」を記載する必要があるが、どの粒度で「基準」を列挙すべきかが不明。サブエージェントが独自に判断する必要があり、結果の一貫性が低下する可能性がある。
- 推奨: 手順3の冒頭に定義を追加する：「『基準』とは、エージェント定義内の指示項目（箇条書き、チェックリスト項目、セクション見出し配下の指示群）を指す。1つのセクション内に複数の独立した指示がある場合は、それぞれを別の基準として評価する。」
- 運用特性: S/N=M, 実行可能性=D, 費用対効果=M

### CE-03: finding の severity 判定基準が欠如 [severity: improvement]
- 内容: 手順4で「severity (critical/improvement/info)」を記載する要件があるが、どの条件で critical/improvement/info を判定するかの基準が示されていない。
- 根拠: audit-criteria.md には「重大度定義」テーブル（critical=即時修正推奨、improvement=精度向上期待、info=参考情報）があるが、本テンプレートからは参照されていない。サブエージェントは静的分析の4観点の結果（S/N比=L, 実行可能性=INFEASIBLE 等）をどう severity にマッピングするかを推論する必要がある。
- 推奨: 手順4に判定ルールを追加する：「severity判定: S/N=L または 実行可能性=I → critical、有効性未確認 または 費用対効果=L → improvement、その他（有効 かつ 運用特性がすべて M 以上）→ info。」
- 運用特性: S/N=H, 実行可能性=D, 費用対効果=H

### CE-04: 条件分岐の網羅性確認が欠如 [severity: info]
- 内容: 手順1の条件分岐（has_knowledge, eval_mode）について、すべての組み合わせで必要なファイルが列挙されているかを確認する指示がない。例: eval_mode=detection かつ has_knowledge=false の場合、perspective_path が必要か不明。
- 根拠: 本テンプレートは scenario モードで実行されているため perspective_path は不要だが、detection モードで静的分析を実行する場合に perspective_path の読み込みが必要かどうかが明示されていない（audit-criteria.md 次元1「静的分析」セクションには detection/scenario の分岐記載がない）。
- 推奨: 手順1に補足を追加する：「eval_mode=detection の場合、has_knowledge に関わらず perspective_path を読み込む（スコープ外定義の確認に必要）。」ただし、次元1では perspective_path を直接参照しないため、現状では info レベルの改善機会として記録する。
- 運用特性: S/N=M, 実行可能性=E, 費用対効果=M

### CE-05: 出力パス変数の存在検証が欠如 [severity: info]
- 内容: 手順5で {findings_save_path} に Write するが、ディレクトリの存在確認・作成指示がない。親ディレクトリが存在しない場合、Write が失敗する可能性がある。
- 根拠: findings_save_path = `/home/.../prompt-improve/dim1-criteria-effectiveness/audit-dim1.md` の場合、`prompt-improve/dim1-criteria-effectiveness/` ディレクトリが存在しない可能性がある。ただし、通常は親スキル（agent_audit）が Phase 0 でディレクトリを準備すると想定される。
- 推奨: 手順5の冒頭に追加する：「Write 実行前に、findings_save_path の親ディレクトリが存在しない場合は Bash で `mkdir -p` を実行してディレクトリを作成する。」または、親スキルの責務として Phase 0 でディレクトリ作成を明示する。
- 運用特性: S/N=M, 実行可能性=E, 費用対効果=H

## 2. スコープ整合性 (Scope Alignment)

### SA-01: スコープ定義の完全な不在 [severity: critical]
- 内容: エージェント定義にスコープ定義セクションが存在しない。このテンプレートは「次元1（基準有効性）の分析を実行する」という手順書であり、エージェント自体の評価対象範囲が記載されていない
- 根拠: 全文を精査したが、「スコープ外」「対象範囲」「境界」等のスコープ定義に関する記述が一切ない。テンプレートは手順実行方法のみを記載している
- 推奨: このファイルは agent_audit スキルのテンプレートファイル（サブエージェント向け指示書）であり、評価対象エージェント（reviewer/general agent）の定義ファイルではない。agent_audit の対象として誤って指定されている可能性がある。正しい評価対象エージェント定義ファイル（例: `.claude/agents/*.md`）を指定すべき

### SA-02: エージェント定義とテンプレートの混同 [severity: critical]
- 内容: {agent_path} として指定されたファイルは、評価・レビュー対象の「エージェント定義」ではなく、agent_audit スキル自身の内部テンプレートファイル（次元1分析の実行手順書）である
- 根拠: ファイル内容は「Read で以下のファイルを読み込む」「分析モードを決定する」等の手順指示で構成され、エージェント自身の評価基準・判定ロジック・ドメイン知識を含まない。ファイルパスも `.claude/skills/agent_audit/templates/` 配下にある
- 推奨: agent_audit の実行時には、テンプレートファイルではなく、実際の評価対象エージェント定義ファイル（例: `.claude/agents/consistency-design-reviewer.md` や `.claude/agents/performance-design-reviewer.md`）を {agent_path} パラメータとして指定する必要がある。スキル実行フローを見直し、正しい対象ファイルが渡されるよう修正すべき

### SA-03: テンプレートファイルのスコープ評価の無意味性 [severity: info]
- 内容: 現在のファイルはサブエージェント向けの実行手順書であるため、スコープ整合性の概念が適用不可能である。テンプレートは「どの手順を実行するか」を定義するものであり、「どの問題を検出するか」の範囲を定義するものではない
- 根拠: テンプレートファイルには評価基準・チェックリスト・判定ロジックが含まれず、他のエージェントに委譲する手順のみが記載されている。スコープ整合性の分析対象となるのは、最終的に問題を検出・評価する「評価対象エージェント定義」である
- 推奨: agent_audit の呼び出し元で、{agent_path} として正しいエージェント定義ファイルが渡されているかを確認する。テンプレートファイルではなく、実際の reviewer agent 定義（`.claude/agents/*.md`）や一般エージェント定義を対象とすべき

## 3. 盲点分析 (Blind Spot Detection)

データ不足のため分析不可

## 4. ドメイン知識充足度 (Domain Knowledge Adequacy)

データ不足のため分析不可

## 5. 改善機会マッピング (Improvement Opportunity Map)

### OM-01: 誤った対象ファイル指定の修正（最優先） [severity: improvement]
- 内容: 現在の実行は agent_audit スキルの内部テンプレートファイル（dim1-criteria-effectiveness.md）を評価対象エージェント定義として誤って分析している。これは SA-01, SA-02 で特定された critical 問題の根本原因である
- 根拠: 次元2の分析で、{agent_path} として指定されたファイルがテンプレートファイル（`.claude/skills/agent_audit/templates/dim1-criteria-effectiveness.md`）であることが判明。エージェント定義ではなく手順書を分析しているため、すべての findings が無意味
- 推奨: agent_audit スキルの呼び出しフローを確認し、正しい評価対象エージェント定義ファイル（`.claude/agents/*.md` 等）が {agent_path} として渡されるよう修正する。その後、正しい対象ファイルで agent_audit を再実行する
- impact: high（全分析結果の信頼性に影響）, confidence: high（ファイルパスとファイル内容から明確）, effort: low（パラメータ修正のみ）
- agent_bench 向け: なし（agent_audit 自体の実行方法の修正であり、バリアント生成の対象外）

### OM-02: テンプレートの指示明確化（次元1の改善統合） [severity: improvement]
- 内容: CE-01, CE-02, CE-03 で特定された、テンプレート内の曖昧な指示を明確化する。外部参照の具体化、「基準」の定義追加、severity 判定ルールの追加を統合的に実施
- 根拠: 次元1の静的分析で、手順3の外部参照が曖昧（CE-01）、「基準」の定義不足（CE-02）、severity 判定基準の欠如（CE-03）が特定された。これらはすべてサブエージェントの推論負荷を増やし、結果の一貫性を低下させる要因
- 推奨:
  - 手順3を具体化：「静的分析の場合、エージェント定義の各評価基準を以下の4観点で評価する: a.指示の具体性, b.S/N比(H/M/L), c.実行可能性(E/D/I), d.費用対効果(H/M/L)」
  - 手順3冒頭に「基準」の定義を追加：「『基準』とは、エージェント定義内の指示項目（箇条書き、チェックリスト項目、セクション見出し配下の指示群）を指す」
  - 手順4に severity 判定ルールを追加：「severity判定: S/N=L または 実行可能性=I → critical、有効性未確認 または 費用対効果=L → improvement、その他 → info」
- impact: medium（サブエージェントの実行精度向上）, confidence: high（静的分析で明確に特定）, effort: low（テンプレート3箇所の追記）
- agent_bench 向け: バリアント提案1「明示的判定基準を追加したテンプレート」— 手順3, 4に上記の具体化・定義・判定ルールを追加し、暗黙的推論を削減する

### OM-03: ディレクトリ存在検証の追加（運用安定性向上） [severity: improvement]
- 内容: CE-05 で特定された、Write 実行前のディレクトリ存在検証を追加する。parent スキルの責務として Phase 0 でディレクトリを作成するか、各テンプレートで mkdir -p を実行するかを統一
- 根拠: 現在のテンプレートは findings_save_path の親ディレクトリが存在することを前提としているが、明示的な検証・作成指示がない。agent_audit スキルの Phase 0 で prompt-improve/{agent_name}/ ディレクトリを作成する責務が想定されるが、これが明示されていない
- 推奨:
  - 短期対応: 各次元テンプレートの手順5冒頭に「Write 実行前に、findings_save_path の親ディレクトリが存在しない場合は Bash で `mkdir -p` を実行する」を追加
  - 長期対応: agent_audit SKILL.md の Phase 0 に「prompt-improve/{agent_name}/ ディレクトリを作成する」責務を明示し、各テンプレートからは削除
- impact: low（現状で問題発生していない）, confidence: medium（想定される親スキルの責務が未確認）, effort: low（1-2箇所の追記）
- agent_bench 向け: なし（運用安定性の改善であり、バリアント生成の対象外）

## Summary

- dimensions_analyzed: 2/5（次元1, 2のみ。次元3, 4はデータ不足により分析不可）
- critical: 2（SA-01, SA-02 — いずれも誤った対象ファイル指定に起因）
- improvement: 5（CE-01, CE-02, CE-03, CE-05, OM-01, OM-02, OM-03 として統合）
- info: 3（CE-04, SA-03, 静的分析の限界に関する参考情報）
- bench_variants: 1（OM-02 の「明示的判定基準を追加したテンプレート」）
