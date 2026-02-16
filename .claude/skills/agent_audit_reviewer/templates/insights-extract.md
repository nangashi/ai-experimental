以下の手順で proven-insights.md をエージェント横断の知見で更新してください:

1. Read で以下を読み込む:
   - {proven_insights_path} （現在のクロスエージェント知見）
   - {proven_techniques_path} （agent_bench の実証済みテクニック — 参照のみ、更新しない）
   - {history_path} （更新済みの最適化履歴）
   - {report_save_path} （今回の比較レポート）

2. history.md の以下のセクションから今回のラウンドで得られた知見を抽出する:
   - 「Effective Changes」テーブルの最新エントリ
   - 「Ineffective Changes」テーブルの最新エントリ
   - 比較レポートの「考察」セクション

3. 各知見について以下の昇格条件を判定する:

   **Section 1 (Error→Fix Patterns) への昇格条件**:
   - effect >= +1.5pt AND SD <= 0.5: 「エラーカテゴリ → 修正パターン」の対応として追加
   - 同じエラー→Fix パターンが 2+ エージェントで確認された場合（proven-insights.md の既存エントリの Source 列と照合）

   **Section 2 (Generally Effective Patterns) への昇格条件**:
   - effect >= +2.0pt AND SD <= 0.25: 一般的に有効なパターンとして追加
   - proven-techniques.md の既存エントリと同じパターンの場合: 出典を追加する

   **Section 3 (Anti-Patterns) への昇格条件**:
   - effect <= -1.5pt: アンチパターンとして追加
   - 2+ エージェントで逆効果が確認された場合

   **昇格なし**:
   - |effect| < 1.0pt
   - SD > 1.0
   - 単一ラウンドで +1.5pt 未満

4. 昇格対象がある場合、proven-insights.md を更新する:
   - 既存エントリは削除しない（preserve + integrate）
   - 同じパターンの場合: 効果範囲を拡大し出典（Source列）を更新する
   - 新規パターンの場合: 該当セクションの末尾に追加する
   - 出典形式: `{agent_name}:R{round}` (例: `agents/security-design-reviewer:R3`)

   **サイズ制限**:
   - Section 1: 最大10エントリ。超過時は最も類似するエントリをマージする
   - Section 2: 最大8エントリ。同上
   - Section 3: 最大8エントリ。エビデンスが最も弱いエントリを削除する

   **メタデータ更新**: HTML コメントの Last updated、Agents、Rounds を更新する

5. 以下のフォーマットで確認のみ返答する:

   昇格対象がある場合:
   proven-insights.md 更新完了（promoted: {N}件, updated: {M}件, skipped: {K}件）

   昇格対象がない場合:
   proven-insights.md 更新なし（promotion条件未達）
