# セキュリティ設計レビュー結果

## 重大な問題

### P07-1: 個人健康情報（PHI）の分類とガバナンスポリシーの欠如
**重要度**: 重大
**カテゴリ**: Data Protection

**問題**:
設計書には患者の氏名、生年月日、住所、電話番号、保険証番号、診断内容、処方薬、検査結果など、極めて機密性の高い医療情報が含まれているにもかかわらず、**データ分類ポリシー**が全く定義されていません。また、医療情報の保存期間、自動削除ポリシー、データライフサイクル管理（収集→保存→アーカイブ→削除）の設計が欠落しています。

医療情報は一般的な個人情報よりも厳格な管理が法的に要求されます（個人情報保護法、医療法、ガイドライン等）が、現状の設計では以下が不明確です：
- どのデータが「機微な医療情報」として分類されるのか
- 各分類レベルに対する保護措置（暗号化、アクセス制限、監査）
- 保存期間（例：診察記録は5年間保持など）と自動削除の仕組み
- データの最小化原則（必要最小限のデータのみ収集・保持）の適用

**影響**:
- 法令違反リスク（個人情報保護法、医療情報ガイドライン違反）
- 不要なデータの長期保管による情報漏洩リスクの増大
- データ主体（患者）の権利（削除権、訂正権）への対応不備
- 内部監査・外部監査時のコンプライアンス証明不可

**推奨対策**:
1. **データ分類の明示化**:
   - Level 1（公開可能）: 医療機関名、診療科目
   - Level 2（要保護）: ユーザー名、メールアドレス
   - Level 3（機微情報）: 患者氏名、生年月日、住所、電話番号、保険証番号
   - Level 4（最高機密）: 診断内容、処方薬、検査結果、カルテ情報

2. **保存期間と自動削除ポリシーの設計**:
   ```
   - 診察記録（medical_records）: 5年間保持後、匿名化アーカイブ
   - 予約情報（appointments）: 診察完了後1年間保持、その後削除
   - 患者プロフィール（patients）: アカウント削除時に即座に削除（GDPR準拠）
   - 監査ログ: 7年間保持（法的要件）
   ```

3. **データライフサイクル管理の実装**:
   - 定期バッチジョブによる保存期限切れデータの自動削除
   - 削除前の暗号化バックアップ作成（法的保持義務対応）
   - 患者によるデータ削除リクエスト機能の提供

4. **暗号化とアクセス制御の分類別適用**:
   - Level 3/4データは保存時暗号化（AES-256）必須
   - Level 4データへのアクセスは医療従事者ロールに限定し、全アクセスを監査ログに記録

**参照箇所**: 4.1 主要エンティティ、4.2 テーブル設計（患者情報、診察記録）

---

### P14-1: データ整合性検証機構の欠如
**重要度**: 重大
**カテゴリ**: Threat Modeling (Tampering)

**問題**:
医療記録（診断内容、処方薬、検査結果）という改ざんが患者の生命に直結するデータを扱うシステムであるにもかかわらず、**データ整合性検証機構**が設計に含まれていません。

現状の設計では以下のリスクが存在します：
- データベース直接アクセスによる診察記録の改ざん（内部不正）
- アプリケーション層の脆弱性を突いた不正更新
- バックアップデータの改ざん検出不可
- 監査証跡の完全性保証なし

特に、`medical_records`テーブルには`updated_at`カラムすらなく、変更履歴の追跡も不可能です。医療記録は法的証拠能力を持つ文書であり、改ざん検知と防止は必須要件です。

**影響**:
- 医療過誤隠蔽のリスク（誤診断の事後書き換え）
- 薬剤情報改ざんによる患者への健康被害
- 法的紛争時の証拠能力喪失
- 医療機関の信頼性崩壊

**推奨対策**:
1. **診察記録の不変性保証設計**:
   ```sql
   -- medical_recordsテーブルに追加
   - record_hash VARCHAR(64) NOT NULL  -- SHA-256ハッシュ
   - previous_hash VARCHAR(64)          -- ブロックチェーン様の連鎖
   - digital_signature TEXT             -- 医師の電子署名
   - updated_at TIMESTAMP               -- 更新日時
   - version INT                        -- バージョン番号
   ```

