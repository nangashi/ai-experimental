# Reviewer Optimize Knowledge: security-design

## 対象エージェント
- **観点**: security
- **対象**: design
- **エージェント定義**: .claude/agents/security-design-reviewer.md
- **累計ラウンド数**: 17

## パフォーマンス改善の要素

### 効果が確認された構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| S3a: 出力形式簡素化 | +0.75 | 0.25 | Round 1 | 平均11.0→11.75。CSRF・監査ログ検出率向上、安定性改善 |
| 英語化（english） | +2.75 | 0.0 | Round 4 | 平均8.25→11.0。P04（入力検証方針）・P06（監査ログ範囲不足）完全検出、完璧な安定性、ボーナス完全カバー |
| 明示的チェックリスト（explicit-checks） | +1.25 | 0.5 | Round 4 | 平均8.25→9.5。P05（冪等性）完全検出、ただしP03で部分的逆効果、視野狭窄リスクあり |
| 冪等性チェック項目（idempotency-checks） | +1.5 | 0.71 | Round 5 | 平均8.0→9.5。P05/P09完全検出、P02で視野狭窄、ボーナス減少 |
| 未検出問題明示的追加（missing-detection） | +2.5 | 0.0 | Round 5 | 平均8.0→10.5。P05/P07/P09すべて改善、完璧な安定性、視野狭窄リスク限定的 |
| 検出ヒント最適化（detection-hints） | +0.75 | 0.25 | Round 6 | 平均9.0→9.75。P07/P08検出向上（+3.25pt）だが、P09/P10減少とボーナス減（-1.5pt）。視野狭窄リスクあり。最高安定性（SD=0.25） |
| 重大度階層化（severity-first） | +1.5 | 0.0 | Round 7 | 平均8.0→9.5。P02（DELETE API認可）+0.75pt、P08（OAuth）+0.25pt、B05（情報漏洩）+0.5pt。完璧な安定性。重大度フレームワークで優先順位付けの変動を削減 |
| テーブル中心構造（table-centric） | +2.5 | 0.0 | Round 8 | 平均8.0→10.5。P03（入力検証）+1.0pt、P04（バックアップ暗号化）+1.0pt、P09（API認証情報保管）+0.5pt、P10（CORS）+0.5pt。完璧な安定性。表形式構造でインフラ仕様網羅性向上 |
| 自由形式出力+重大度分類（free-form） | +2.0 | 0.5 | Round 9 | 平均7.0→9.0。P02（JWT保管）部分検出0.0→0.5pt、ボーナス+1.0pt（2.5→3.5）。構造化出力削除で認知負荷軽減、パターン認識向上 |
| 自由形式+テーブル構造ハイブリッド（free-table-hybrid） | +3.0 | 0.25 | Round 10 | 平均7.75→10.75。P06（Elasticsearch暗号化）+0.75pt、P07（DB最小権限）+0.5pt、P08（JWTペイロード保護）+1.0pt。テーブル構造でインフラコンポーネント体系的カバレッジ+自由形式の認知負荷軽減を両立 |
| JWT保管明示的チェック（jwt-storage-explicit） | +1.25 | 0.0 | Round 11 | 平均8.75→10.0。P06（ログPIIマスキング）+2.0pt（スピルオーバー効果）、完璧な安定性（SD=0.0）。JWT保管チェックがログ機密情報処理への波及効果を生む。P03（予約キャンセル認可）-2.0ptのトレードオフあり |
| インフラテーブル拡張（freeform-table-extended） | +2.5 | 0.0 | Round 15 | 平均7.5→10.0。P09（ConfigMaps secrets）0%→100%完全検出（+1.0pt）、ボーナス検出爆発的拡大（0-2件→15件/run、+1.5pt上限）。完璧な安定性（SD=0.0）。Infrastructure component × security dimension マトリクスで体系的カバレッジ強制 |

