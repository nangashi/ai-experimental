# Reviewer Optimize Knowledge: performance-design

## 対象エージェント
- **観点**: performance
- **対象**: design
- **エージェント定義**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/agents/performance-design-reviewer.md
- **累計ラウンド数**: 12

## パフォーマンス改善の要素

### 効果が確認された構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| baseline (最小限の指示) | +0.75 ~ +1.5 | 0.0 | Round 001 | 完璧な安定性、最多ボーナス検出（6項目/Run）|
| NFRチェックリスト構造化 (N1a) | +3.0 | 0.5 | Round 002 | NFR仕様欠如問題（P03, P09）で+4.0pt検出向上、ボーナス検出+1.0pt |
| 検出ヒント埋め込み (N3a) | +2.0 | 0.0 | Round 002 | ボーナス検出+1.5pt、P09監視戦略+2.0pt改善 |
| カテゴリ分解構造化 (新規) | +2.0 | 0.35 | Round 003 | P02チャットブロードキャストN+1明確検出、ペナルティ排除 |
| データライフサイクル&容量計画チェックリスト (M2b) | +2.25 | 0.0 | Round 003 | P09アーカイブ長期増大完全検出（0/2→2/2）、完全安定性達成 |
| 英語指示への変更 (L1b) | +1.5 | 0.0 | Round 004 | P04/P06/P08検出精度向上、ボーナス検出安定化（5件/Run）、完全安定性達成 |
| カテゴリ分解構造化 (Decomposition) | +2.0 | 0.25 | Round 006 | P03/P08検出安定化、ボーナス検出4.5項目/Run、SD=0.25の高安定性達成 |
| NFRチェックリスト+アンチパターンカタログ参照 (N1a+catalog) | +1.5 | 0.5 | Round 007 | P04無制限クエリ完全検出(+2.0pt)、P09データライフサイクル完全検出(+2.0pt)、P07通知スケーリング完全検出(+1.0pt) |
| 優先度分類優先アプローチ (Priority-First Severity Classification) | +1.75 | 0.25 | Round 009 | P09競合状態初検出（全ラウンド初）、P08 WebSocketスケーラビリティ部分検出、高ボーナス多様性（平均5.5項目）、ゼロペナルティ、高安定性（SD=0.25）|
| Priority-First + WebSocket/並行制御軽量ヒント (priority-websocket-hints) | +0.5 | 0.0 | Round 010 | P08 WebSocket完全検出（○/○）、P09競合状態部分検出（△/△）、完全安定性（SD=0.0）、ボーナス検出保持（4項目/Run）、軽量ヒントにより探索的思考維持 |

