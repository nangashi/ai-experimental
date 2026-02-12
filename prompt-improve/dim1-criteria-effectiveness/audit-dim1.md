# Dim 1: 基準有効性 (Criteria Effectiveness)

- agent_name: dim1-criteria-effectiveness
- analysis_mode: 静的
- analyzed_at: 2026-02-12

## 基準別評価テーブル
| 基準 | S/N比 | 実行可能性 | 費用対効果 | 判定 |
|------|-------|-----------|-----------|------|
| 手順1: ファイル読み込み指示 | H | E | H | 有効 |
| 手順2: 分析モード決定ロジック | H | E | H | 有効 |
| 手順3: audit-criteria.md 参照指示 | M | D | M | 有効性未確認 |
| 手順4: Finding フォーマット要件 | H | E | H | 有効 |
| 手順5: Write 出力要件 | H | E | H | 有効 |
| 手順6: サマリ返答要件 | H | E | H | 有効 |

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

## Summary

- critical: 0
- improvement: 3
- info: 2