2. **整合性検証メカニズムの実装**:
   - 診察記録作成時に `diagnosis + prescription + lab_results + doctor_name + created_at` のSHA-256ハッシュを計算し、`record_hash`に保存
   - 前の診察記録の`record_hash`を`previous_hash`に保存（改ざん連鎖検知）
   - 診察記録読み取り時に再計算したハッシュと保存値を比較し、不一致の場合はアラート発行

3. **変更履歴の監査ログ設計**:
   ```sql
   CREATE TABLE medical_record_audit (
     id BIGINT PRIMARY KEY,
     record_id BIGINT REFERENCES medical_records(id),
     changed_by BIGINT REFERENCES users(id),
     changed_at TIMESTAMP NOT NULL,
     old_hash VARCHAR(64),
     new_hash VARCHAR(64),
     change_reason TEXT,
     ip_address VARCHAR(45)
   );
   ```

4. **改ざん検知と対応手順**:
   - 日次バッチでデータベース全体の整合性スキャン
   - 不整合検出時は管理者へアラート + 該当レコードのロック
   - 改ざん検知レポートの自動生成と保管

**参照箇所**: 4.2 テーブル設計（medical_recordsテーブル）、3.3 データフロー

---

### P04-1: 認証エンドポイントへのレート制限と総当たり攻撃対策の欠如
**重要度**: 重大
**カテゴリ**: Input Validation & Attack Defense

**問題**:
設計書には「API Gatewayでレート制限（1分あたり100リクエスト）」が記載されていますが、これは**全エンドポイント一律の制限**であり、認証エンドポイント（`POST /api/auth/login`, `POST /api/auth/register`, `POST /api/auth/refresh`）に対する特化した防御策が存在しません。

医療情報システムへの不正アクセスは高い価値目標であり、以下の攻撃が想定されます：
- パスワード総当たり攻撃（100req/minでも1日144,000回の試行可能）
- アカウント列挙攻撃（登録済みユーザー名の特定）
- クレデンシャルスタッフィング（漏洩パスワードの使い回し）

現状の設計では以下が欠落しています：
- 認証エンドポイント専用のより厳格なレート制限
- アカウントロックアウト機構
- 認証失敗の監視とアラート

**影響**:
- 患者アカウントの不正乗っ取り → 医療情報の閲覧・改ざん
- 医療従事者アカウント侵害 → 診察記録の不正作成・削除
- 管理者アカウント侵害 → システム全体の制御奪取
- DDoS攻撃による認証サービス停止 → 緊急時の医療サービス提供不可

**推奨対策**:
1. **認証エンドポイント専用のレート制限設計**:
   ```
   - POST /api/auth/login:
     - IPアドレスごと: 5回/分、20回/時間
     - ユーザー名ごと: 3回/分、10回/時間（アカウント列挙防止）
   - POST /api/auth/register:
     - IPアドレスごと: 3回/時間（大量登録防止）
   - POST /api/auth/refresh:
     - トークンごと: 10回/分
   ```

2. **段階的ブルートフォース防御機構**:
   - 3回失敗: 5秒の待機時間挿入
   - 5回失敗: アカウント15分間ロック + メール通知
   - 10回失敗: アカウント1時間ロック + 管理者アラート
   - ロック解除は管理者承認またはメール認証経由

3. **認証失敗監視とアラート設計**:
   ```
   認証失敗イベントをCloudWatch Logs Insightsで監視:
   - 同一IPから複数アカウントへの失敗（5分間に10アカウント以上）
   - 単一アカウントへの大量失敗（1時間に50回以上）
   - 地理的に異常なアクセス（国外IPからの管理者ログイン試行）
   → アラート発火 + 自動IP遮断
   ```

4. **CAPTCHA統合**:
   - 2回連続失敗後はreCAPTCHA v3による人間検証を要求
   - 管理者ログインは常にCAPTCHA必須

