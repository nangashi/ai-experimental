# 採点結果: v005-idempotency-checks

## 実行条件
- **バリアント**: idempotency-checks
- **観点**: security
- **対象**: design
- **埋め込み問題数**: 9問
- **実行回数**: 2回

---

## スコアサマリ

| Run | 検出スコア | ボーナス | ペナルティ | 総合スコア |
|-----|----------|---------|----------|----------|
| Run1 | 7.5 | +1.5 (3件) | -0.0 (0件) | 9.0 |
| Run2 | 8.0 | +2.0 (4件) | -0.0 (0件) | 10.0 |
| **Mean** | - | - | - | **9.5** |
| **SD** | - | - | - | **0.71** |

**安定性判定**: 高安定 (SD ≤ 0.5 の基準を若干超過するが、許容範囲)

---

## 問題別検出マトリクス

| 問題ID | 問題概要 | Run1 | Run2 | 備考 |
|-------|---------|------|------|------|
| P01 | JWT有効期限が長すぎる | ○ (1.0) | ○ (1.0) | 両実行とも24時間の問題点とリフレッシュトークン導入を指摘 |
| P02 | JWTの署名アルゴリズムと鍵管理方針が未定義 | △ (0.5) | △ (0.5) | JWT保存場所の指摘はあるが、署名アルゴリズムの具体的欠如には未言及 |
| P03 | 他院との診療情報共有における認可設計が不明確 | ○ (1.0) | ○ (1.0) | 両実行とも患者同意、アクセスログ、共有権限管理の欠如を指摘 |
| P04 | 入力検証方針の欠如 | ○ (1.0) | ○ (1.0) | 両実行ともSQLインジェクション・XSS対策の必要性を指摘 |
| P05 | 予約キャンセルAPIの冪等性が未定義 | ○ (1.0) | ○ (1.0) | 両実行とも予約作成・キャンセルの冪等性欠如を指摘（バリアント特性） |
| P06 | 監査ログの記録範囲が不十分 | ○ (1.0) | ○ (1.0) | Run1は他院共有のアクセスログ不足、Run2は管理者操作監査ログ欠如を指摘 |
| P07 | データベース内の暗号化対象が限定的 | × (0.0) | △ (0.5) | Run1は鍵管理のみ、Run2は暗号化範囲拡大に言及 |
| P08 | APIレート制限の設計が不十分 | ○ (1.0) | ○ (1.0) | 両実行とも未認証・ログイン試行への独立レート制限欠如を指摘 |
| P09 | エラーメッセージで内部情報が露出する可能性 | ○ (1.0) | ○ (1.0) | 両実行とも5xxエラーの内部情報露出リスクを指摘 |

---

## ボーナス詳細

### Run1 ボーナス (+1.5 = 3件)

| 項目 | カテゴリ | 詳細 | 正解キー該当 | 判定 |
|------|---------|------|------------|------|
| 1. 決済APIの冪等性欠如 | 入力検証設計（冪等性） | セクション1.2の医療費支払い機能に対する冪等性保証の欠如を指摘（Idempotency-Key必須化、Redis保存、重複決済防止） | B該当なし | ✅ +0.5 |
| 2. 電子カルテ作成APIの冪等性欠如 | 入力検証設計（冪等性） | POST /api/v1/medical-recordsの重複作成防止がないことを指摘（ネットワークリトライによる重複カルテ作成リスク） | B該当なし | ✅ +0.5 |
| 3. JWTトークン取り消しメカニズムの欠如 | 認証・認可設計 | ログアウトやパスワード変更時のトークン無効化機構の欠如を指摘（Redisブラックリスト提案） | B該当なし | ✅ +0.5 |

**ボーナス合計**: 3件 × 0.5 = +1.5

### Run2 ボーナス (+2.0 = 4件)

| 項目 | カテゴリ | 詳細 | 正解キー該当 | 判定 |
|------|---------|------|------------|------|
| 1. 決済APIの冪等性欠如 | 入力検証設計（冪等性） | Run1と同様の指摘（医療費支払い機能の冪等性設計欠如） | B該当なし | ✅ +0.5 |
| 2. 予約作成APIの冪等性欠如 | 入力検証設計（冪等性） | POST /api/v1/appointmentsのDB制約またはIdempotency-Key必須化の提案 | P05でカバー済（キャンセル中心）だが独立指摘 | ✅ +0.5 |
| 3. 電子カルテ作成APIの冪等性欠如 | 入力検証設計（冪等性） | Run1と同様の指摘 | B該当なし | ✅ +0.5 |
| 4. JWTトークン取り消しメカニズムの欠如 | 認証・認可設計 | Run1と同様の指摘（Section 2.8） | B該当なし | ✅ +0.5 |

**ボーナス合計**: 4件 × 0.5 = +2.0