### 効果が限定的/逆効果だった構造変化
| 変化 | 効果 (pt) | 安定性 (SD) | 確認ラウンド | 備考 |
|------|-----------|-------------|-------------|------|
| S4a: サブ項目削減 | -1.0 | 0.0 | Round 1 | 平均11.0→10.0。横断的セキュリティ要件の見落とし増加 |
| C1a: CoT段階的分析 | +0.25 | 0.0 | Round 2 | 平均10.25→10.5。重大問題検出率向上だが中程度問題検出率低下。差<0.5ptのため有意差なし |
| N1a: OWASP標準チェックリスト | -0.25 | 0.0 | Round 2 | 平均10.25→10.0。チェックリスト外の問題を見落とす |
| S1b: ドメイン特化Few-shot/クリティカルチェック | -3.75 | 0.75 | Round 3 | 出力例6個で重大問題検出率100%→0% |
| M1a: 事前分析+本レビュー分離 | -0.25 | 1.75 | Round 3 | SD=1.75で極めて不安定。差<0.5ptのため有意差なし |
| 検出ヒント削減（min-detection） | +1.0 | 0.71 | Round 6 | 平均9.0→10.0。P03完全検出安定化（+1.0pt）、平均10.0達成。P09未検出（-2.0pt）、P05不安定化が課題 |
| 出力簡素化（minimized） | +0.5 | 0.0 | Round 7 | 平均8.0→8.5。P04（S3アクセス制御）完全検出（+0.25pt）、安定性向上（SD=0.0）だが、スコア上限8.5で限定的効果 |
| 階層的簡素化（hierarchical-simplify） | +1.5 | 0.0 | Round 8 | 平均8.0→9.5。P02（DELETE認可）+0.75pt、P03（入力検証）+0.5pt。ボーナス最高（5件）。MFA・bot防御の検出向上だが検出スコアは table-centric に劣る |
| Few-shot例6個（few-shot） | -0.5 | 1.0 | Round 9 | 平均7.0→6.5。検出不安定（Run1: 5.5, Run2: 7.5, 2pt差）、例による注意バイアス。総bonus 11-17件でも検出スコア低下 |
| 重大度階層化アンカー（severity-anchor） | -0.25 | 0.0 | Round 10 | 平均7.75→7.5（有意差なし）。P02（パスワードリセット有効期限）検出低下-1.0pt、P06/P07未検出。完璧な安定性（SD=0.0）だがCritical優先で中程度問題の検出優先度が低下 |
| ログマスキング明示的チェック（log-masking-explicit） | -1.5 | 0.25 | Round 11 | 平均8.75→7.25。P06（ログPIIマスキング）+2.0pt達成だが、ボーナス検出大幅減少-5.0pt（B02/B03/B04/B05/B06すべてRun2で見落とし）。明示的チェックによる視野狭窄が横断的セキュリティ要件の注意を崩壊 |
| 重大度重み付け明示（weighted-scoring） | -2.5 | 0.0 | Round 12 | 平均11.0→8.5。P01/P03/P04/P06すべて0%検出。重大度重み付けがポジティブフレーミングバイアスを誘発（存在確認モード vs 十分性分析モード）。完璧な安定性（SD=0.0）だが検出能力大幅低下 |
| 攻撃者視点STRIDE分析（adversarial-perspective） | -2.0 | 0.0 | Round 12 | 平均11.0→9.0。P06完全検出（IDOR分析フレームワーク）だが、範囲外の推測分析でペナルティ平均-2.0pt累積。MITMやインフラ脆弱性チェーン等、TLS仕様矛盾やCVE根拠なしの推測。完璧な安定性（SD=0.0） |
| 階層的テーブル構造（hierarchical-table） | -0.25 | 0.75 | Round 14 | 平均9.5→9.25。有意差なし。P05/P08検出改善（+1.5pt）だがP01/P04退化（-2.5pt）。テーブル構造のインフラ明示化が注意バジェット制約によりトレードオフ発生 |
| 攻撃者視点+範囲制約（adversarial-scoped） | -1.5 | 0.0 | Round 14 | 平均9.5→8.0。P05/P08完全検出（+3.0pt）だがP01/P04退化（-3.25pt）。範囲制約で推測ペナルティ回避も検出スコア低下。完璧な安定性（SD=0.0）で決定論的検出パターン |
| ナラティブチェックポイント（narrative-checkpoint） | +2.0 | 0.5 | Round 15 | 平均7.5→9.5。P05部分改善（Run2で△、+0.25pt）、P09部分改善（Run1で○、+0.5pt）、ボーナス検出拡大（0-2件→14件/run）。攻撃シナリオ段階的説明で一部問題への理解深化だが、P08/P09検出variance（Run2で同時未検出-1.5pt）により安定性維持（SD=0.5）。認知負荷増加が注意を分散 |
| 日英混合カテゴリ（mixed-language） | -0.75 | 1.0 | Round 17 | 平均7.25→6.5。Critical検出改善（P02: ×/× → ○/○, +2.0pt; P03: 部分改善+0.25pt; P08: ×/× → △/△, +1.0pt）だがインフラ検出低下（P07: ○/○ → ×/×, -2.0pt; P06: ○/○ → ○/×, -1.5pt; P05: △/△ → ×/×, -1.0pt）。日本語カテゴリ「認証・認可設計」が認証フロー分析をprimeする一方でWebhook/ストリーミングプロトコル検出を低下。SD=1.0（4倍不安定化） |