5. **パスワードポリシーの明示化**:
   - 最小12文字、大小英字・数字・記号の組み合わせ必須
   - 過去3世代のパスワード再利用禁止
   - 漏洩パスワードデータベース（Have I Been Pwned API等）との照合

**参照箇所**: 5.1 認証API、5.3 認証・認可方式、3.2 API Gatewayの責務

---

## 重要な問題

### P02-1: API認可チェックの設計欠落
**重要度**: 重要
**カテゴリ**: Authentication & Authorization Design

**問題**:
設計書には「ロールベースアクセス制御（RBAC）により、エンドポイントごとに必要なロールを定義」と記載されていますが、**具体的な認可チェックロジック**が記載されていません。特に以下のリソースアクセスエンドポイントで、所有権・権限検証の設計が欠落しています：

1. `GET /api/patients/{id}` - 患者情報取得
   - 問題: 他人の患者情報を`{id}`を変更してアクセス可能か不明
   - 必要な検証: リクエストユーザーのIDと`{id}`の一致確認、または医療従事者ロールの場合は診察担当かの確認

2. `PUT /api/patients/{id}` - 患者情報更新
   - 問題: 他人の住所や電話番号を変更可能か不明
   - 必要な検証: 本人または担当医師のみ更新可能

3. `GET /api/patients/{id}/records` - 診察履歴取得
   - 問題: 機微な診察記録を第三者が閲覧可能か不明
   - 必要な検証: 本人または担当医師のみ閲覧可能

4. `GET /api/appointments/{id}` - 予約詳細取得
   - 問題: 他人の予約情報（医療機関、診療科）の閲覧可否不明
   - 必要な検証: 本人、予約先医療機関の医療従事者のみ閲覧可能

5. `DELETE /api/appointments/{id}` - 予約キャンセル
   - 問題: 他人の予約を勝手にキャンセル可能か不明
   - 必要な検証: 本人または予約先医療機関の管理者のみキャンセル可能

現状では、JWT内のロールのみで制御している可能性が高く、**水平権限昇格（同じロールの他ユーザーのリソースにアクセス）**の脆弱性が存在します。

**影響**:
- 患者の医療情報の不正閲覧（プライバシー侵害）
- 他人の診察記録の改ざん
- 他人の予約のキャンセル（サービス妨害）
- 内部不正（医療従事者による権限外データアクセス）

**推奨対策**:
1. **エンドポイントごとの認可チェック設計の明示化**:
   ```
   GET /api/patients/{id}:
     - ロール PATIENT: JWTのuserIdに紐づくpatient.idと{id}が一致する場合のみ許可
     - ロール DOCTOR: {id}の患者の予約（appointments）にログイン医師が担当医として含まれる場合のみ許可
     - ロール ADMIN: 全患者情報アクセス可能

   GET /api/records/{id}:
     - ロール PATIENT: records.patient_idが自分のpatient.idと一致する場合のみ許可
     - ロール DOCTOR: records.doctor_nameが自分の名前と一致する場合のみ許可
     - ロール ADMIN: 全レコードアクセス可能（監査ログ必須）

   DELETE /api/appointments/{id}:
     - ロール PATIENT: appointments.patient_idが自分のpatient.idと一致する場合のみ許可
     - ロール DOCTOR: 不可（医療機関都合のキャンセルは別エンドポイント）
     - ロール ADMIN: 全予約キャンセル可能
   ```

2. **認可ロジックの実装パターン**:
   ```java
   @GetMapping("/api/patients/{id}")
   public PatientDTO getPatient(@PathVariable Long id, @AuthenticationPrincipal UserDetails user) {
     Patient patient = patientRepository.findById(id)
       .orElseThrow(() -> new NotFoundException("Patient not found"));

     // 認可チェック
     if (user.getRole() == Role.PATIENT) {
       if (!patient.getUserId().equals(user.getUserId())) {
         throw new ForbiddenException("Access denied");
       }
     } else if (user.getRole() == Role.DOCTOR) {
       if (!isDoctorAssignedToPatient(user.getUserId(), id)) {
         throw new ForbiddenException("Access denied");
       }
     }
     // ADMIN は無条件アクセス可能

     auditLog.log("PATIENT_ACCESS", user.getUserId(), id);
     return patientMapper.toDTO(patient);
   }
   ```