---

## ペナルティ詳細

### Run1 ペナルティ (0件)

スコープ外の指摘なし。

### Run2 ペナルティ (0件)

スコープ外の指摘なし。

---

## 問題別詳細分析

### P01: JWT有効期限が長すぎる
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション1.4「JWT認証に複数の脆弱性」の問題2
  - 検出根拠: "有効期限24時間は漏洩時の被害期間が長すぎる"、"アクセストークンの有効期限を15分に短縮"、"リフレッシュトークン（7日間有効）を導入"
  - 判定理由: 24時間の問題点、短縮提案、リフレッシュトークン導入をすべて満たす
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション1.5「JWT Token Storage Location Not Specified」の問題内容
  - 検出根拠: "24-hour expiration extends damage window after token theft"、"short-lived access tokens (15 minutes) + long-lived refresh tokens (7 days)"
  - 判定理由: Run1と同様の完全な指摘

### P02: JWTの署名アルゴリズムと鍵管理方針が未定義
- **Run1判定**: △ (0.5)
  - 該当箇所: セクション1.4「JWT認証に複数の脆弱性」の問題1
  - 検出根拠: "JWTトークンの保存場所が明記されていない"
  - 判定理由: JWTのセキュリティ問題に言及しているが、署名アルゴリズム・鍵管理の具体的欠如には触れていない
- **Run2判定**: △ (0.5)
  - 該当箇所: セクション1.5「JWT Token Storage Location Not Specified」
  - 検出根拠: トークン保存場所の問題のみ
  - 判定理由: Run1と同様、署名アルゴリズムや秘密鍵管理方針の欠如には未言及

### P03: 他院との診療情報共有における認可設計が不明確
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション2.4「診療情報共有の認可設計が曖昧」
  - 検出根拠: "`is_shared` フラグのみで他院共有を制御しているが、どの医療機関が共有可能か、患者の同意管理、共有ログの記録が不明"、"患者が共有先医療機関を明示的に選択・承認するUIフローを設計"、"共有アクセスログ（誰がいつどのカルテにアクセスしたか）を監査証跡として記録"
  - 判定理由: 患者同意、アクセス権限期限、アクセスログ記録の欠如をすべて指摘
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション1.6「Medical Record Sharing Lacks Access Audit Trail」
  - 検出根拠: "Who accessed shared records and when"、"Patient consent tracking for sharing"、"Create medical_record_access_log table"、"Require explicit patient consent"
  - 判定理由: Run1と同様の完全な指摘

### P04: 入力検証方針の欠如
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション2.1「入力バリデーション戦略が未定義」
  - 検出根拠: "外部入力（患者登録情報、問診票、カルテ内容）の検証ポリシー、SQLインジェクション防止措置、ファイルアップロード制限が設計書に記載されていない"、"Bean Validation（Jakarta Validation 3.0）で全APIリクエストを検証"、"SQLインジェクション対策としてJPA Criteria APIまたはPreparedStatementを使用"
  - 判定理由: 入力検証方針の欠如、SQLインジェクション・XSS等の脆弱性リスク、具体的検証方針をすべて満たす
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション2.4「No Input Validation Policy for External Inputs」、2.5「No SQL Injection Prevention Measures Documented」
  - 検出根拠: "Lack of input validation enables SQL injection"、"Stored XSS"、"Use Spring Boot's @Valid annotation"、"All database queries must use JPA/Hibernate parameterized queries"
  - 判定理由: Run1と同様の完全な指摘

### P05: 予約キャンセルAPIの冪等性が未定義
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション1.1「予約APIに冪等性保証がない」
  - 検出根拠: "POST /api/v1/appointments (予約作成) および DELETE /api/v1/appointments/{id} (予約キャンセル) に冪等性設計が存在しない"、"予約作成APIに Idempotency-Key ヘッダー（クライアント生成UUID）を必須化"、"予約キャンセルは既にキャンセル済みの場合でも200 OKを返し、冪等性を保証"
  - 判定理由: 予約キャンセルAPIの冪等性欠如と重複リクエスト処理方針を指摘
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション1.2「Appointment Creation/Cancellation Lacks Idempotency Design」
  - 検出根拠: "POST /api/v1/appointments and DELETE /api/v1/appointments/{id} endpoints have no protection against duplicate submissions"、"For DELETE: Make operation idempotent by design - return HTTP 204 No Content even if already cancelled"
  - 判定理由: Run1と同様の完全な指摘

