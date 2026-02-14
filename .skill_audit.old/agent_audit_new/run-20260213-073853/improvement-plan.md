# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/phase2-per-item-approval.md | 新規作成 | Phase 2 Step 2a の Per-item 承認ループを外部化 | C-1 |
| 2 | templates/phase1-failure-handling.md | 新規作成 | Phase 1 部分失敗時の継続判定ロジックを外部化 | I-3 |
| 3 | templates/generate-completion-summary.md | 新規作成 | Phase 3 の完了サマリ生成を外部化 | I-6 |
| 4 | SKILL.md | 修正 | Phase 2 詳細手順・検証詳細・Phase 1 判定ロジック・Phase 3 詳細をテンプレート参照に置換 | C-1, C-2, C-3, C-5, C-7, I-1, I-2, I-3, I-5, I-6, I-8, I-9 |
| 5 | templates/apply-improvements.md | 修正 | 30行超過時のルール明記 | C-4 |
| 6 | templates/collect-findings.md | 修正 | 件数カウント指示の明記 | I-7 |

## 各ファイルの変更詳細

### 1. templates/phase2-per-item-approval.md（新規作成）
**対応フィードバック**: C-1: SKILL.md超過

**変更内容**:
- Phase 2 Step 2a の Per-item 承認ループ詳細手順をテンプレートとして外部化
- フォーマット: findings-summary.md を読み込み、各 finding を順に提示、ユーザー判定（承認/スキップ/残りすべて承認/キャンセル）を収集
- 返答: 4行（approved_count, skipped_count, approved_ids, skipped_ids）

### 2. templates/phase1-failure-handling.md（新規作成）
**対応フィードバック**: I-3: Phase 1 部分失敗時の継続判定ロジックが長い

**変更内容**:
- Phase 1 部分失敗時の継続判定ロジック（成功基準チェック、中止条件判定、fast mode 分岐、AskUserQuestion）を外部化
- 入力: dimension 成功/失敗ステータス、fast_mode フラグ
- 返答: 2行（decision: continue/abort, reason: 判定理由）

### 3. templates/generate-completion-summary.md（新規作成）
**対応フィードバック**: I-6: Phase 3 の完了サマリが詳細すぎる

**変更内容**:
- Phase 3 完了サマリの生成（条件分岐を含む出力ロジック）をテンプレートに外部化
- 入力: agent_name, agent_path, agent_group, dim_count, findings 統計、承認統計、backup_path, validation_failed フラグ
- 返答: 完全な完了サマリテキスト（親はそのまま出力）

### 4. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-3, C-5, C-7, I-1, I-2, I-3, I-5, I-6, I-8, I-9

**変更内容**:
- Phase 0 Step 3 直後: group-classification.md 実在確認を追加（Bash で存在確認、不在時エラー終了）[C-7]
- Phase 1 並列起動直後: 各次元完了時のリアルタイム出力指示を追加（「✓ {次元名} 完了」）[I-8]
- Phase 1 部分失敗判定: SKILL.md:209-217 を templates/phase1-failure-handling.md テンプレート委譲に置換 [I-3]
- Phase 2 Step 1 完了後: findings-summary.md を Read する処理を明記 [I-1]
- Phase 2 Step 1 エラー確認（SKILL.md:265-268）: else節を追記（「存在しない場合は次のステップへ進む」）[C-5]
- Phase 2 Step 2a: SKILL.md の詳細記述を削除し、templates/phase2-per-item-approval.md テンプレート委譲に置換 [C-1]
- Phase 2 Step 4 直前: サブエージェントに進捗メッセージ出力指示を追加 [I-9]
- Phase 2 検証ステップ（SKILL.md:320-341）: 検証詳細記述を削除、返答パース情報のみ保持。analysis_path の存在判定ロジックを明記（Bash で .skill_audit/ ディレクトリ検索 → 最新 run-* ディレクトリの analysis.md を取得、不在時は省略）[C-2, C-3, I-2]
- Phase 3 完了サマリ（SKILL.md:345-369）: 詳細記述を削除し、templates/generate-completion-summary.md テンプレート委譲に置換 [I-6]
- Phase 0 Step 4 グループ分類サブエージェント: 失敗時のフォールバック処理を追加（デフォルトグループ: unclassified）[I-5]

### 5. templates/apply-improvements.md（修正）
**対応フィードバック**: C-4: 出力フォーマット決定性: サブエージェント返答の曖昧さ

**変更内容**:
- 行36-42: 「上限: 30行以内」 → 「上限: 30行。30行を超える場合は重要度順（critical findings → improvement findings）に上位30行まで記載し、残りは `...（他 N 件）` と省略する」

### 6. templates/collect-findings.md（修正）
**対応フィードバック**: I-7: 出力フォーマット決定性: 件数取得失敗時の処理不足

**変更内容**:
- 手順 2: findings 抽出時に「各 finding をカウントし、total/critical/improvement 件数を集計する」を明記
- 手順 4: 「統計セクションに集計した件数を記載する」を明記

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase2-per-item-approval.md | Phase 2 Step 2a の Per-item 承認ループ詳細を外部化 | C-1 |
| templates/phase1-failure-handling.md | Phase 1 部分失敗時の継続判定ロジックを外部化 | I-3 |
| templates/generate-completion-summary.md | Phase 3 完了サマリ生成を外部化 | I-6 |

## 削除推奨ファイル
（なし）

## 実装順序
1. **新規テンプレート3件作成** (phase2-per-item-approval.md, phase1-failure-handling.md, generate-completion-summary.md)
   - 理由: SKILL.md がこれらのテンプレートを参照するため、先に作成する必要がある
2. **templates/collect-findings.md 修正** (件数カウント指示明記)
   - 理由: SKILL.md の依存関係はないが、Phase 2 Step 1 の動作改善のため早期実施
3. **templates/apply-improvements.md 修正** (30行超過ルール明記)
   - 理由: SKILL.md の依存関係はないが、Phase 2 Step 4 の動作改善のため早期実施
4. **SKILL.md 修正** (テンプレート参照追加、詳細記述削除、ロジック追加)
   - 理由: 新規テンプレートが存在してから SKILL.md を変更することで、参照整合性を保つ

## 注意事項
- 新規テンプレートのパス変数定義が SKILL.md で正しく記載されていることを確認する
- Phase 2 Step 2a, Phase 1 部分失敗判定, Phase 3 完了サマリの委譲が正常に動作することを検証する
- analysis_path の存在判定ロジック（Bash による .skill_audit/ ディレクトリ検索）が正しく機能することを確認する
- バックアップ `.prev` の重複上書き問題（C-6）は承認されているが、タイムスタンプ付きバックアップへの変更はスコープ外として今回の改善計画には含めていない（将来的な検討事項として記録）