3. **認可失敗時の監査ログ記録**:
   - 全ての認可拒否イベントを記録（試行したユーザー、リソースID、タイムスタンプ）
   - 短時間に複数の認可拒否が発生した場合はアラート

**参照箇所**: 5.1 API設計、5.3 認証・認可方式

---

### P05-1: シークレット管理の具体的設計欠如
**重要度**: 重要
**カテゴリ**: Infrastructure, Dependencies & Audit

**問題**:
設計書には「環境変数はECS Task Definitionに記載し、AWS Systems Manager Parameter Storeから取得」と記載されていますが、以下の点が不明確です：

1. **どのシークレットをParameter Storeで管理するのか明示されていない**:
   - データベース接続情報（ホスト、ポート、ユーザー名、パスワード）
   - JWT署名鍵
   - AWS S3アクセスキー
   - 外部APIキー（通知サービス、決済サービス等）
   - Redis接続情報

2. **Parameter Storeのアクセス権限設計が欠如**:
   - どのECSタスクロールがどのパラメータにアクセス可能か
   - 開発者のParameter Storeへのアクセス権限（読み取り専用か、書き込み可能か）

3. **シークレットローテーション戦略が未定義**:
   - データベースパスワードやJWT署名鍵の定期変更方針
   - ローテーション時のダウンタイム回避方法

4. **シークレット漏洩防止策が不明**:
   - ログにシークレットが含まれないようにする仕組み
   - GitHubリポジトリへのハードコード防止策

**影響**:
- シークレットのハードコードによる漏洩（GitHubへのコミット等）
- 不適切なアクセス権限による内部不正（開発者が本番DBパスワードを閲覧）
- シークレット漏洩時の迅速なローテーション不可
- ログファイルからのクレデンシャル窃取

**推奨対策**:
1. **管理対象シークレットの一覧化**:
   ```
   Parameter Store構成（/medical-reservation/{env}/以下）:
   - /database/host
   - /database/port
   - /database/username
   - /database/password (SecureString, KMS暗号化)
   - /jwt/signing-key (SecureString)
   - /redis/connection-string (SecureString)
   - /aws/s3-access-key-id
   - /aws/s3-secret-access-key (SecureString)
   - /notification/api-key (SecureString)
   ```

2. **IAMロールベースのアクセス制御設計**:
   ```json
   // ECS Task Role ポリシー（本番環境）
   {
     "Effect": "Allow",
     "Action": ["ssm:GetParameter", "ssm:GetParameters"],
     "Resource": [
       "arn:aws:ssm:ap-northeast-1:ACCOUNT_ID:parameter/medical-reservation/prod/*"
     ]
   }

   // 開発者ロール（読み取り専用、開発環境のみ）
   {
     "Effect": "Allow",
     "Action": ["ssm:GetParameter"],
     "Resource": [
       "arn:aws:ssm:ap-northeast-1:ACCOUNT_ID:parameter/medical-reservation/dev/*"
     ]
   }
   ```

3. **シークレットローテーション戦略**:
   - データベースパスワード: 90日ごとに自動ローテーション（AWS Secrets Manager併用）
   - JWT署名鍵: 180日ごとにローテーション（複数鍵の同時有効化でダウンタイム回避）
   - ローテーション実行は自動化（Lambda関数 + EventBridge）

4. **シークレット漏洩防止策**:
   - `.env.example`ファイルでダミー値を提供、`.env`は`.gitignore`に追加
   - GitHub Actionsでgit-secretsによるコミット前スキャン
   - Logbackでパスワードフィールドのマスキング設定
   - スタックトレースに環境変数を含めない設定

**参照箇所**: 6.4 デプロイメント方針、2.4 主要ライブラリ

---

