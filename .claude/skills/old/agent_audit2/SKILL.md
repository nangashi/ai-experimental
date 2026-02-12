# agent_audit2

自身の分析サブエージェントを自律的・継続的に改善する自己改善型スキル。
`claude -p` の無限ループにより、分析テンプレートの問題検出能力を評価→分析→改善→検証→知見蓄積のサイクルで自動最適化する。

## 使い方

```
/agent_audit2
```

引数なし。実行すると初期化処理を行い、ループ開始コマンドを表示する。

## 初期化処理

1. `.task/infinite_update_agent_audit2/` の作業ディレクトリが存在するか確認
2. 既にファイルが配置済みの場合はスキップし、ループコマンドを表示
3. 未配置の場合は全ファイルを生成

## ループ開始

初期化完了後、以下のコマンドでループを開始する:

```bash
bash .task/infinite_update_agent_audit2/run.sh
```

## 監視方法

- 実行ログ: `tail -f .task/infinite_update_agent_audit2/run.log`
- 改善履歴: `cat .task/infinite_update_agent_audit2/history.md`
- 現在状態: `cat .task/infinite_update_agent_audit2/state.json`
- 蓄積知見: `cat .task/infinite_update_agent_audit2/knowledge.md`

## 最適化対象

以下の分析サブエージェントテンプレートを巡回改善する:

- `analyze-criteria` — 基準有効性分析（評価基準の具体性・実行可能性）
- `analyze-scope` — スコープ整合性分析（境界の明確さ・適切さ）
- `analyze-blind-spots` — 盲点検出分析（系統的検出失敗の特定）
- `analyze-domain-knowledge` — ドメイン知識充足度分析（知識の網羅性）

## 評価方法

1. テストエージェント定義（既知の問題が埋め込まれたレビューエージェント定義）を生成
2. 分析サブエージェントを実行して問題検出率を測定（2回実行で安定性確認）
3. 検出ギャップを分析してテンプレートの改善案を生成
4. 改善適用後に再測定して効果を確認

## 停止

- 全サブエージェントの改善が収束すると自動停止（STOPファイル生成）
- 手動停止: `Ctrl+C` または `touch .task/infinite_update_agent_audit2/STOP`

## Safety Constraints

修正可能なファイル:
- `.task/infinite_update_agent_audit2/**`
- `.claude/skills/agent_audit2/**`
- `.claude/skills/test_*/**`

上記以外のファイルは絶対に変更しない。