### バリエーションステータス
| Variation ID | Status | Round | Effect (pt) | Notes |
|-------------|--------|-------|-------------|-------|
| V012-weighted | INEFFECTIVE | 12 | -2.5 | 重大度重み付け明示（weighted-scoring）。P01/P03/P04/P06すべて0%検出。ポジティブフレーミングバイアスで十分性分析が存在確認モードに退化 |
| V012-adversarial | INEFFECTIVE | 12 | -2.0 | 攻撃者視点STRIDE分析（adversarial-perspective）。P06完全検出（IDOR）だが範囲外推測でペナルティ-2.0pt累積（MITM/CVE根拠なし推測） |
| V014-hierarchical-table | MARGINAL | 14 | -0.25 | 階層的テーブル構造（hierarchical-table）。有意差なし。P05/P08検出改善（+1.5pt）だがP01/P04退化（-2.5pt）。インフラ明示化が注意バジェット制約によりトレードオフ発生 |
| V014-adversarial-scoped | INEFFECTIVE | 14 | -1.5 | 攻撃者視点+範囲制約（adversarial-scoped）。P05/P08完全検出（+3.0pt）だがP01/P04退化（-3.25pt）。範囲制約で推測ペナルティ回避も検出スコア低下。SD=0.0で決定論的検出パターン |
| V015-freeform-table-extended | EFFECTIVE | 15 | +2.5 | インフラテーブル拡張（freeform-table-extended）。P09（ConfigMaps）完全検出+1.0pt、ボーナス検出15件/run（+1.5pt上限）。Infrastructure component × security dimension マトリクスで体系的カバレッジ。SD=0.0で完璧な安定性 |
| V015-narrative-checkpoint | EFFECTIVE | 15 | +2.0 | ナラティブチェックポイント（narrative-checkpoint）。P05/P09部分改善、ボーナス検出14件/run。攻撃シナリオ詳細化で理解深化だがP08/P09 variance（SD=0.5）。認知負荷増加が注意分散 |
| V016-api-authz-matrix | MARGINAL | 16 | -0.375 | API認可マトリクス（api-authz-matrix）。P07部分改善（×/× → △/△, +0.5pt）、ボーナス一貫性（7件×2runs）だが、P08退化（○/○ → △/○, -0.25pt）。注意バジェット制約により検出スコア-1.125pt。安定性改善（SD=0.177 vs baseline 0.5） |
| V016-compliance-encryption | MARGINAL | 16 | -0.75 | コンプライアンス暗号化マトリクス（compliance-encryption）。P07完全検出（×/× → ○/○, +2.0pt）だが、P02退化（△/○ → ×/△, -0.5pt）。コンプライアンスフォーカスが認証フロー注意を削減。総合-0.75pt |
| V017-mixed-language | INEFFECTIVE | 17 | -0.75 | 日英混合カテゴリ（N2b）。認証フロー分析強化（P02: +2.0pt, P03: +0.25pt, P08: +1.0pt）だが、インフラ検出大幅低下（P07: -2.0pt, P06: -1.5pt, P05: -1.0pt）。SD=1.0（4倍不安定化）。日本語カテゴリが検出パターンをauth flow優先に変化させるが総合効果は負 |
| S1a | INEFFECTIVE | 9 | -0.5 | Few-shot例6個。検出不安定（SD=1.0, 2pt差）、注意バイアス |
| S1b | INEFFECTIVE | 3 | -3.75 | 出力例6個で基本検出低下 |
| S1c | UNTESTED | - | - | - |
| S1d | UNTESTED | - | - | - |
| S1e | UNTESTED | - | - | - |
| S2a | EFFECTIVE | 4 | +2.75 | 英語化。P04/P06完全検出、SD=0.0、ボーナス完全カバー |
| S2b | UNTESTED | - | - | - |
| S2c | UNTESTED | - | - | - |
| S3a | EFFECTIVE | 1 | +0.75 | 出力形式簡素化 |
| S3b | UNTESTED | - | - | - |
| S3c | UNTESTED | - | - | - |
| S4a | INEFFECTIVE | 1 | -1.0 | サブ項目削減で見落とし増加 |
| S4b | UNTESTED | - | - | - |
| S5a | EFFECTIVE | 7 | +0.5 | 出力簡素化（minimized）。P04完全検出、SD=0.0だがスコア上限8.5 |
| S5b | EFFECTIVE | 6 | +0.75 | 検出ヒント最適化（detection-hints）。P07/P08検出向上、最高安定性、視野狭窄リスクあり |
| S5c | EFFECTIVE | 5 | +1.5 | 冪等性チェック項目。P05/P09検出向上、P02で視野狭窄 |
| S5d | EFFECTIVE | 7 | +1.5 | 重大度階層化（severity-first）。P02/P08/B05検出向上、SD=0.0、安定性と高スコアを同時達成 |
| S5e | EFFECTIVE | 9 | +2.0 | 自由形式出力+重大度分類（free-form）。P02部分検出、ボーナス+1.0pt、SD=0.5、認知負荷軽減で広範囲分析 |
| S5f | MARGINAL | 10 | -0.25 | 重大度階層化アンカー（severity-anchor）。P01部分検出、SD=0.0だが中程度問題（P02/P06/P07）検出低下で有意差なし |
| S6a | EFFECTIVE | 8 | +2.5 | テーブル中心構造（table-centric）。P03/P04/P09/P10検出向上、SD=0.0、インフラ仕様網羅性が最高 |
| S6b | EFFECTIVE | 8 | +1.5 | 階層的簡素化（hierarchical-simplify）。P02/P03検出向上、ボーナス最高（5件）、認証・防御の視野拡大 |
| S6c | EFFECTIVE | 10 | +3.0 | 自由形式+テーブル構造ハイブリッド（free-table-hybrid）。P06/P07/P08完全検出、SD=0.25、インフラ体系的カバレッジ+認知負荷軽減の両立 |
| C1a | MARGINAL | 2 | +0.25 | 有意差なし |
| C2d | EFFECTIVE | 11 | +1.25 | JWT保管明示的チェック（jwt-storage-explicit）。P06スピルオーバー効果+2.0pt、SD=0.0、完璧な安定性。P03注意トレードオフ-2.0pt |
| C2e | INEFFECTIVE | 11 | -1.5 | ログマスキング明示的チェック（log-masking-explicit）。P06完全検出+2.0ptだが、ボーナス-5.0pt、横断的要件崩壊 |
| C2f | INEFFECTIVE | 12 | -2.5 | 重大度重み付け明示（weighted-scoring）。P01/P03/P04/P06すべて0%検出。ポジティブフレーミングバイアス |
| C2g | INEFFECTIVE | 12 | -2.0 | 攻撃者視点STRIDE分析（adversarial-perspective）。P06完全検出だが推測分析ペナルティ-2.0pt累積。範囲制御課題 |
| C1b | UNTESTED | - | - | - |
| C1c | UNTESTED | - | - | - |
| C2a | EFFECTIVE | 5 | +2.5 | 未検出問題明示的追加。P05/P07/P09改善、SD=0.0 |
| C2b | UNTESTED | - | - | - |
| C2c | UNTESTED | - | - | - |
| C3a | UNTESTED | - | - | - |
| C3b | UNTESTED | - | - | - |
| C3c | UNTESTED | - | - | - |
| N1a | INEFFECTIVE | 2 | -0.25 | チェックリスト外の問題を見落とす |
| N1b | UNTESTED | - | - | - |
| N1c | UNTESTED | - | - | - |
| N2a | INEFFECTIVE | 4 | +1.25 | 明示的チェックリストとして実装。P05検出+2.0pt、P03で-0.25pt、視野狭窄リスク |
| N2b | INEFFECTIVE | 17 | -0.75 | 日英混合カテゴリ。認証フロー検出+3.25ptだがインフラ検出-4.5pt。SD=1.0（4倍不安定化）、検出パターンシフトで総合負効果 |
| N2c | UNTESTED | - | - | - |
| N3a | UNTESTED | - | - | - |
| N3b | UNTESTED | - | - | - |
| N3c | UNTESTED | - | - | - |
| M1a | MARGINAL | 3 | -0.25 | SD=1.75で不安定 |
| M1b | UNTESTED | - | - | - |
| M2a | EFFECTIVE | 6 | +1.0 | 検出ヒント削減（min-detection）。P03完全検出、平均10.0達成、P05不安定化が課題 |
| M2b | UNTESTED | - | - | - |
| M2c | UNTESTED | - | - | - |