### P05-2: セキュリティ監査ログの設計不備
**重要度**: 重要
**カテゴリ**: Infrastructure, Dependencies & Audit

**問題**:
6.2節のロギング方針には「すべてのAPIリクエスト・レスポンスをINFOレベルでログ出力」とありますが、以下の問題があります：

1. **セキュリティイベントの明示的記録が欠如**:
   - 認証失敗（ユーザー名、IPアドレス、失敗理由）
   - 認可拒否（アクセス試行したリソース、ユーザー、ロール）
   - 権限変更（ユーザーロールの変更、実行者）
   - 機微データアクセス（診察記録の閲覧・更新、患者情報の閲覧）
   - 設定変更（システム設定の変更、医療機関の追加・削除）

2. **ログの改ざん防止策が未設計**:
   - ログファイル自体が改ざんされた場合の検知方法がない
   - 監査ログの整合性検証機構がない

3. **ログ保存期間が明示されていない**:
   - 医療情報関連のログは法的保持義務がある可能性
   - セキュリティインシデント調査に必要な期間の保存が保証されていない

4. **ログ内の機微情報の扱いが不明**:
   - 例のログフォーマットには`"requestBody": "{...}"`が含まれるが、診察記録作成APIのログにはPHIが含まれる可能性

**影響**:
- セキュリティインシデント発生時の原因調査不可
- 内部不正の検知・証明不可
- コンプライアンス監査対応不可（監査ログ不足）
- ログ改ざんによる証拠隠滅のリスク

**推奨対策**:
1. **セキュリティ監査ログの明示的設計**:
   ```json
   // セキュリティイベント専用ログフォーマット
   {
     "timestamp": "2025-01-15T10:30:00Z",
     "eventType": "AUTHENTICATION_FAILURE",
     "severity": "WARNING",
     "userId": "patient001",
     "ipAddress": "203.0.113.45",
     "userAgent": "Mozilla/5.0...",
     "failureReason": "Invalid password",
     "attemptCount": 3
   }

   {
     "eventType": "SENSITIVE_DATA_ACCESS",
     "severity": "INFO",
     "userId": "doctor123",
     "role": "DOCTOR",
     "resourceType": "MEDICAL_RECORD",
     "resourceId": "11111",
     "patientId": "67890",
     "action": "READ",
     "authorized": true
   }

   {
     "eventType": "AUTHORIZATION_DENIED",
     "severity": "WARNING",
     "userId": "patient002",
     "role": "PATIENT",
     "resourceType": "PATIENT",
     "resourceId": "67890",
     "requestedAction": "READ",
     "denialReason": "Patient ID mismatch"
   }
   ```

2. **記録対象セキュリティイベントの一覧化**:
   - 認証: ログイン成功/失敗、ログアウト、トークンリフレッシュ
   - 認可: 認可拒否、ロール変更
   - データアクセス: 診察記録の作成/読取/更新、患者情報の閲覧/更新
   - 管理操作: 医療機関の追加/削除、システム設定変更
   - セキュリティ設定: パスワード変更、MFA設定変更

3. **ログ改ざん防止策**:
   - CloudWatch Logsへのストリーミング配信（アプリケーションからの削除不可）
   - ログストリームのKMS暗号化
   - CloudWatch Logs Insightsでの異常検知（ログ欠損、タイムスタンプ異常）
   - 重要イベントログのS3へのアーカイブ + S3 Object Lock（WORM: Write Once Read Many）

4. **ログ保存期間の明示化**:
   ```
   - セキュリティ監査ログ: 7年間保持（CloudWatch Logs 90日 + S3アーカイブ 7年）
   - アクセスログ: 1年間保持
   - エラーログ: 6ヶ月保持
   - デバッグログ: 30日保持
   ```

5. **機微情報のログマスキング**:
   - `requestBody`のログ記録時に、`password`, `insurance_number`, `diagnosis`, `prescription`等のフィールドを`***REDACTED***`に置換
   - 必要な場合のみ、暗号化した完全ログを別途保存