### 効果が限定的/逆効果だった構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| Few-shot example追加 (S1a) | -0.75 | 0.25 | Round 001 | P04容量設計検出は向上したがボーナス検出減少 |
| Explicit scoring rubric (C1a) | -1.5 | 1.0 | Round 001 | P06検出向上も不安定性増加、ボーナス検出減少 |
| 検出ヒント埋め込み (N3a) | +2.0 | 0.0 | Round 002 | ボーナス検出は最多だがN+1検出精度低下（-1.25pt）、P10検出減少（-0.5pt）|
| 構造化Scoring Rubric (S2a/S2b) | -0.5 | 0.5 | Round 004 | P06検出安定化も、P02/P10完全未検出、評価モード誘発により探索的思考抑制 |
| Query Pattern Detection - antipattern focus (N2a) | -1.25 | 0.0 | Round 005 | P07/P10検出向上(+1.0pt)もP01 NFR検出喪失(-1.0pt)、ペナルティ増加(-0.75pt) |
| Query Pattern Detection - pattern matching focus (N2a) | -3.5 | 0.25 | Round 005 | P01/P07/P08/P10完全未検出、パターンマッチモードがNFR/インフラ分析を抑制 |
| Baseline (Round 006テスト) | -3.0 | 1.25 | Round 006 | Round 005の10.25→7.25に退行、SD=0.25→1.25に悪化、ボーナス検出2.5→1.0に減少 |
| アンチパターンカタログのトレードオフ | -1.25 | - | Round 007 | P10並行制御検出回帰(○/○→×/△, -1.25pt)、ボーナス多様性低下(5件→3件, -1.25pt) |
| CoT Steps Structure (明示的思考段階構造化) | -0.25 | 0.75 | Round 009 | ペナルティ排除成功も、P02完全未検出（Run1）、P03/P05部分検出劣化（Run2）、段階完了バイアスにより包括的カバレッジ低下 |
| NFR+並行制御チェックリスト統合 (N1c) | -1.75 | 0.25 | Round 010 | P01 NFR完全検出（○/○, +2.0pt）、80%完全検出率達成も、スコープ逸脱（9件reliability候補）によりボーナス検出完全喪失（0項目, -2.5pt）、P02 N+1未検出（-2.0pt）、満足化バイアス確認 |
| Priority-First + N+1/Batch Hints (4 hints total) | -2.75 | 0.75 | Round 011 | 4件の軽量ヒント（WebSocket/並行制御/N+1/バッチ処理）は満足化バイアス閾値を超過し、P01 NFR検出喪失（-2.0pt）、P04無制限クエリ検出失敗（-1.0pt）、P05非同期処理検出喪失（-1.0pt）、reliabilityスコープ逸脱（タイムアウト/サーキットブレーカー推奨で-0.5pt×2回）を誘発。N+1ヒントはパターンマッチモード化、バッチヒントはreliability思考を誘発 |