## テスト対象文書履歴

| ラウンド | テーマ/ドメイン | 主要問題カテゴリ |
|---------|---------------|----------------|
| Round 2 | デジタルウォレット決済システム | 認証・認可設計、データ保護、入力検証設計 |
| Round 3 | SmartHome IoTデバイス管理プラットフォーム | 認証・認可設計、データ保護、入力検証設計、インフラ・依存関係 |
| Round 4 | 従業員給与管理システム | データ保護、入力検証設計、脅威モデリング、認証・認可設計、インフラ・依存関係 |
| Round 5 | 医療予約・電子カルテシステム | 認証・認可設計、データ保護、入力検証設計、API設計、監査ログ設計 |
| Round 6 | オンライン教育プラットフォーム | 認証・認可設計、データ保護、入力検証設計、脅威モデリング、インフラ・依存関係、情報漏洩防止 |
| Round 7 | オンライン教育プラットフォーム（プロジェクト管理機能付き） | 認証・認可設計、データ保護、入力検証設計、脅威モデリング |
| Round 8 | 不動産賃貸プラットフォーム | 認証・認可設計、データ保護、入力検証設計、脅威モデリング、インフラ・依存関係 |
| Round 9 | 企業文書管理システム | 認証・認可設計、データ保護、入力検証設計、監査ログ設計、インフラ・依存関係 |
| Round 10 | 企業文書管理システム（Round 9同一文書） | 認証・認可設計、データ保護、入力検証設計、CSRF、インフラ・依存関係 |
| Round 11 | 企業文書管理システム（Round 10同一文書、再テスト） | 認証・認可設計、データ保護、入力検証設計、監査ログ、インフラ・依存関係 |
| Round 12 | 企業文書管理システム（Round 11同一文書、ベースライン評価） | 認証・認可設計、データ保護、入力検証設計、監査ログ、インフラ・依存関係 |
| Round 13 | 企業文書管理システム（Round 12同一文書、weighted-scoring/adversarial-perspective評価） | 認証・認可設計、データ保護、入力検証設計、監査ログ、インフラ・依存関係 |
| Round 14 | 企業文書管理システム（Round 13同一文書、hierarchical-table/adversarial-scoped評価） | 認証・認可設計、データ保護、入力検証設計、監査ログ、インフラ・依存関係 |
| Round 15 | 医療予約・電子カルテシステム | 認証・認可設計、データ保護、入力検証設計、インフラ・依存関係（Kubernetes）、HIPAA compliance |
| Round 16 | CRMセールスパイプラインシステム | 認証・認可設計、データ保護、入力検証設計、インフラ・依存関係、Webhook、API設計 |
| Round 17 | 動画配信プラットフォーム（クリエイターポータル+視聴者再生） | 認証・認可設計（JWT/Refresh Token）、データ保護、入力検証設計、インフラ・依存関係、Webhook署名検証、RTMP認証、レート制限 |