**参照箇所**: 6.2 ロギング方針、5.3 認証・認可方式

---

## 中程度の問題

### P03-1: JWTトークンのlocalStorage保存によるXSS脆弱性
**重要度**: 中
**カテゴリ**: Data Protection

**問題**:
5.3節に「JWTトークンはlocalStorageに保存し、各APIリクエストのAuthorizationヘッダーで送信する」と記載されていますが、これは**XSS攻撃に対して脆弱**です。

localStorageはJavaScriptから自由にアクセス可能なため、XSS脆弱性が存在する場合、攻撃者のスクリプトがトークンを窃取できます。医療情報システムでは、トークン窃取は患者の機微情報への不正アクセスに直結します。

**影響**:
- XSS攻撃によるJWTトークンの窃取
- 窃取したトークンによる患者情報の不正アクセス
- セッションハイジャック（攻撃者が正規ユーザーとしてログイン）

**推奨対策**:
1. **HttpOnly Cookieへの変更**:
   - JWTをHttpOnly属性付きCookieに保存（JavaScriptからアクセス不可）
   - Secure属性でHTTPS通信のみに制限
   - SameSite=Strict属性でCSRF対策

2. **実装例**:
   ```java
   // ログインレスポンスでCookie設定
   Cookie jwtCookie = new Cookie("jwt", token);
   jwtCookie.setHttpOnly(true);
   jwtCookie.setSecure(true);
   jwtCookie.setMaxAge(3600); // 1時間
   jwtCookie.setPath("/");
   jwtCookie.setAttribute("SameSite", "Strict");
   response.addCookie(jwtCookie);
   ```

3. **CSRF対策の追加**:
   - CSRFトークンを別途発行し、カスタムヘッダーで送信
   - Spring SecurityのCsrfTokenRepositoryを使用

4. **XSS対策の強化**:
   - Content Security Policy (CSP) ヘッダーの設定（`script-src 'self'`等）
   - React等のフレームワークによる自動エスケープの活用
   - DOMPurifyによるHTMLサニタイゼーション

**参照箇所**: 5.3 認証・認可方式

---

### P04-2: 外部入力検証の具体性欠如
**重要度**: 中
**カテゴリ**: Input Validation & Attack Defense

**問題**:
7.2節に「外部入力はSpring Validationで検証」とありますが、具体的な検証ルールが記載されていません。以下のフィールドで不適切な入力を許容すると、データ品質問題やセキュリティリスクが発生します：

1. **患者情報のバリデーション不明**:
   - `phone_number`: 形式検証なし（国際電話番号対応か？）
   - `email`: メールアドレス形式検証の詳細不明
   - `insurance_number`: 保険証番号の形式検証不明（桁数、チェックディジット等）

2. **診察記録の入力制限不明**:
   - `diagnosis`, `prescription`, `lab_results`: 最大長制限なし → DoS攻撃やストレージ枯渇のリスク
   - HTMLタグ等の許可/不許可が不明 → XSS格納型攻撃のリスク

3. **日付・時刻の検証不明**:
   - `appointment_time`: 過去日時や営業時間外の予約を受け付けるか不明
   - `date_of_birth`: 未来日付や異常値（1800年等）の防止策不明

**影響**:
- 不正なデータの格納によるアプリケーションエラー
- XSS格納型攻撃（診察記録にスクリプト埋め込み）
- DoS攻撃（巨大テキストによるストレージ/メモリ枯渇）
- データ品質低下（電話番号が「あああ」等）

**推奨対策**:
1. **バリデーションルールの明示化**:
   ```java
   // PatientDTO
   @Pattern(regexp = "^[0-9]{2,4}-[0-9]{2,4}-[0-9]{3,4}$", message = "Invalid phone number format")
   private String phoneNumber;

   @Email(message = "Invalid email format")
   @NotBlank
   private String email;

   @Pattern(regexp = "^[0-9]{8}$", message = "Insurance number must be 8 digits")
   private String insuranceNumber;

   @Past(message = "Date of birth must be in the past")
   private LocalDate dateOfBirth;
   ```

