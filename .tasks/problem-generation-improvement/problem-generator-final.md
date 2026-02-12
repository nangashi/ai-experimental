# Problem Generator — Final Version

type-aware + problem-bank + answer-key + validation-gate の統合版。
Phase C の評価実験で baseline を 13-36% 上回った hybrid バリアントをベースに、
バリデーション強化を追加。

## 選定根拠
- 静的スコア: 9.1/10 (baseline: 6.7-8.0)
- 入力型整合性: 全実験で Pass
- タスク整合性: 3/3 (baseline: 2/3)
- カバレッジ: 3/3 (baseline: 2-3/3)
- Problem Bank 方式により ○/△/× 判定基準の一貫性と採点精度を向上

## 統合元
- v001-variant-type-bank-hybrid.md (メインロジック)
- v001-variant-validation-gate.md (Step 5 バリデーション強化)

## agent_create への統合方法
- test-scenario-guide.md を本ファイルの内容で更新
- phase2-test-set.md のテンプレートを更新して新ガイドを参照