### バリエーションステータス
| Variation ID | Status | Round | Effect (pt) | Notes |
|-------------|--------|-------|-------------|-------|
| S1a | MARGINAL | 001 | -0.75 | P04容量設計検出向上も総合スコア劣位 |
| S1b | UNTESTED | - | - | |
| S1c | UNTESTED | - | - | |
| S1d | UNTESTED | - | - | |
| S1e | UNTESTED | - | - | |
| S2a | UNTESTED | - | - | |
| S2b | UNTESTED | - | - | |
| S2c | UNTESTED | - | - | |
| S3a | UNTESTED | - | - | |
| S3b | UNTESTED | - | - | |
| S3c | UNTESTED | - | - | |
| S4a | UNTESTED | - | - | |
| S4b | UNTESTED | - | - | |
| S5a | UNTESTED | - | - | |
| S5b | UNTESTED | - | - | |
| S5c | UNTESTED | - | - | |
| C1a | INEFFECTIVE | 001 | -1.5 | P06検出向上も不安定性増加、ボーナス検出減少 |
| C1b | UNTESTED | - | - | |
| C1c | UNTESTED | - | - | |
| C2a | UNTESTED | - | - | |
| C2b | UNTESTED | - | - | |
| C2c | UNTESTED | - | - | |
| C3a | UNTESTED | - | - | |
| C3b | UNTESTED | - | - | |
| C3c | UNTESTED | - | - | |
| N1a | EFFECTIVE | 002 | +3.0 | NFR仕様欠如問題で+4.0pt検出向上、Round 002推奨 |
| N1b | UNTESTED | - | - | |
| N1c | UNTESTED | - | - | |
| N2a | UNTESTED | - | - | |
| N2b | UNTESTED | - | - | |
| N2c | UNTESTED | - | - | |
| N3a | MARGINAL | 002 | +2.0 | ボーナス検出最多(4.0)だが基礎検出精度低下 |
| N3b | UNTESTED | - | - | |
| N3c | UNTESTED | - | - | |
| M1a | UNTESTED | - | - | |
| M1b | UNTESTED | - | - | |
| M2a | UNTESTED | - | - | |
| M2b | EFFECTIVE | 003 | +2.25 | データライフサイクル特化でP09完全検出、SD=0.0達成 |
| M2c | UNTESTED | - | - | |
| L1a | UNTESTED | - | - | |
| L1b | EFFECTIVE | 004 | +1.5 | 英語指示により技術用語の意味解釈明確化、完全安定性達成 |
| S2a | INEFFECTIVE | 004 | -0.5 | Broad Mode: NFRチェックリスト重視、評価モード誘発 |
| S2b | INEFFECTIVE | 004 | -0.5 | Deep Mode: 実装詳細分析重視、部分検出消失 |
| N2a | INEFFECTIVE | 005 | -1.25 ~ -3.5 | antipattern: P01 NFR喪失+ペナルティ, pattern matching: NFR/インフラ分析抑制 |
| N2b | UNTESTED | - | - | |
| N2c | UNTESTED | - | - | |
| Decomposition | EFFECTIVE | 006 | +2.0 | Category breakdown structure stabilizes detection (SD=0.25), high bonus diversity (4.5/run) |
| N1a+Antipattern Catalog | EFFECTIVE | 007 | +1.5 | NFR checklist + catalog reference. Superior unbounded query (+2.0pt), data lifecycle (+2.0pt), notification (+1.0pt) detection. Trade-off: concurrency regression (-1.25pt), lower bonus diversity (-1.25pt) |
| N1c | MARGINAL | 008 | -0.25 | Concurrency checklist addition. Superior P09 race condition (+2.0pt), P06 data lifecycle (+1.75pt) detection, better stability (SD 0.25). Trade-off: P05 algorithm complexity regression (-1.75pt), P08 WebSocket scaling (-1.0pt), bonus diversity loss (-0.75pt). Checklist satisficing reduces exploratory scope. |
| CoT-Steps | INEFFECTIVE | 009 | -0.25 | Explicit CoT steps (NFR → Architecture → Implementation → Cross-cutting). Zero penalties but P02 complete miss (Run1), P03/P05 partial detection degradation (Run2). Step completion bias reduces comprehensive coverage. |
| Priority-First | EFFECTIVE | 009 | +1.75 | Severity classification before detailed analysis (Critical → Significant → Medium → Minor). First P09 race condition detection (+2.0pt), P08 partial detection (+0.5pt), highest bonus diversity (5.5 avg), zero penalties, high stability (SD=0.25). Exploratory thinking after critical issue identification. |
| N1c | INEFFECTIVE | 010 | -1.75 | NFR+Concurrency checklist integration. Highest complete detection rate (80%) but scope creep into reliability domain caused total bonus collapse (0 items, -2.5pt), P02 N+1 miss (-2.0pt). Explicit checklist triggered satisficing bias, suppressing exploratory thinking. |
| priority-websocket-hints | EFFECTIVE | 010 | +0.5 | Priority-first + lightweight WebSocket/concurrency hints (not explicit checklist). Perfect stability (SD=0.0), P08 complete detection (○/○), P09 partial detection (△/△), bonus preservation (4 items/run, +2.0pt). Directional hints guide attention without triggering satisficing bias. |
| priority-nplus1-batch-hints | INEFFECTIVE | 011 | -2.75 | Priority-first + 4 lightweight hints (WebSocket/concurrency/N+1/batch). 2-hint → 4-hint increase crossed satisficing threshold: P01 NFR loss (-2.0pt), P04 unbounded query miss (-1.0pt), P05 async processing loss (-1.0pt), reliability scope creep (timeout/circuit breaker penalties -0.5pt×2). N+1 hint triggered pattern-matching mode, batch hint activated reliability thinking. |

## テスト対象文書履歴