2. **診察記録のサニタイゼーション**:
   ```java
   @Size(max = 10000, message = "Diagnosis text too long")
   private String diagnosis;

   // HTMLタグを除去またはエスケープ
   String sanitizedDiagnosis = Jsoup.clean(input, Whitelist.none());
   ```

3. **予約時刻の検証ロジック**:
   ```java
   @Future(message = "Appointment time must be in the future")
   private LocalDateTime appointmentTime;

   // カスタムバリデータで営業時間チェック
   @ValidBusinessHours(startHour = 9, endHour = 18)
   private LocalDateTime appointmentTime;
   ```

4. **リクエストサイズ制限**:
   ```yaml
   # application.yml
   spring:
     servlet:
       multipart:
         max-file-size: 10MB
         max-request-size: 10MB
   server:
     tomcat:
       max-http-form-post-size: 2MB
   ```

**参照箇所**: 7.2 セキュリティ要件、4.2 テーブル設計

---

### P04-3: CORS設定の具体性欠如
**重要度**: 中
**カテゴリ**: Input Validation & Attack Defense

**問題**:
設計書にはCORS（Cross-Origin Resource Sharing）に関する言及が全くありません。React SPAとSpring Boot APIが異なるオリジン（例: フロントエンド `https://app.medical-reservation.com`、バックエンド `https://api.medical-reservation.com`）で動作する場合、適切なCORS設定がないとブラウザがリクエストをブロックします。

一方、過度に緩いCORS設定（`Access-Control-Allow-Origin: *`）は、悪意のあるサイトからのAPIアクセスを許可してしまい、CSRF攻撃やデータ窃取のリスクがあります。

**影響**:
- 不適切なCORS設定によるアプリケーション動作不良
- `*`許可による悪意のあるサイトからのAPIアクセス
- CSRF攻撃の成功（Cookieベース認証との組み合わせ）

**推奨対策**:
1. **許可オリジンの明示化**:
   ```java
   @Configuration
   public class CorsConfig {
     @Bean
     public WebMvcConfigurer corsConfigurer() {
       return new WebMvcConfigurer() {
         @Override
         public void addCorsMappings(CorsRegistry registry) {
           registry.addMapping("/api/**")
             .allowedOrigins(
               "https://app.medical-reservation.com",
               "https://mobile.medical-reservation.com"
             )
             .allowedMethods("GET", "POST", "PUT", "DELETE")
             .allowedHeaders("Authorization", "Content-Type", "X-CSRF-Token")
             .allowCredentials(true)
             .maxAge(3600);
         }
       };
     }
   }
   ```

2. **環境別のオリジン設定**:
   ```yaml
   # application-dev.yml
   cors:
     allowed-origins: http://localhost:3000

   # application-prod.yml
   cors:
     allowed-origins: https://app.medical-reservation.com
   ```

3. **プリフライトリクエストの最適化**:
   - `maxAge`を3600秒に設定し、OPTIONSリクエストのキャッシュを有効化

**参照箇所**: 3.1 全体構成、5.3 認証・認可方式

---

### P05-3: 依存ライブラリの脆弱性管理方針の欠如
**重要度**: 中
**カテゴリ**: Infrastructure, Dependencies & Audit

**問題**:
2.4節で使用ライブラリが列挙されていますが、脆弱性管理方針が記載されていません。医療情報システムでは、第三者ライブラリの脆弱性が情報漏洩やシステム侵害につながります。

現状では以下が不明確です：
- 脆弱性スキャンの実施方法と頻度
- 脆弱性発見時のパッチ適用プロセス
- 脆弱性情報の監視方法

**影響**:
- 既知の脆弱性を持つライブラリの使用継続
- ゼロデイ脆弱性公開時の迅速な対応不可
- セキュリティインシデントの発生

**推奨対策**:
1. **自動脆弱性スキャンの組み込み**:
   ```yaml
   # GitHub Actions CI
   - name: Dependency vulnerability scan
     run: |
       ./mvnw dependency-check:check
       # または
       ./mvnw org.owasp:dependency-check-maven:check
   ```

