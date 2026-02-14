# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 4のグループ分類をサブエージェント委譲から親の直接実装に変更 | I-4: Phase 0 グループ分類サブエージェントは直接実装可能 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-4: Phase 0 グループ分類サブエージェントは直接実装可能

**変更内容**:
- **Phase 0 Step 4のグループ分類ロジック**: Task ツールでのサブエージェント委譲を削除し、親エージェントが直接分類を実行する
  - 現在: `Task` ツールで haiku サブエージェントに group-classification.md を Read させ、グループ判定を委譲している（84-94行）
  - 改善後: 親が直接 group-classification.md を Read し、evaluator/producer 特徴の4項目チェックを実行し、判定ルールに従ってグループを決定する
  - 実装方法:
    1. Read で `{skill_path}/group-classification.md` と `{agent_path}` を読み込む
    2. evaluator 特徴4項目のマッチ数をカウント（評価基準・検出ルール、findings出力構造、severity分類、評価スコープの存在）
    3. producer 特徴4項目のマッチ数をカウント（ワークフロー構造、成果物出力、変換・加工処理、ツール操作手順の存在）
    4. 判定ルール適用（hybrid → evaluator → producer → unclassified の順）
    5. `{agent_group}` に結果を格納
  - エラーハンドリング: 分類失敗時は unclassified をデフォルト値として使用（既存の警告表示ロジックは保持）

## 新規作成ファイル
なし

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/analyze-dimensions.md | テンプレートが実質パス変数展開のみで冗長。SKILL.md Phase 1から既に直接委譲に変更済みで物理ファイルのみ残存 | I-7: Phase 1 analyze-dimensions.md テンプレートは冗長 |

## 実装順序
1. **templates/analyze-dimensions.md の削除** — 残存ファイルの削除のみで依存関係なし
2. **SKILL.md の Phase 0 Step 4 修正** — グループ分類を親の直接実装に変更

依存関係の検出方法:
- analyze-dimensions.md は既に SKILL.md から参照されていないため、削除しても影響なし
- SKILL.md の修正は独立した変更であり、analyze-dimensions.md の有無に依存しない
- 両者に依存関係はないが、クリーンアップ（削除）を先に実行し、その後機能変更（グループ分類の直接実装）を行う順序が論理的

## 注意事項
- SKILL.md Phase 0 Step 4の変更によって、group-classification.md の役割が「サブエージェント向けプロンプト」から「親エージェント向け判定基準ドキュメント」に変わる。group-classification.md の内容は変更不要だが、冒頭に「この基準は親エージェントが直接使用します」といった説明を追加するか検討する（今回の改善計画には含めない）
- Phase 0 Step 4のエラーハンドリング（抽出失敗時のデフォルト値 unclassified、警告表示）は既存ロジックを保持する
- テンプレートファイル削除後、templates/ ディレクトリ内に残るファイルは apply-improvements.md のみとなる