| ラウンド | テーマ/ドメイン | 主要問題カテゴリ |
|---------|---------------|----------------|
| Round 001 | オフィス検温システム | I/O効率、DB設計、キャッシュ、スケーラビリティ、並行処理 |
| Round 002 | オフィス検温システム | NFR仕様欠如（SLA、監視）、N+1問題、容量設計、並行制御 |
| Round 003 | ライブ配信プラットフォーム | リアルタイム通信、アーカイブ処理、データ長期増大、大容量ファイル、並行書き込み |
| Round 004 | オフィス検温システム | ポーリング、N+1問題、データ増大、レポートタイムアウト、ページネーション、インデックス設計、再接続ストーム、アラート遅延、並行書き込み、監視メトリクス |
| Round 005 | オフィス検温システム | NFR要件、N+1問題、キャッシュ戦略、非同期ジョブ、ページネーション、コネクションプール、データ増大、水平スケーリング、並行予約、監視メトリクス |
| Round 006 | オフィス検温システム | NFR要件、N+1問題、キャッシュ戦略、非同期レポート、無制限クエリ、インデックス設計、コネクションプール、アラートポーリング、データライフサイクル、並行書き込み |
| Round 007 | 医療予約プラットフォーム | NFR仕様欠如、予約履歴N+1、キャッシュ戦略、無制限クエリ、カルテアクセス効率化、インデックス設計、通知処理スケール、コネクションプール、データ増大戦略、並行予約競合 |
| Round 008 | 投資ポートフォリオ管理プラットフォーム | NFR仕様欠如、保有資産N+1、キャッシュ戦略欠如、無制限履歴クエリ、レコメンドエンジン複雑度、取引履歴データ増大、インデックス欠如、WebSocketスケーリング、リバランス並行競合、パフォーマンス監視欠如 |
| Round 009 | スマート交通管理プラットフォーム | NFR要件/SLA、経路推薦N+1、キャッシュ戦略欠如、履歴クエリ無制限、経路計算複雑度、時系列データ増大、インデックス欠如、WebSocketスケーラビリティ、信号制御競合状態、監視メトリクス欠如 |
| Round 010 | 多言語リアルタイム翻訳プラットフォーム | NFR要件/SLA、翻訳履歴N+1、キャッシュ戦略不明瞭、無制限クエリ、翻訳APIバッチ処理欠如、データ増大対策、インデックス設計欠如、WebSocket接続スケーリング、用語集競合状態、監視メトリクス欠如 |
| Round 011 | オンライン学習プラットフォーム（クイズ重点） | NFR要件/SLA、クイズ結果N+1、キャッシュ戦略欠如、無制限クエリ、非同期処理欠如、データライフサイクル、インデックス設計欠如、接続スケーリング、並行制御、監視メトリクス欠如 |

## 最新ラウンドサマリ

**Round 011**:
- スコア: baseline 8.5 (SD=1.0), variant-priority-nplus1-batch-hints 5.75 (SD=0.75)
- 推奨: baseline（+2.75pt差、Round 010 priority-websocket-hints の2ヒント構成を保持）
- 主要知見:
  - 軽量ヒントの満足化バイアス閾値は2件: Round 010の2ヒント（WebSocket/並行制御）で9.5pt達成も、Round 011の4ヒント（+N+1/バッチ処理）で5.75ptに退行（-2.75pt）
  - N+1明示ヒントはパターンマッチモードを誘発し、NFR分析を抑制（P01検出 ○/○→×/×, -2.0pt）、P04無制限クエリも未検出（×/○→×/×, -1.0pt）
  - バッチ処理ヒントはreliabilityスコープ逸脱（タイムアウト/サーキットブレーカー推奨 -0.5pt×2回）を誘発し、P05非同期処理検出を喪失（△/△→×/×, -1.0pt）
  - ボーナス検出多様性は健全性指標: baseline 3.5項目（+1.75pt平均）、variant 3.0項目（+1.5pt平均）、多様性と総合スコアが相関
  - 継続推奨: baseline 8.5pt（Round 010比-1.0pt）は環境依存性を示唆するもvariant劣位は一貫、2ヒント限界が確定的
  - 次ラウンド優先課題: 2ヒント構成保持、P01/P04/P05検出改善は構造的アプローチ（NFRセクション明示化、カテゴリ分解）で探索

## 改善のための考慮事項