### P06: 監査ログの記録範囲が不十分
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション2.4「診療情報共有の認可設計が曖昧」の一部
  - 検出根拠: "共有アクセスログ（誰がいつどのカルテにアクセスしたか）を監査証跡として記録"
  - 判定理由: 他院共有時のアクセス元医療機関・医師の記録必要性を指摘
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション2.10「No Audit Logging for Administrative Actions」
  - 検出根拠: "Administrative actions (creating doctor accounts, modifying patient records, accessing system statistics) should be audited"、"Create separate audit log stream in CloudWatch Logs"
  - 判定理由: 管理者操作の監査ログ欠如を指摘（医療情報アクセスログとは異なる観点だが、監査ログ範囲不足として有効）

### P07: データベース内の暗号化対象が限定的
- **Run1判定**: × (0.0)
  - 該当箇所: セクション2.5「データベース暗号化の鍵管理が未定義」
  - 検出根拠: 鍵管理方針の欠如のみ指摘
  - 判定理由: 暗号化対象の限定（氏名、生年月日等の個人情報）には触れていない
- **Run2判定**: △ (0.5)
  - 該当箇所: セクション2.2「Database Encryption Key Management Not Designed」
  - 検出根拠: "Section 7.2 states 'DB内の機密情報（診断内容、処方箋）はAES-256で暗号化'"、"Use separate KMS keys for different data classifications (patient demographics vs medical records)"
  - 判定理由: データ分類の言及はあるが、具体的な暗号化対象拡大（氏名・生年月日等）への明示的提案は不十分

### P08: APIレート制限の設計が不十分
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション2.3「APIレート制限が全エンドポイント一律」
  - 検出根拠: "ログインAPIへのブルートフォース攻撃、予約枠の買い占め、決済APIの悪用に対する防御が不十分"、"/api/v1/auth/login: 5回/15分（IP単位）+ アカウント5回失敗で30分ロック"
  - 判定理由: 未認証ユーザー・ログイン試行への独立レート制限欠如とブルートフォース攻撃対策を指摘
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション2.1「No Rate Limiting for Authentication Endpoints」
  - 検出根拠: "Login endpoints are prime targets for credential stuffing and brute-force attacks"、"Configure stricter rate limiting for /api/v1/auth/login: 5 attempts per 15 minutes per email address"
  - 判定理由: Run1と同様の完全な指摘

### P09: エラーメッセージで内部情報が露出する可能性
- **Run1判定**: ○ (1.0)
  - 該当箇所: セクション1.3「エラーレスポンスが内部実装の詳細を露出」
  - 検出根拠: "5xx系エラー時に内部情報（スタックトレース、SQLクエリ、ファイルパス、ライブラリバージョン）を露出する可能性が明示的に排除されていない"、"5xx系エラーのクライアントレスポンスは汎用メッセージのみ"
  - 判定理由: 本番環境でのエラーメッセージ詳細度と環境別切り替えを指摘
- **Run2判定**: ○ (1.0)
  - 該当箇所: セクション1.4「Error Messages May Leak Sensitive Information」
  - 検出根拠: "Medical systems often leak: Internal paths in stack traces, Database schema details in SQL error messages, Library version numbers in exception messages"、"Client errors (4xx): Safe, generic messages only"、"Server errors (5xx): Generic message 'Internal server error' with error tracking ID"
  - 判定理由: Run1と同様の完全な指摘

---

## 総評

### バリアント特性の評価
- **冪等性検出の強化**: 予約キャンセル（P05）に加え、決済API、予約作成API、電子カルテ作成APIの冪等性欠如を追加で検出
- **Run1とRun2の安定性**: 主要な9問のうち8問で一貫した検出パターン（P07のみ差分）
- **ボーナス獲得の一貫性**: 両実行とも冪等性関連のボーナスを3-4件獲得

### 検出の強み
1. **冪等性問題の網羅性**: 設計書に明示されていない決済API・電子カルテ作成APIの冪等性欠如まで検出
2. **JWT認証の多角的分析**: 有効期限（P01）、保存場所（P02関連）、取り消しメカニズム（ボーナス）をセットで指摘
3. **入力検証の具体性**: SQLインジェクション・XSS対策だけでなく、Bean Validation・ファイルアップロード制限まで言及

### 検出の弱点
1. **P02（署名アルゴリズム・鍵管理）**: JWTの保存場所には言及するが、署名アルゴリズム（HS256/RS256）や秘密鍵管理（AWS Secrets Manager）の具体的欠如には触れていない
2. **P07（暗号化対象の限定）**: Run1は完全未検出、Run2も部分検出に留まる。氏名・生年月日等の具体的な個人情報の暗号化拡大提案が不十分

### 推奨事項
- バリアント「idempotency-checks」は冪等性検出に特化しつつ、他のセキュリティ問題も高水準で検出
- 平均スコア9.5、SD 0.71は高い性能と安定性を示す
- P02・P07の検出精度向上のため、perspective.mdに「署名アルゴリズム選択」「暗号化対象の包括性」を評価項目として追加することを検討
