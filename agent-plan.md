# エージェント再編計画

## 背景

現行5観点（security, performance, best-practices, maintainability, consistency）を以下の理由で再編する。

- **best-practices と maintainability の大幅な重複**: SOLID/結合度、テスト設計/テスタビリティ、エラーハンドリング、API設計、コード可読性（関数長・ネスト深さ・マジックナンバー）が両方に存在
- **障害耐性・運用性の観点が欠落**: テスト文書テンプレートの「非機能要件 > 可用性・スケーラビリティ」を主管する観点がない

## 新5観点の一覧

| # | ID | 名称 | 問い | 変更種別 |
|---|-----|------|------|---------|
| 1 | security | セキュリティ | 攻撃者に悪用されるか？ | 変更なし |
| 2 | performance | パフォーマンス | リソースを無駄にしていないか？ | 変更なし |
| 3 | structural-quality | 構造品質 | 良い構造で変更容易か？ | best-practices + maintainability を統合 |
| 4 | consistency | 一貫性 | 既存規約に合っているか？ | スコープ明確化 |
| 5 | reliability | 信頼性・運用性 | 障害時に正しく動き運用できるか？ | 新規追加 |

## 各観点の直交性（境界の考え方）

| 観点 | レンズ | 判断基準 | 他観点との境界 |
|------|--------|---------|---------------|
| Security | 敵対的 | 脅威モデル・脆弱性 | 悪意ある攻撃者による悪用。偶発的障害は reliability |
| Performance | 効率性 | 計算量・I/O・メモリ | 正常時のリソース効率。障害時の縮退は reliability |
| Structural Quality | 持続可能性 | 工学原則（SOLID, DRY等） | 普遍的な設計原則。既存パターンとの適合は consistency |
| Consistency | 適合性 | このコードベースの慣習 | パターンの良し悪しは問わず既存との一致を評価。良し悪しは structural-quality |
| Reliability | 継続性 | 障害回復・運用可能性 | 偶発的障害への耐性と運用性。セキュリティ攻撃は security |

---

## 1. Security（セキュリティ）— 変更なし

### 概要
設計書/コードをセキュリティ観点で評価し、脆弱性や不足している対策を特定する。

### 問い
「攻撃者に悪用されるか？」

### 作成/変更が必要なファイル
- `perspectives/design/security.md` — 変更なし
- `perspectives/code/security.md` — 変更なし
- `.claude/agents/security-design-reviewer.md` — 変更なし
- `.claude/agents/team-security-reviewer.md` — 変更なし

---

## 2. Performance（パフォーマンス）— 変更なし

### 概要
設計書/コードをパフォーマンス観点で評価し、ボトルネックや非効率な設計/実装を特定する。

### 問い
「リソースを無駄にしていないか？」

### 作成/変更が必要なファイル
- `perspectives/design/performance.md` — 変更なし
- `perspectives/code/performance.md` — 変更なし
- `.claude/agents/performance-design-reviewer.md` — 変更なし
- `.claude/agents/team-performance-reviewer.md` — 変更なし

---

## 3. Structural Quality（構造品質）— best-practices + maintainability を統合

### 概要
設計書/コードの構造的健全性を評価する。SOLID原則、結合度/凝集度、変更容易性、テスタビリティ、エラーハンドリング戦略、DRY/YAGNIなど、長期的に持続可能なソフトウェアを実現するための工学原則への適合を包括的に評価する。

### 問い
「良い構造で、長期的に変更・維持可能か？」

### 統合元の対応関係

best-practices から引き継ぐ項目:
- SOLID原則の適用
- デザインパターンの適切性
- エラーハンドリング戦略（分類、伝播、リカバリー）
- ロギング・オブザーバビリティ設計
- テスト設計（テスト戦略、テスト可能な設計）
- API設計原則（RESTful、バージョニング）
- DRY原則
- コード可読性

maintainability から引き継ぐ項目:
- 変更容易性（モジュール分割、拡張ポイント、変更局所化）
- 結合度と凝集度（依存方向、循環依存、グローバル状態）
- テスタビリティ設計（DI、モックポイント）
- API・データモデル設計品質（後方互換性、スキーマ進化）
- 段階的実装可能性
- YAGNI違反
- 技術的負債兆候

重複排除後の統合スコープ（後述の perspective に反映）

### perspective 定義

#### design（設計レビュー用）