## 最新ラウンドサマリ

- **ラウンド**: Round 17（動画配信プラットフォーム、mixed-language評価）
- **スコア**: baseline=7.25(SD=0.25), mixed-language=6.50(SD=1.0)
- **推奨**: baseline（判定根拠: Higher mean score (7.25 vs 6.50, +0.75pt) with superior stability (SD=0.25 vs 1.00). Score difference in 0.5-1.0pt range favors lower SD per scoring-rubric.md Section 5）
- **主要知見**: 日英混合言語構造（N2b）は検出パターンシフトを引き起こす。日本語カテゴリ「認証・認可設計」がCritical認証フロー検出を改善（P02: ×/× → ○/○, +2.0pt; P03/P08: 部分改善+1.25pt）する一方で、インフラ実装検出を大幅低下（P07 RTMP認証: ○/○ → ×/×, -2.0pt; P06 Webhook署名: ○/○ → ○/×, -1.5pt; P05 DB認可: △/△ → ×/×, -1.0pt）。総合-0.75pt、SD=1.0（4倍不安定化）
- **スコア変動**: Round 16 baseline=12.5pt → Round 17 baseline=7.25pt（-5.25pt）はテストセット変更（CRM → Video streaming）による難易度差であり最適化退化ではない
- **収束判定**: 継続推奨。Round 17が新テストセット初回のため多ラウンド改善トレンド未確認。N2b検出パターンシフトはハイブリッド最適化の余地を示唆（auth flow向上+インフラ検出維持の両立可能性）

