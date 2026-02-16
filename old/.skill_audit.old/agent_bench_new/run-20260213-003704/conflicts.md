## コンフリクト

### CONF-1: Phase 0 perspective 自動生成のモード選択
- 側A: [ux] perspective 自動生成モード選択をデフォルト化し、初回は簡略モード、エラー発生時のみ標準モードに自動切り替えする設計にすれば、ユーザー確認を削減できる
- 側B: [efficiency] 初回実行時はデフォルトで簡略版を使用し、エラー発生時のみ標準モード（4並列批評）に自動フォールバックする設計に変更する
- 対象findings: C-9（該当項目は重大な問題として採用済み。ux レビューの改善提案は同一の提案）

### CONF-2: agent_audit 参照の扱い
- 側A: [architecture] agent_audit スキルが出力パスを明示的に返す設計に変更するか、パラメータ化して skill 内に audit 結果をコピーする仕組みを導入する
- 側B: [effectiveness] Phase 0 で agent_audit の実行有無を確認し、未実行の場合は Phase 1B で audit 統合をスキップする旨をユーザーに説明する
- 対象findings: I-4, I-7（両方とも改善提案として採用済み。architecture は実装変更、effectiveness はユーザー通知の改善を推奨）
