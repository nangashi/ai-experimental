# implement_p1_p2_p3_skills

## 目的

classification.md で定義された P1/P2/P3 の 3 フェーズに対応するスキルを、設計書（history/04〜06）に基づいて実装する。既存の arch_design/process_design スキルは old/ に退避し、スキル間の連鎖（次のステップ案内）と extract_decisions の入力参照も新体制に合わせて更新する。

## ゴール

- [x] 既存 `arch_design` が `old/arch_design.old/` に退避されている → `old/arch_design.old/`
- [x] 既存 `process_design` が `old/process_design.old/` に退避されている → `old/process_design.old/`
- [x] 新 `arch_design` スキルが 04 設計書に従って実装されている（全ファイル新規作成） → `.claude/skills/arch_design/`
- [x] 新 `standards_design` スキルが 05 設計書に従って実装されている（全ファイル新規作成） → `.claude/skills/standards_design/`
- [x] 新 `process_design` スキルが 06 設計書に従って実装されている（全ファイル新規作成、06 の `dev_process` を `process_design` に命名変更） → `.claude/skills/process_design/`
- [x] スキル間の次のステップ連鎖が更新されている（arch_design → standards_design → process_design → extract_decisions）
## スコープ

- `.claude/skills/arch_design/` の新規作成
- `.claude/skills/standards_design/` の新規作成
- `.claude/skills/process_design/` の新規作成（06 設計の `dev_process` を命名変更）
- 既存スキルの `old/` 退避

## スコープ外

- `extract_decisions` の更新（入力ファイル・出力セクションの再設計が必要、別途対応）
- CLAUDE.md の Instructions テーブル更新（別途対応）
- agent 定義ファイル（`.claude/agents/`）の変更
- 設計書（history/04〜06）自体の修正

## 前提条件

- 設計書（history/04〜06）はレビュー済み・承認済み
- classification.md の P1/P2/P3 分類は確定済み