1. **NFRチェックリストの有効性**: NFR関連の欠如問題（SLA定義、監視戦略）を体系的に検出。設計書に非機能要件の記載が不足している場合に+4.0pt改善（根拠: Round 002, N1a P03+P09検出向上）
2. **ボーナス検出の価値**: 基準外の創造的指摘（バッチAPI、コネクションプール等）が高スコアに寄与する。平均+2.5~+4.0pt獲得（根拠: Round 001 baseline 6項目/Run、Round 002 variant-detection-hints 8項目/Run）
3. **構造化による満足化バイアス（Satisficing Bias）**: NFRチェックリスト、検出ヒント(-0.5pt, Round 002)、アンチパターンカタログ参照(-1.25pt, Round 007)、並行制御チェックリスト追加(-0.75pt bonus, Round 008)は「チェックリスト完了バイアス」を誘発し、リスト外の問題への探索意欲を低下させる。検出ヒントはボーナス検出増加（+1.5pt）も基礎問題検出精度低下（-1.25pt）。Round 008ではP09競合検出改善（+2.0pt）と引き換えにP05アルゴリズム複雑度（-1.75pt）、ボーナス多様性（-0.75pt）が劣化。専用チェックリストは焦点を狭める（根拠: Round 002 N1a/N3a P10検出 0/2・N3a統合指摘傾向、Round 007 variant P10 ○/○→×/△、Round 008 variant P05 ○/○→△/×）
4. **データライフサイクルチェックリストの有効性**: 時系列データの長期容量戦略（P09アーカイブ増大）を確実に検出（0/2→2/2、テーブルパーティショニング提案）。完全安定性（SD=0.0）と+2.25pt改善を達成（根拠: Round 003, M2b P09完全検出）
5. **ボーナス検出の多様性vs安定性**: 少数精鋭型（2.5件）でも高安定性達成可能。多様性型（4.0件）は創造的指摘が豊富だが、カテゴリカバレッジ（B01-B10）が重要（根拠: Round 002, baseline安定性 vs variant-detection-hints多様性）
6. **監視戦略の検出改善**: NFRチェックリスト導入により監視/アラート問題（P09）を確実に検出（0/2 → 2/2、+2.0pt）。NFR標準項目として体系的カバーが有効（根拠: Round 002, N1a P09検出）
7. **適切な構造化の重要性**: Round 001ではbaseline優位、Round 002ではNFRチェックリスト+3.0pt、Round 003ではデータライフサイクル+2.25pt改善。「過度な構造化」ではなく「問題ドメインに特化した構造化」が最も有効（根拠: Round 002 N1a、Round 003 M2b）
8. **Few-shot/Rubricの副作用**: Few-shot exampleはテンプレート効果によりボーナス検出減少（-1.0pt、S1a -0.75pt）。明示的な採点基準は「評価モード」を誘発し不安定性増加（SD=1.0、C1a -1.5pt）。両者とも探索的思考を抑制（根拠: Round 001 S1a/C1a、Round 004 S2a/S2b -0.5pt）
9. **カテゴリ分解のトレードオフ**: I/O効率カテゴリの明示化はP02 N+1を明確検出（○/○）し、カテゴリ固有問題（P03キャッシュ、P08ポーリング）を安定化（SD=0.25、+2.0pt）するが、データライフサイクル（P09）や横断的パターン（P10並行制御）の検出を阻害する。カテゴリ境界が明確な問題に有効、複合領域に弱い（根拠: Round 003 P02向上/P03低下、Round 006 P03/P08安定化・P09/P10喪失）
10. **ペナルティ排除の成功パターン**: 構造化アプローチ（NFRチェックリスト、データライフサイクル、カテゴリ分解）はスコープ外問題（security violation）を回避する傾向。baselineでのJWT expiration指摘（-0.5pt）が構造化により排除（根拠: Round 003, 両バリアントペナルティ0件）
11. **データ増大問題の検出難易度**: P09アーカイブ長期増大はRound 002まで全プロンプトで未検出だったが、M2bデータライフサイクル導入により完全検出達成。一般的なNFRチェックリストでは不十分で、ドメイン特化チェックリストが必要（根拠: Round 003, M2b専用チェックリスト効果）
12. **観点特化チェックリストの焦点効果**: データライフサイクル観点はP06ページネーション検出を安定化（○/× → ○/○）。カテゴリ分解はN+1を明示的に検出（P02 ○/○）、データライフサイクルは副次的扱い（P02 △/△）。観点により検出焦点が変化（根拠: Round 003, M2b vs decomposition P02/P06検出パターン）
13. **英語指示の優位性**: 技術用語（async job queue, throttling）の意味解釈明確化と表現揺れ排除により、検出精度+1.5pt向上、完全安定性（SD=0.0）達成、ボーナス検出安定化（5件/Run）。LLMの事前学習データで「パフォーマンスレビュー文書」が英語で豊富（根拠: Round 004, L1b P04 ×/△→○/○安定化）
14. **Query Pattern Detection の逆効果**: 明示的なクエリパターンリスト（N+1、unbounded queries、missing indexes）はチェックリスト化を誘発し、NFR要件分析を抑制する。antipattern版(-1.25pt)はP01 NFR検出喪失+ペナルティ増加、pattern matching版(-3.5pt)はNFR/インフラ問題（P01/P07/P08/P10）を完全未検出。「パターンマッチモード」は探索的思考を阻害する（根拠: Round 005, N2a両バリアント逆効果）
15. **NFR要件検出の困難性**: P01（Missing Performance Requirements/SLA Definition）は構造化指示（Query Pattern, Scoring Rubric）により検出困難になる。baselineのみが○/○検出達成。NFR Section の明示的レビュー指示が必要（根拠: Round 005, N2a両バリアントP01完全未検出、baseline○/○検出）。カテゴリ分解構造ではP01を部分検出可能（×/×→△/△）だが完全検出には至らず（根拠: Round 006, Decomposition △/△検出）
16. **Baseline環境依存性**: Round 005→006で10.25→7.25退行、006→007で7.25→8.5回復。探索的アプローチは問題分布（NFR仕様欠如密度）に依存し環境変化に脆弱。構造化プロンプト（+1.5pt）はbaseline-friendly文書でも一貫優位性を維持（根拠: Round 006 退行-3.0pt・SD悪化+1.0、Round 007 回復+1.25pt・構造化優位性両立）
17. **アンチパターンカタログの効果とトレードオフ**: 明示的アンチパターンリスト（unbounded queries, N+1, missing indexes）は該当パターン検出を促進（P04 +2.0pt完全検出）するが、「満足化行動」によりカタログ外問題への探索意欲を低下させる。ボーナス多様性が5件→3件に減少（-1.25pt）（根拠: Round 007, P04完全検出 vs baseline 8種類・variant 3種類のボーナス項目）
18. **NFRチェックリストの体系的検出効果**: NFRチェックリスト（N1a）はP09データライフサイクル（×/×→○/○, +2.0pt）、P07通知スケーリング（△/△→○/○, +1.0pt）を完全検出。「Data Retention/Archival Policy」「notification delivery SLA」等の明示項目が仕様欠如を体系的に露呈させる（根拠: Round 002 +3.0pt、Round 007 +3.0pt検出改善）
19. **並行制御チェックリストのトレードオフ**: 明示的並行制御項目（race conditions, locking, idempotency）はP09競合状態を確実に検出（×/×→○/○, +2.0pt）するが、「満足化バイアス」によりチェックリスト外問題への探索意欲を低下させる。P05アルゴリズム複雑度検出回帰（○/○→△/×, -1.75pt）、P08 WebSocket接続数制限検出劣化（○/○→△/△, -1.0pt）、ボーナス多様性減少（4.25→3.5, -0.75pt）。専用チェックリストではなくコアNFRチェックリストへの統合が必要（根拠: Round 008, N1c +0.5pt検出改善も-0.75pt総合劣位）
20. **優先度分類優先アプローチの有効性**: 詳細分析前の重大性分類（Critical → Significant → Medium → Minor）は、全ラウンド初のP09競合状態検出（+2.0pt）、P08 WebSocket部分検出（+0.5pt）、最高ボーナス多様性（5.5項目平均）、ゼロペナルティ、高安定性（SD=0.25）を達成し+1.75pt改善。重大問題を先に特定することで満足化バイアスを回避し、残存認知リソースをMedium/Minor探索に配分可能（根拠: Round 009, Priority-First 11.75 vs baseline 10.0）
21. **明示的思考段階構造化の逆効果**: CoT Steps構造（NFR → Architecture → Implementation → Cross-cutting）は段階完了バイアスを誘発し、包括的カバレッジを低下させる（-0.25pt）。P02 Run1完全未検出、P03/P05 Run2部分検出劣化。各段階の完了が目標となり、問題網羅性が二次的になる。ペナルティ排除成功（0件）も総合スコア劣位（根拠: Round 009, CoT-Steps 9.75 vs baseline 10.0, SD=0.75）
22. **チェックリスト統合の原則**: ドメイン特化チェックリスト（データライフサイクル、並行制御）は該当問題の検出精度を向上させるが、分離されたチェックリストは満足化バイアスを誘発する。効果的なアプローチは「コアNFRチェックリストに項目を統合」または「優先度分類により探索的思考を促進」することで焦点と広がりを両立させる（根拠: Round 008分析、Round 009 Priority-First +1.75pt優位性）
23. **軽量ヒントvs明示的チェックリストのトレードオフ**: 明示的チェックリスト（NFR+並行制御統合, N1c）は該当問題検出率を向上（80%完全検出率）させるが満足化バイアスによりボーナス検出を完全喪失（0項目, -2.5pt）、スコープ逸脱（9件reliability候補）を誘発する。軽量ヒント2件（"Consider WebSocket scaling..."）は方向性誘導のみで探索的思考を維持し、ボーナス検出保持（4項目/Run, +2.0pt）と完全安定性（SD=0.0）を両立するが、4件に増加すると満足化バイアス閾値を超過し、チェックリストと類似の負効果（NFR検出喪失-2.0pt、スコープ逸脱-1.0pt）を示す（根拠: Round 010 websocket-hints +0.5pt vs nfr-concurrency -1.75pt、Round 011 nplus1-batch-hints -2.75pt）
24. **ボーナス検出多様性の指標性**: ボーナス検出項目数（3.5-5項目/Run）は探索的思考の健全性を示す代理指標として機能する。チェックリスト特異性/ヒント数と逆相関: baseline 5項目（+2.5pt）、priority-nfr-concurrency 0項目（+0.0pt）、priority-websocket-hints 4項目（+2.0pt）、priority-nplus1-batch-hints 3.0項目（+1.5pt）。3.5項目以上を維持するバリアントは焦点と探索のバランスが良好（根拠: Round 010/011 ボーナス多様性と総合スコアの相関分析）
25. **軽量ヒント数の満足化バイアス閾値**: 軽量ヒントは2件まで（WebSocket/並行制御）が最適閾値。3-4件に増加すると累積的ディレクティブ負荷により満足化バイアスを誘発し、探索的思考を抑制する（Round 011: 4ヒントで-2.75pt退行）。N+1明示ヒントはパターンマッチモード化（P01 NFR検出-2.0pt）、バッチ処理ヒントはreliabilityスコープ逸脱（タイムアウト/サーキットブレーカー-0.5pt×2）を誘発。「方向性誘導」であっても累積数がチェックリスト化効果を生む（根拠: Round 011, 2ヒントbaseline 8.5pt vs 4ヒントvariant 5.75pt、-2.75pt差）
