# improve_seq スキル — ファイル構成

## スキルディレクトリ

```
.claude/skills/improve_seq/
├── SKILL.md                          # メインスキル定義
├── references/
│   └── triage-criteria.md            # トリアージ判定基準の詳細
└── templates/
    ├── analyze-target.md             # Phase 1: 対象の構造理解
    ├── review.md                     # Phase 2: 観点別レビュー実行
    └── apply-improvements.md         # Phase 4: 改善適用
```

### テンプレートの役割

| テンプレート | 使用Phase | サブエージェント種別 | 入力 | 出力 |
|---|---|---|---|---|
| analyze-target.md | Phase 1 | general-purpose | 対象ファイル | target-analysis.md |
| review.md | Phase 2 | general-purpose（観点数分並列） | 対象ファイル + target-analysis.md + 観点 + decisions.md | findings-{id}.md |
| apply-improvements.md | Phase 4 | general-purpose | 対象ファイル + target-analysis.md + triage.md | 対象ファイル更新 + changes.md |

### 親エージェントが直接処理するもの

- **Phase 0 初期化**: ディレクトリ作成、ファイル確認
- **Phase 1 品質ゲート QG-1**: target-analysis.md の品質確認
- **Phase 3 トリアージ**: 判定ロジック + 人間への提示を含むため親が担当
- **Phase 5 サマリ生成**: 全フェーズの集約

## ワーキングディレクトリ

```
.skill_output/improve_seq/${key}/
├── target-analysis.md                # Phase 1 出力: 対象の構造理解
├── decisions.md                      # 人間の判断記録（セッション跨ぎで永続）
├── target-snapshot-before.md         # 改善前のスナップショット
├── target-snapshot-after.md          # 改善後のスナップショット
├── findings-R0.md                    # 固定観点R0のレビュー結果
├── findings-R1.md                    # 動的観点R1のレビュー結果
├── findings-R2.md                    # 動的観点R2のレビュー結果
├── triage.md                         # トリアージ結果
├── changes.md                        # 適用した変更のサマリ
└── summary.md                        # 最終サマリ
```

### ファイルのライフサイクル

| ファイル | 生成 | 更新 | 参照元 |
|---|---|---|---|
| target-analysis.md | Phase 1 | なし | Phase 2, Phase 3, Phase 4 |
| decisions.md | Phase 3（初回判断時に作成） | Phase 3 で追記 | Phase 2, Phase 3 |
| target-snapshot-before.md | Phase 0 | なし | 差分確認用 |
| target-snapshot-after.md | Phase 4 | なし | 差分確認用 |
| findings-{id}.md | Phase 2 | なし | Phase 3 |
| triage.md | Phase 3 | なし | Phase 4 |
| changes.md | Phase 4 | なし | Phase 5 |
| summary.md | Phase 5 | なし | ユーザー |

## データフロー図

```
Phase 0              Phase 1                Phase 2                Phase 3
 対象読み込み ──→  構造理解  ──────→  観点別レビュー(並列)  ──→  トリアージ
 snapshot-before    target-analysis.md   findings-{id}.md        triage.md
                         │                     ↑                    │
                         │               decisions.md ←──── 人間判断記録
                         │               (照合用)              (追記)
                         │
                         ↓
                    Phase 4              Phase 5
                    改善適用  ──────→  完了サマリ
                    changes.md          summary.md
                    snapshot-after
```

※ target-analysis.md は Phase 2（レビュー文脈）と Phase 4（一貫性確認）の両方で参照される
