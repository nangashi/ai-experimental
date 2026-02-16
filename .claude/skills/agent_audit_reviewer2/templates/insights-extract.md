以下の手順で proven-insights.md をエージェント横断の知見で更新してください:

1. Read で以下を読み込む:
   - {proven_insights_path} （現在のクロスエージェント知見）
   - {history_path} （更新済みの最適化履歴）
   - {report_save_path} （今回の比較レポート）

2. history.md の以下から今回の知見を抽出する:
   - 「Effective Changes」テーブルの最新エントリ
   - 「Ineffective Changes」テーブルの最新エントリ
   - 比較レポートの「考察」セクション

3. 昇格条件を判定する:

   **Section 1 (Error→Fix Patterns)**:
   - effect >= +1.5pt AND SD <= 0.5 AND 回帰なし

   **Section 2 (Generally Effective Patterns)**:
   - effect >= +2.0pt AND SD <= 0.25 AND 回帰なし

   **Section 3 (Anti-Patterns)**:
   - effect <= -1.5pt、または回帰あり（カテゴリ検出率低下 0.15 以上）

   **昇格なし**: |effect| < 1.0pt、SD > 1.0、回帰なしの微改善

4. 昇格対象がある場合、proven-insights.md を更新する:
   - 既存エントリは削除しない（preserve + integrate）
   - 同じパターンの場合: 効果範囲を拡大し Source 列を更新
   - 出典形式: `{agent_name}:R{round}`
   - サイズ制限: Section 1: 10件、Section 2: 8件、Section 3: 8件
   - メタデータ（HTML コメント）を更新

5. 以下のフォーマットで返答する:

   昇格あり:
   proven-insights.md 更新完了（promoted: {N}件, updated: {M}件, skipped: {K}件）

   昇格なし:
   proven-insights.md 更新なし（promotion条件未達）