評価スコープ:
1. SOLID原則・構造設計 — 責務分離、依存方向、モジュール境界、結合度/凝集度、デザインパターンの適切性
2. 変更容易性・拡張性 — 変更影響範囲の限定、拡張ポイント、段階的実装可能性、設定管理・環境差分
3. エラーハンドリング・オブザーバビリティ — エラー分類・伝播・リカバリー戦略、ロギング設計、トレーシング
4. テスト設計・テスタビリティ — テスト戦略、DI設計、外部依存の抽象化、モック可能性
5. API・データモデル品質 — RESTful設計原則、バージョニング、後方互換性、スキーマ進化戦略

スコープ外:
- セキュリティ脆弱性（認証・認可、暗号化等）→ security
- パフォーマンス問題（クエリ最適化、キャッシュ戦略等）→ performance
- 既存コードとの規約一致 → consistency
- 障害回復パターン、可用性設計、デプロイ戦略 → reliability

ボーナス/ペナルティ判定指針:
- ボーナス: SOLID違反、YAGNI違反、循環依存、過剰な抽象化層など正解キーに含まれない構造的問題の検出
- ペナルティ: セキュリティ脆弱性、パフォーマンス問題、障害回復パターンの指摘
- 迷うケース: テスト容易性に関わる設計 → スコープ内。既存コードとの不整合で保守コスト増大の文脈 → スコープ内

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| SOLID/SRP | 1つのクラスに複数の責務を持たせる設計 | 重大 |
| 結合度 | コンポーネント間に循環依存が存在する設計 | 重大 |
| YAGNI | 現時点で不要な複雑な抽象化層を設計している | 重大 |
| 変更影響 | 1つの機能変更が多数のコンポーネントに波及する設計 | 重大 |
| エラー処理 | エラーハンドリング戦略の欠如 | 重大 |
| 依存関係管理 | ドメインロジックが外部実装詳細（ORM、外部API）に直接依存 | 中 |
| テスト | テスト戦略の記載なし | 中 |
| API設計 | RESTful原則に反するエンドポイント設計 | 中 |
| API設計 | APIにバージョニング戦略がなく破壊的変更リスクが高い | 中 |
| 設定管理 | 設定管理戦略が未定義で環境差分が暗黙的 | 中 |
| 技術的負債 | 「暫定対応」の設計が恒久化するリスクが高い | 中 |
| テスタビリティ | 外部依存の抽象化が不十分でモック困難 | 軽微 |
| グローバル状態 | シングルトンやグローバル状態の過剰使用 | 軽微 |
| ロギング | ロギング・オブザーバビリティ設計の欠如 | 軽微 |

#### code（実装レビュー用）

評価スコープ:
1. SOLID原則・構造 — クラス設計、結合度、依存注入、インターフェース分離
2. コード可読性・理解容易性 — 関数長、ネスト深さ、命名の意図明確性、複雑なロジックのドキュメンテーション
3. DRY/YAGNI — コード重複の排除、過剰な抽象化の回避、未使用コード
4. エラーハンドリング・ロギング品質 — 例外処理の粒度、エラーメッセージ、ログレベルの適切性、構造化ログ
5. テスト品質・テスタビリティ — テスト容易な構造、モック可能性、DI、テストカバレッジ、アサーション品質
6. 技術的負債兆候 — TODO/FIXME、ワークアラウンド、マジックナンバー

スコープ外:
- セキュリティ脆弱性 → security
- パフォーマンス最適化 → performance
- コーディングスタイルの一貫性 → consistency
- リトライ実装、タイムアウト設定等の障害耐性 → reliability

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| SOLID | 神クラス（God Class）の実装 | 重大 |
| 複雑性 | 循環的複雑度が高い関数 | 重大 |
| DRY | コードの大規模な重複 | 中 |
| エラー処理 | 空のcatchブロック | 中 |
| YAGNI | 使用されていないインターフェース/抽象クラス | 中 |
| 依存 | ハードコードされた外部サービスのURL | 中 |
| マジックナンバー | 定数化されていないリテラル値 | 軽微 |
| 可読性 | 100行を超える関数 | 軽微 |

### 作成/変更が必要なファイル
- `perspectives/design/structural-quality.md` — 新規作成（上記 design perspective 定義）
- `perspectives/code/structural-quality.md` — 新規作成（上記 code perspective 定義）
- `.claude/agents/structural-quality-design-reviewer.md` — 新規作成（security-design-reviewer.md の構造を参考）
- `.claude/agents/team-structural-quality-reviewer.md` — 新規作成（team-security-reviewer.md の構造を参考）

