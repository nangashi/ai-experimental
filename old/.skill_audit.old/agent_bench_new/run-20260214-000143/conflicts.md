## コンフリクト

### CONF-1: SKILL.md:54, 74 - 外部参照パスの修正範囲
- 側A: [architecture] `.claude/skills/agent_bench/perspectives/{target}/{key}.md` と `.claude/skills/agent_bench/perspectives/design/*.md` を `.claude/skills/agent_bench_new/perspectives/` に修正すべき
- 側B: [stability] `.claude/skills/agent_bench/perspectives/{target}/{key}.md` への参照を「スキルディレクトリ内への perspective ファイルのコピーまたはパス変数での明示」で対処すべき
- 対象findings: C-1, C-2
