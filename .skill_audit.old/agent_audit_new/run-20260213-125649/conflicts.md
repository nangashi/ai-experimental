## コンフリクト

### CONF-1: Phase 0 の agent_path 上書き vs 既存ファイル保護
- 側A: [stability] Phase 0 Step 5 の perspective 再生成で上書き保存後、検証失敗するとリカバリ不能（Step 3 の初期生成版も失われる）
- 側B: [architecture] Phase 0 の knowledge.md 検証失敗時に再初期化で自動復旧する設計は良い点として評価
- 対象findings: C-1

### CONF-2: Phase 3 の削除処理 vs 冪等性設計
- 側A: [architecture] Phase 3 開始前の一括削除（`rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md`）が再試行時に競合リスクを引き起こす
- 側B: [efficiency] 既存ファイルの削除は効率的なクリーンアップとして理解できるが、部分失敗時の再試行で成功済みプロンプトの結果も削除される
- 対象findings: C-4