## 改善のための考慮事項

1. [原則] 英語プロンプトは検出能力と安定性を大幅に向上させる（根拠: Round 4, english, +2.75pt, SD=0.0）
2. [原則] 出力形式の簡素化は検出能力を向上させる（根拠: Round 1, S3a, +0.75pt）
3. [原則] サブ項目の過度な削減は横断的要件の見落としを増加させる（根拠: Round 1, S4a, -1.0pt）
4. [原則] Few-shot出力例は検出能力を低下させる（根拠: Round 3 S1b -3.75pt、Round 9 S1a -0.5pt SD=1.0）。3個超は大幅低下、6個でも不安定化と注意バイアス発生
5. [原則] 明示的チェックリストは3-4領域まで拡大すると視野狭窄リスクは限定的（根拠: Round 5, missing-detection, SD=0.0）。しかし単一領域チェックは横断的要件の注意を崩壊させる（根拠: Round 11, log-masking-explicit, ボーナス-5.0pt）
6. [原則] 単一領域チェックリストは視野狭窄リスクが高い（根拠: Round 2 N1a, Round 4 N2a, Round 5 idempotency-checks, Round 11 log-masking-explicit -1.5pt）
7. [原則] 明示的ヒント追加は「ターゲット問題の検出率」と「網羅的な問題探索」のトレードオフを生む（根拠: Round 6, detection-hints, +3.25pt vs -1.5pt）
8. [原則] 検出ヒントの量は安定性とスコア上限のトレードオフを生む。ヒント追加で安定化するがスコア抑制、削減で高スコア達成だが不安定化し、モデルの暗黙的優先順位付けが表面化する（根拠: Round 6, detection-hints SD=0.25平均9.75 vs min-detection SD=0.71平均10.0, P03完全検出+1.0pt vs P09未検出-2.0pt）
9. [原則] 明示的チェック項目により技術的要件（冪等性・エラーハンドリング等）は確実に検出可能。複数領域（3-4領域）チェックリストはボーナス検出数を維持し、網羅性とのバランスが良い。具体化が不十分な場合は部分検出に留まる（根拠: Round 5, P05/P09完全検出 vs P07部分検出、平均2.5件以上ボーナス）
10. [原則] 認証フロー全体の完全性チェック（signup→reset→recovery）は明示的チェックポイントなしでは検出困難（根拠: Round 2-7, P06, 0% detection）
11. [原則] 重大度階層化は安定性を向上させるが効果は問題セット依存。Critical優先が中程度問題の検出を低下させる可能性（根拠: Round 7 +1.5pt vs Round 10 -0.25pt、severity-anchor SD=0.0だがP02/P06/P07検出低下）
12. [原則] 階層的簡素化は認証・防御メカニズム（MFA、bot防御）の検出視野を拡大し、最高ボーナス検出を達成する（根拠: Round 8, hierarchical-simplify, 5件ボーナス検出）
13. [原則] 表形式出力構造とテーブル評価マトリクス（各コンポーネント×評価軸）はインフラ仕様の体系的カバレッジを促進する。出力構造の選択は検出パターンに影響し、インフラ重視（table-centric）vs 認証重視（hierarchical-simplify）のトレードオフが存在する（根拠: Round 8 table-centric P04/P09完全検出、Round 10 P06/P07 25-50%→100%）
14. [原則] 自由形式出力は構造化出力削除による認知負荷軽減で、検出範囲拡大と特定問題検出を同時に達成する（根拠: Round 9 free-form +2.0pt P02 JWT保管0%→50%、Round 10 free-table-hybrid +3.0pt P06/P07/P08完全検出）
15. [原則] 明示的チェックはスピルオーバー効果により概念的に関連する問題の検出を改善する可能性があるが、注意バジェット制約によりトレードオフを生む。JWT保管チェックがログPIIマスキング検出を改善（クレデンシャル処理→ログ内機密情報の概念的クラスタリング）する一方で他問題検出が低下（根拠: Round 11, jwt-storage-explicit, P06スピルオーバー+2.0pt vs P03 -2.0pt）
16. [原則] 重大度重み付け明示は「十分性分析」を「存在確認」モードに退化させる。部分的対処済み仕様（8文字パスワード最小長、2時間トークン有効期限）を肯定的側面として扱い、十分性への批判を抑制するポジティブフレーミングバイアスが発生（根拠: Round 13, weighted-scoring, P01/P03/P04/P06すべて0%検出、-4.0pt）
17. [原則] 攻撃者視点STRIDE分析はエンドポイント別認可ギャップ検出を改善するが、範囲制御課題を持つ。攻撃チェーン構築がIDOR検出率向上させる（+0.5pt）一方で、設計文書範囲外の「もしも」シナリオ（TLS仕様矛盾のMITM、CVE根拠なしの脆弱性チェーン）を生成し、ペナルティ累積（-2.0pt平均）が上回る。範囲制約追加でペナルティ回避も検出スコア低下（根拠: Round 13 adversarial-perspective 総合-2.0pt、Round 14 adversarial-scoped -1.5pt）
18. [原則] テーブル構造の効果は問題セット依存で、注意バジェット制約によりカテゴリ間トレードオフが発生する可能性がある。インフラ体系的カバレッジ向上（P05/P08 +1.5pt）と認証・API設計の注意低下（P01/P04 -2.5pt）のトレードオフ。同一構造でも問題セット構成により効果が逆転（根拠: Round 8 table-centric +2.5pt SD=0.0 vs Round 14 hierarchical-table -0.25pt SD=0.75）
19. [原則] 中程度の変動（SD=0.5-0.75）はボーナス検出varianceに起因し、高天井パフォーマンスを示す。完璧な安定性（SD=0.0）は決定論的検出パターンだが検出スコア低下の傾向。ただしInfrastructure component matrixは例外でSD=0.0と高スコア10.0ptを同時達成（根拠: Round 12/13 baseline SD=1.0で11.0pt、Round 14 baseline SD=0.5で9.5pt vs adversarial-scoped SD=0.0で8.0pt、Round 15 freeform-table-extended SD=0.0で10.0pt）
20. [原則] Infrastructure component × security dimension マトリクス評価は体系的カバレッジを強制し、インフラレイヤー問題検出を劇的改善する。評価軸明示化（encryption at rest/in transit, authentication, access control, network isolation）により各コンポーネント（PostgreSQL, Redis, Elasticsearch, S3, Kong, Kubernetes）を体系的にチェック。ConfigMaps等のKubernetes特有問題の検出0%→100%、ボーナス検出7.5倍拡大（0-2件→15件/run）、完璧な安定性（SD=0.0）を同時達成（根拠: Round 15 freeform-table-extended, +2.5pt, P09 ConfigMaps完全検出+1.0pt）
21. [原則] 構造化評価（table matrix）の一貫性効果 > ナラティブ説明の深度効果。Infrastructure tableによる体系的カバレッジ（+2.5pt, SD=0.0）がnarrative詳細化（+2.0pt, SD=0.5）を上回る。ナラティブ説明（攻撃シナリオ段階的詳細化）は特定問題への理解を深化させるが、注意バジェット制約により他問題検出が不安定化（根拠: Round 15 freeform-table-extended vs narrative-checkpoint比較）
22. [原則] Endpoint-level authorization logic（"care team" membership等の細粒度認可）はinfrastructure component tableでもカバーしきれない。P08検出は全プロンプトで不安定（△/○, △/△, △/×）。API endpoint × authorization check matrixが必要（根拠: Round 15全バリアント, P08 variance）
23. [原則] マトリクス構造は特定領域の検出を改善しボーナス一貫性を向上させるが、注意バジェット制約によりゼロサムトレードオフを生む。API認可マトリクスはP07部分改善（+0.5pt）とボーナス安定（7件×2runs）を達成するが、P08入力検証で退化（-0.25pt）し総合-0.375pt。コンプライアンス暗号化マトリクスはP07完全検出（+2.0pt）だが、P02認証フロー注意削減（-0.5pt）により総合-0.75pt。マトリクス評価の認知負荷がフローベース問題の警戒性を削減（根拠: Round 16, api-authz-matrix -0.375pt SD=0.177, compliance-encryption -0.75pt SD=0.25）
24. [原則] 安定性向上（SD削減）とピーク検出パフォーマンスの間にはトレードオフが存在する。マトリクス構造による体系的評価はSD=0.177-0.25の高安定性を実現するが、自由形式ベースライン（SD=0.5）の高得点（12.5pt）を下回る。完璧な安定性（SD=0.0）は決定論的検出を示すが、ボーナスバリアンス（4-7件）を持つ中程度安定性（SD=0.5）の方が高天井パフォーマンスを示す場合がある（根拠: Round 16, baseline 12.5pt SD=0.5 vs api-authz-matrix 12.125pt SD=0.177）
25. [原則] 収束の兆候: 連続5ラウンド（Round 13-17）でベースライン優位が続き、バリアント効果<1.0ptはノイズまたは特定領域改善とトレードオフの組み合わせ。問題セット変更時のスコア変動（Round 16→17で-5.25pt、12.5→7.25）は最適化退化ではなくテストセット難易度差を反映（根拠: Round 17, baseline 7.25 vs mixed-language 6.50, +0.75pt差、4連続baseline推奨）
26. [原則] 言語・カテゴリ構造は検出パターンを変化させる。日英混合構造（N2b）の日本語カテゴリ「認証・認可設計」は認証フロー分析を強化（P02 Refresh Token検出0%→100%, +2.0pt）するが、インフラ実装検出を低下（Webhook/RTMP/DB認可で-4.5pt）。言語選択がモデルの注意配分メカニズムに影響し、トレードオフを生む（根拠: Round 17, mixed-language, +3.25pt auth flow vs -4.5pt infrastructure, 総合-0.75pt, SD 4倍悪化）
27. [原則] カテゴリ誘導による検出パターンシフトは安定性を低下させる。日本語カテゴリによる注意再配分がRun間variance（P03: ○/×, P06: ○/×）を増加させ、SD=0.25→1.0（4倍不安定化）。構造化評価の一貫性効果（Infrastructure table SD=0.0）との対比で、カテゴリ言語選択が決定論的評価を損なう（根拠: Round 17, mixed-language SD=1.0 vs baseline SD=0.25）
