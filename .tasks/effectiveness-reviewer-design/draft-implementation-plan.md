# 有効性レビューアー追加の実装計画

## 変更対象ファイル

| # | ファイル | 変更種別 | 変更概要 |
|---|---------|---------|---------|
| 1 | `templates/reviewer-effectiveness.md` | 新規作成 | 有効性レビューアーテンプレート |
| 2 | `quality-criteria.md` | 修正 | 「5. 有効性・目的達成度」セクション追加 |
| 3 | `SKILL.md` | 修正 | Phase 2 のレビューアーを4→5に変更、Phase 3/7 の件数更新 |

## SKILL.md の変更詳細

### Phase 2 の変更
- レビュータスク数: 4件 → 5件
- レビューアーリスト: stability, efficiency, ux, architecture, effectiveness
- テンプレートテーブルに `reviewer-effectiveness.md` / `{work_dir}/review-effectiveness.md` を追加
- 並列起動を5件に変更

### Phase 3 の変更
- 最低基準: 3件 → 4件（5件中4件成功で続行）
- コンフリクトパターンに有効性レビューアー固有の想定パターンを追加:
  - 有効性「フェーズを追加すべき」↔ 効率性「フェーズが多すぎる」→ 目的達成に不可欠なら有効性優先

### Phase 7 の変更
- レビュー観点数: 4 → 5
- レビューアーリスト更新
