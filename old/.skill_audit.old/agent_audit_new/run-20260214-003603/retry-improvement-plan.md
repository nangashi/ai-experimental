# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | agent_bench への参照を削除（Phase 1B の agent_bench 連携機能を削除） | C-2 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: C-2: 大規模外部スキル埋め込み - agent_bench スキル全体が内包されている。スキル境界が曖昧

**変更内容**:
- Phase 1B の agent_bench 連携機能を削除: 現在 SKILL.md Line 174 付近に「`.agent_bench/{agent_name}/audit-*.md` からフィードバックを読み込んで活用する」機能があると想定されるが、この機能は agent_audit_new のコア機能ではなく、オプショナルな連携機能のため、削除または別途プラグイン化を推奨
- 外部スキル参照のクリーンアップ: Phase 1 での次元エージェント参照パス（`.claude/skills/agent_audit_new/agents/{dim_path}.md`）は維持（agent_audit_new 本体の一部のため）

## 新規作成ファイル
（なし）

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| agent_bench/ ディレクトリ全体（39ファイル、約220KB） | agent_bench は独立したスキルであり、agent_audit_new の一部として配置されるべきではない。既に `.claude/skills/agent_bench` および `.claude/skills/agent_bench_new` として独立したディレクトリが存在するため、agent_audit_new 内の埋め込みコピーは削除すべき | C-2 |

## 実装順序
1. **agent_bench/ ディレクトリ全体の削除**: agent_audit_new スキルの境界を明確にするため、まず埋め込まれた agent_bench スキル全体を削除する
2. **SKILL.md の修正**: agent_bench への参照（Phase 1B の連携機能等）を削除または無効化し、agent_audit_new のコア機能のみに集中する構造に変更

依存関係の検出方法:
- 削除（1）によって SKILL.md の参照が壊れる可能性があるため、削除後に参照箇所を修正（2）
- ただし analysis.md Line 77 によれば、SKILL.md Line 174 は `.agent_bench/{agent_name}/` ディレクトリを参照しており、これはプロジェクトルート直下の `.agent_bench/` 出力ディレクトリを指しているため、`.claude/skills/agent_audit_new/agent_bench/` の削除による直接的な影響はない可能性が高い
- 念のため SKILL.md を確認し、agent_bench スキル本体への参照がある場合のみ修正する

## 注意事項
- agent_bench/ ディレクトリの削除により、agent_audit_new スキルのコンテキスト予算が大幅に削減される（39ファイル、約7000行分）
- 削除後も agent_bench スキルは独立して `.claude/skills/agent_bench_new/` として利用可能
- Phase 1B の agent_bench 連携機能（`.agent_bench/{agent_name}/audit-*.md` 参照）は、プロジェクトルート直下の出力ディレクトリを参照するため、スキル埋め込みの削除による影響は受けない。ただし、この連携機能自体が agent_audit_new のコア機能に必須かどうかを再検討すべき
- 変更によって既存のワークフロー（Phase 0-3）が壊れないこと
- agent_audit_new スキルの独立性と明確なスキル境界の確立が本変更の主目的