### 削除対象ファイル
- `perspectives/design/best-practices.md`
- `perspectives/code/best-practices.md`
- `perspectives/design/maintainability.md`
- `perspectives/code/maintainability.md`
- `.claude/agents/best-practices-design-reviewer.md`
- `.claude/agents/maintainability-design-reviewer.md`
- `.claude/agents/team-maintainability-reviewer.md` (+ .bak)
- `.claude/agents/team-practices-reviewer.md`

---

## 4. Consistency（一貫性）— スコープ明確化

### 概要
設計書/コードが既存のコードベースに確立された規約・パターンと整合しているかを評価する。パターンの良し悪しは判断せず、既存との一致/逸脱を評価する。

### 問い
「このコードベースの既存規約・パターンに合っているか？」

### スコープ変更点
- 「アーキテクチャパターンの整合性」→「**既存の**アーキテクチャパターンとの整合性」に限定。パターン自体の良し悪しは structural-quality の管轄
- 「API/インターフェース設計の統一性」→「**既存API**とのフォーマット統一」に限定。RESTful原則への適合は structural-quality の管轄
- 「エラーハンドリングパターンの統一」→ 既存のエラー処理パターンとの一致を評価。エラーハンドリング戦略自体の品質は structural-quality の管轄

### perspective 定義

#### design（設計レビュー用）

評価スコープ:
1. 命名規約の一貫性 — 変数名、関数名、クラス名、ファイル名の命名パターンが既存に合っているか
2. 既存アーキテクチャパターンとの整合性 — レイヤー構成、依存方向、責務分離の方針が既存に合っているか
3. ディレクトリ構造・ファイル配置の一貫性 — 既存の配置規則に合っているか
4. API/インターフェース設計の統一性 — 既存APIのエンドポイント命名、レスポンス形式、エラー形式と統一されているか
5. 依存関係管理の方針 — 既存のライブラリ選定基準、バージョン管理方針に合っているか

スコープ外:
- セキュリティ脆弱性 → security
- パフォーマンスの問題 → performance
- 設計原則（SOLID等）の遵守、テスト設計の十分性 → structural-quality
- 障害回復・運用性 → reliability

ボーナス/ペナルティ判定指針:
- ボーナス: 設計書が既存パターンから逸脱しているが正解キーに含まれない不整合の検出
- ペナルティ: セキュリティやパフォーマンスの指摘（一貫性に無関係）
- 迷うケース: 既存パターン自体に問題がある場合の「改善提案」→ 一貫性の観点では既存パターンとの整合性を優先し、改善提案はスコープ外

**注意**: この観点は「パターンが良いか悪いか」ではなく「既存と合っているか」を評価する。コードベースが一貫してアンチパターンを使っている場合でも、新しい設計が同じパターンに従っていれば「一貫している」と判定する。

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| アーキテクチャ | レイヤーの依存方向が既存と異なる | 重大 |
| 命名 | エンドポイントの命名規則が既存と混在（camelCase/kebab-case） | 中 |
| API設計 | レスポンス形式が既存APIと統一されていない | 中 |
| エラー形式 | エラーレスポンスの形式が既存APIと異なる | 中 |
| 依存管理 | 既存で使用中のライブラリと同機能の別ライブラリを新たに導入 | 中 |

#### code（実装レビュー用）

評価スコープ:
1. コーディングスタイル — インデント、括弧、空白、コメントスタイルが既存に合っているか
2. 命名規約の準拠 — 変数、関数、クラス、定数の命名パターンが既存に合っているか
3. エラーハンドリングパターンの統一 — 既存の例外処理パターン、エラーレスポンス形式に合っているか
4. インポート・依存関係の整理 — インポート順序、未使用インポートが既存の慣習に合っているか
5. 既存ユーティリティの活用 — 車輪の再発明を避け、既存の共通関数を使用しているか

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| 命名 | 同一概念に既存と異なる名前を使用 | 中 |
| エラー処理 | 既存の例外処理パターンと異なるパターンを使用 | 中 |
| ユーティリティ | 既存ユーティリティの未使用（車輪の再発明） | 中 |
| スタイル | インデントやブレースのスタイルが既存と混在 | 軽微 |

### 作成/変更が必要なファイル
- `perspectives/design/consistency.md` — 更新（スコープ注記追加）
- `perspectives/code/consistency.md` — 更新（スコープ注記追加）
- `.claude/agents/consistency-design-reviewer.md` — 更新（スコープ注記をエージェント定義に反映）
- `.claude/agents/team-consistency-reviewer.md` — 更新（同上）

---

## 5. Reliability & Operability（信頼性・運用性）— 新規追加