2. **Dependabotの有効化**:
   - GitHubリポジトリでDependabotを有効化し、脆弱性アラートと自動PR作成
   - 毎週の依存関係更新チェック

3. **脆弱性対応SLA**:
   ```
   - Critical (CVSS 9.0-10.0): 24時間以内にパッチ適用
   - High (CVSS 7.0-8.9): 7日以内にパッチ適用
   - Medium (CVSS 4.0-6.9): 30日以内にパッチ適用
   ```

4. **脆弱性情報の監視**:
   - NVD (National Vulnerability Database) の監視
   - Spring Security Advisories の購読
   - AWS Security Bulletins の確認

**参照箇所**: 2.4 主要ライブラリ

---

## 軽微な改善提案

### P07-2: データベースパスワードの暗号化詳細不明
**重要度**: 軽微
**カテゴリ**: Data Protection

**問題**:
7.2節に「パスワードはbcryptアルゴリズム（コスト係数10）でハッシュ化する」とありますが、これはユーザーパスワードのハッシュ化であり、データベースレベルの暗号化（Transparent Data Encryption）への言及がありません。

**推奨対策**:
- PostgreSQL 16のTDE（Transparent Data Encryption）拡張の検討
- または、Amazon RDS for PostgreSQLの暗号化オプション有効化（KMS管理鍵使用）

**参照箇所**: 7.2 セキュリティ要件

---

### P04-4: SQLインジェクション対策の具体性不足
**重要度**: 軽微
**カテゴリ**: Input Validation & Attack Defense

**問題**:
7.2節に「SQLインジェクション対策としてPreparedStatementを使用する」とありますが、Spring Data JPAを使用している場合、PreparedStatementは自動的に使われるため、この記述は不正確です。また、動的クエリ（`@Query`アノテーションでの文字列連結等）のリスクへの言及がありません。

**推奨対策**:
1. **動的クエリのレビュー方針**:
   - `@Query`アノテーション使用時はパラメータバインディング（`:paramName`）を必須とする
   - ネイティブクエリ（`nativeQuery = true`）の使用は最小限にし、使用時は必ずコードレビュー必須

2. **静的解析ツールの導入**:
   - SpotBugs + Find Security Bugs プラグインでSQLインジェクションパターン検出

**参照箇所**: 7.2 セキュリティ要件

---

## 肯定的な評価

### P-1: 基本的な認証・暗号化の採用
以下の設計判断は適切です：
- JWT認証の採用（ステートレス、スケーラブル）
- bcryptによるパスワードハッシュ化（コスト係数10は適切）
- TLS 1.3での通信暗号化（最新の安全なプロトコル）
- Spring Securityの採用（実績のあるセキュリティフレームワーク）

### P-2: 多層防御の考慮
- API Gatewayでのレート制限
- Spring Securityでの認証・認可
- PostgreSQL Multi-AZ構成による可用性確保

これらは良好なセキュリティ設計の基盤となっています。

---

## 総括

本設計書は基本的なセキュリティ対策（認証、暗号化、ロールベースアクセス制御）を含んでいますが、**医療情報システムに求められる高度なセキュリティ要件**に対して重大な欠陥があります。

**最優先対応が必要な3つの問題**:
1. **P07-1**: 医療情報の分類とデータガバナンスポリシーの欠如（法令違反リスク）
2. **P14-1**: 診察記録のデータ整合性検証機構の欠如（改ざんリスク）
3. **P04-1**: 認証エンドポイントへの専用レート制限とブルートフォース対策の欠如（アカウント侵害リスク）

これらの問題を解決しない限り、本システムを医療現場で運用することは**セキュリティリスクおよび法的リスクの観点から推奨できません**。特にP07-1とP14-1は医療情報システム特有の要件であり、一般的なWebアプリケーションと同じレベルの対策では不十分です。

上記の推奨対策を実装した上で、外部のセキュリティ専門家によるレビューおよびペネトレーションテストの実施を強く推奨します。
