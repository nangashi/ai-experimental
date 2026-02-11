以下の手順で proven-techniques.md をエージェント横断の知見で更新してください:

1. Read で以下を読み込む:
   - {proven_techniques_path} （現在のスキルレベル知見）
   - {knowledge_path} （更新済みのエージェント単位ナレッジ）
   - {report_save_path} （今回の比較レポート）

2. knowledge.md の以下のセクションから、今回のラウンドで得られた知見を抽出する:
   - 「効果が確認された構造変化」テーブル
   - 「効果が限定的/逆効果だった構造変化」テーブル
   - 「改善のための考慮事項」セクション

3. 各知見について、以下の昇格条件を順に判定する:

   **Tier 1: 即時昇格**
   - effect ≥ +2.5pt AND SD ≤ 0.25 → Section 1（実証済み効果テクニック）に追加/更新
   - effect ≤ -2.5pt AND SD ≤ 0.5 → Section 2（回避すべきアンチパターン）に追加/更新
   - 同じテクニックが knowledge.md 内で 2+ エージェントの出典を持ち effect ≥ +1.0pt → Section 1
   - 同じテクニックが 2+ エージェントで effect ≤ -1.0pt → Section 2

   **Tier 2: 条件付き昇格**
   - あるエージェントで正効果、別エージェントで負効果（双方 |effect| ≥ 1.0pt）→ Section 3（条件付き）
   - 同一エージェントの 3+ ラウンドで確認済み、effect ≥ +1.0pt → Section 1

   **Tier 3: 昇格なし**
   - |effect| < 1.0pt、SD > 1.0、MARGINAL ステータス、または単一ラウンドで +2.5pt 未満 → スキップ

4. 昇格対象がある場合、proven-techniques.md を以下のルールで更新する:

   **統合ルール（preserve + integrate）**:
   - 既存エントリは削除しない。矛盾するエビデンスがある場合は Section 3 へ移動する
   - 既存エントリと同じテクニックの場合: 効果範囲を拡大し、出典列を更新する
   - 新規エントリの場合: 該当セクションの末尾に追加する
   - 出典列の形式: `{agent1}:{rounds}, {agent2}:{rounds}` (例: `sec:16,perf:4`)

   **サイズ制限の遵守**:
   - Section 1: 最大8エントリ。超過時は最も類似する2エントリをマージして1つにする
   - Section 2: 最大8エントリ。同上
   - Section 3: 最大7エントリ。超過時はエビデンスが最も弱いエントリを削除する
   - Section 4（ベースライン構築ガイド）: 新たな実証済みテクニックが既存ガイドラインと矛盾する場合のみ更新

   **メタデータの更新**:
   - ファイル先頭の HTML コメント内の Last updated 日付、Agents 数、Rounds 数を更新する

5. 以下のフォーマットで確認のみ返答する:

   昇格対象がある場合:
   proven-techniques.md 更新完了（promoted: {N}件, updated: {M}件, skipped: {K}件）

   昇格対象がない場合:
   proven-techniques.md 更新なし（promotion条件未達）