### 概要
設計書/コードの障害耐性と運用性を評価する。障害発生時のシステムの振る舞い、回復能力、監視可能性、デプロイ安全性を重点的に評価する。セキュリティ（悪意ある攻撃）やパフォーマンス（正常時の効率）とは異なり、「偶発的な障害に対してシステムが正しく振る舞い、運用チームが適切に対応できるか」を評価する。

### 問い
「障害時に正しく動き、運用できるか？」

### 他観点との境界の詳細

| 境界ケース | 判定 |
|-----------|------|
| DoS攻撃への耐性 | security（悪意ある攻撃） |
| 偶発的な高負荷時の縮退運転 | **reliability**（偶発的障害） |
| レート制限の設計 | security（攻撃防御目的）。ただし自己保護目的のバックプレッシャーは **reliability** |
| エラーハンドリング戦略（設計原則として） | structural-quality |
| 障害発生時の具体的な回復フロー | **reliability** |
| ロギング設計（構造化ログ、ログレベル） | structural-quality |
| 監視アラート設計（SLO/SLA違反検知） | **reliability** |

### perspective 定義

#### design（設計レビュー用）

評価スコープ:
1. 障害回復設計 — サーキットブレーカー、リトライ戦略（指数バックオフ）、タイムアウト設計、フォールバック戦略
2. データ整合性・べき等性 — 分散トランザクション戦略（Saga等）、べき等性設計、重複検出メカニズム
3. 可用性・冗長性 — 単一障害点（SPOF）の特定と対策、フェイルオーバー設計、グレースフルデグラデーション
4. 監視・アラート設計 — SLO/SLA定義、メトリクス収集設計、アラート戦略、ヘルスチェック設計
5. デプロイ・ロールバック — デプロイ戦略（カナリア、Blue-Green等）、ロールバック計画、データマイグレーションの後方互換性

スコープ外:
- 悪意ある攻撃への耐性（DoS攻撃、ブルートフォース等）→ security
- 正常時のリソース効率（クエリ最適化、キャッシュ戦略等）→ performance
- 設計原則の遵守（SOLID、DRY等）→ structural-quality
- 既存コードとの規約一致 → consistency

ボーナス/ペナルティ判定指針:
- ボーナス: SPOFの特定、べき等性の欠如、監視の盲点など正解キーに含まれない運用上の問題の検出
- ペナルティ: セキュリティ脆弱性、コーディングスタイルの指摘
- 迷うケース: レート制限 → 自己保護（バックプレッシャー）目的はスコープ内、攻撃防御目的は security

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| 障害回復 | 外部API呼び出しにサーキットブレーカーもリトライ戦略もない | 重大 |
| データ整合性 | 複数サービス間トランザクションの一貫性保証が未設計 | 重大 |
| 可用性 | 単一障害点（SPOF）の特定と対策が未設計 | 重大 |
| タイムアウト | サービス間通信のタイムアウト仕様が未定義 | 中 |
| べき等性 | リトライ可能な操作のべき等性が未設計 | 中 |
| 縮退運転 | 依存サービスダウン時のグレースフルデグラデーション未設計 | 中 |
| 監視・アラート | SLO/SLAに対応する監視・アラート設計がない | 中 |
| ヘルスチェック | ヘルスチェックエンドポイント / Liveness Probe の設計なし | 中 |
| ロールバック | ロールバック戦略の欠如（データ移行を伴う変更での後方互換性なし） | 中 |
| デプロイ安全性 | カナリア/Blue-Green等の段階的デプロイ戦略がない | 軽微 |
| 非同期処理 | 失敗メッセージのDead Letter Queue設計がない | 軽微 |
| 監視 | パフォーマンスメトリクス収集の設計欠如 | 軽微 |

#### code（実装レビュー用）

評価スコープ:
1. リトライ・タイムアウト実装 — リトライロジック、指数バックオフ、タイムアウト設定、接続プール管理
2. 障害処理の実装 — サーキットブレーカーの実装、フォールバック処理、グレースフルシャットダウン
3. べき等性の実装 — べき等キーの実装、重複検出ロジック、トランザクション管理
4. ヘルスチェック・監視 — ヘルスチェックエンドポイント実装、メトリクス埋め込み、構造化ログの運用適合性
5. リソースクリーンアップ — コネクションの適切なクローズ、リソースリーク防止、シャットダウンフック

スコープ外:
- セキュリティ脆弱性 → security
- パフォーマンス最適化 → performance
- コード構造・設計原則 → structural-quality
- コーディングスタイルの一貫性 → consistency

問題バンク:

| カテゴリ | 問題例 | 深刻度 |
|---------|--------|-------|
| リトライ | 外部API呼び出しにリトライロジックが一切ない | 重大 |
| リソースリーク | DB接続やHTTPクライアントが適切にクローズされていない | 重大 |
| タイムアウト | HTTP呼び出しにタイムアウトが設定されていない | 重大 |
| べき等性 | 決済処理にべき等キーが実装されていない | 中 |
| サーキットブレーカー | 外部依存にサーキットブレーカーパターンが未実装 | 中 |
| ヘルスチェック | ヘルスチェックが浅い（依存サービスの疎通を確認しない） | 中 |
| シャットダウン | グレースフルシャットダウンが未実装（処理中リクエストの完了待ち） | 中 |
| 監視 | ビジネスクリティカルな処理にメトリクス収集がない | 軽微 |
| ログ | 障害原因調査に必要な情報（リクエストID、タイムスタンプ等）がログに不足 | 軽微 |

### 作成が必要なファイル
- `perspectives/design/reliability.md` — 新規作成（上記 design perspective 定義）
- `perspectives/code/reliability.md` — 新規作成（上記 code perspective 定義）
- `.claude/agents/reliability-design-reviewer.md` — 新規作成（security-design-reviewer.md の構造を参考）
- `.claude/agents/team-reliability-reviewer.md` — 新規作成（team-security-reviewer.md の構造を参考）

---

## 作業サマリ

### 新規作成（8ファイル）
| ファイル | 種別 |
|---------|------|
| `perspectives/design/structural-quality.md` | perspective |
| `perspectives/code/structural-quality.md` | perspective |
| `perspectives/design/reliability.md` | perspective |
| `perspectives/code/reliability.md` | perspective |
| `.claude/agents/structural-quality-design-reviewer.md` | agent |
| `.claude/agents/team-structural-quality-reviewer.md` | agent |
| `.claude/agents/reliability-design-reviewer.md` | agent |
| `.claude/agents/team-reliability-reviewer.md` | agent |

### 更新（4ファイル）
| ファイル | 変更内容 |
|---------|---------|
| `perspectives/design/consistency.md` | スコープ注記追加（既存との一致を評価、パターンの良し悪しは structural-quality） |
| `perspectives/code/consistency.md` | 同上 |
| `.claude/agents/consistency-design-reviewer.md` | スコープ注記をエージェント定義に反映 |
| `.claude/agents/team-consistency-reviewer.md` | 同上 |

### 削除（8ファイル）
| ファイル | 理由 |
|---------|------|
| `perspectives/design/best-practices.md` | structural-quality に統合 |
| `perspectives/code/best-practices.md` | structural-quality に統合 |
| `perspectives/design/maintainability.md` | structural-quality に統合 |
| `perspectives/code/maintainability.md` | structural-quality に統合 |
| `.claude/agents/best-practices-design-reviewer.md` | structural-quality に統合 |
| `.claude/agents/maintainability-design-reviewer.md` | structural-quality に統合 |
| `.claude/agents/team-maintainability-reviewer.md` | structural-quality に統合 |
| `.claude/agents/team-practices-reviewer.md` | structural-quality に統合 |

### その他更新が必要な可能性があるファイル
- `SKILL.md` — 観点リストの参照がある場合に更新
- `approach-catalog.md` — クロスリファレンステーブルの観点名更新
- `test-document-guide.md` — 変更不要（観点非依存のガイドラインのため）
- `scoring-rubric.md` — 変更不要（観点非依存の採点基準のため）
- テンプレートファイル群 — perspective パス変数を使用しているため変更不要（呼び出し側で新パスを渡す）

### エージェント定義の構造（参考）

各エージェントは以下の2種類を作成する:

**1. `{perspective}-design-reviewer.md`（単体レビューアー）**
- reviewer_optimize スキルの Phase 3 で並列評価に使用
- tools: Glob, Grep, Read, WebFetch, WebSearch, BashOutput, KillBash
- 英語で記述（reviewer_optimize の評価パイプラインとの整合性）
- 含めるべきセクション: ロール定義、Evaluation Priority、Evaluation Criteria、Problem Detection Focus、Scoring Criteria、Output Guidelines

**2. `team-{perspective}-reviewer.md`（チーム版レビューアー）**
- team_plan / team_plan_v2 スキルで対話的レビューに使用
- tools: 上記 + SendMessage, TaskList, TaskUpdate, TaskGet
- 日本語で記述
- 含めるべきセクション: ロール定義、評価項目、評価の姿勢、スコアリング基準、出力フォーマット、チーム参加ルール
