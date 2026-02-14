## コンフリクト

### CONF-1: SKILL.md:54, perspectives フォールバック
- 側A: [architecture] perspectives ディレクトリを agent_bench_new スキル内にコピーすべき（外部スキルディレクトリへの参照は保守性を下げる）
- 側B: [stability] perspectives ディレクトリを agent_bench_new スキル内にコピーするか、初期セットアップ時のコピー指示に変更すべき（外部参照である旨と依存ディレクトリのパスを明示する）
- 対象findings: C-2, I-2
