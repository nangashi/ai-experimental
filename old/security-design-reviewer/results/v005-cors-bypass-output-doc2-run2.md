# Security Design Review: Nexamart プラットフォーム システム設計書 v1.4.0

**Reviewer**: security-design-reviewer (v005-variant-cors-bypass-output)
**Document**: test-document-2.md
**Run**: doc2-run2

---

## Critical Issues

### C-01: CORSサフィックスマッチによる任意ドメインバイパス（CORS Bypass via Suffix-Only Regex）

**Section**: §6.4 CORS設定

**Issue**:
設計書に明示されたCORS設定は正規表現 `/\.nexamart\.com$/` によるオリジンマッチングを採用している。この正規表現はオリジンの末尾が `.nexamart.com` で終わることのみを検証しており、ドメインの先頭部分には制約を設けていない。

**具体的なバイパス攻撃パターン**:
攻撃者が `evil-nexamart.com` というドメインを取得した場合、このドメインは正規表現の末尾マッチを満たさない。しかし、`attacker.nexamart.com` のようにサブドメインを登録できる環境（テナントのサブドメインが `{tenant-slug}.nexamart.com` 形式である本設計では、テナント名として `evilnexamart.com` のようなピリオドを含む文字列が使用可能な場合）に注意が必要である。さらに深刻な問題として、正規表現がプロトコル部分（`https://` や `http://`）を除いたオリジン文字列全体に対してテストされる実装依存の問題がある。

より重大なバイパス：正規表現 `/\.nexamart\.com$/` はオリジン文字列 `https://evil.nexamart.com.attacker.com` のようなオリジンには一致しないが、`https://malicious-nexamart.com` の末尾は `.com` であり一致しない。ただし、`https://x.nexamart.com` 形式のサブドメインは意図通り許可される。

**実際に危険なパターン**: 実装コードがオリジンヘッダー全体（例: `https://evilnexamart.com`）に対してテストする場合、この正規表現はプロトコルを含む文字列の末尾が `.nexamart.com` で終わるかどうかのみを検査するため、`https://anything.nexamart.com` 系はすべて許可される。問題は第三者がサブドメインを作成できる場合（ワイルドカードDNSや外部サービス）、または `Access-Control-Allow-Credentials: true` と組み合わせた際に Cookie・Authorization ヘッダーを含むクロスオリジンリクエストが可能になる点である。

**本設計の最大リスク**: `Access-Control-Allow-Credentials: true` が設定されており、攻撃者が任意の `.nexamart.com` サブドメインを制御できる場合（例: テナント申請によるサブドメイン取得、または DNS サブドメイン乗っ取り）、被害者のブラウザから認証済みAPIリクエストを任意のオリジンから実行させることができる。

**Impact**: 認証済みセッションを利用したCORSバイパスにより、攻撃者のページから被害者ユーザーの権限でAPIを呼び出し可能。注文作成・個人情報取得・テナントデータアクセスが被害者の認証情報を使って実行される。

**Countermeasure**:
```javascript
// 推奨: 許可するオリジンを明示的に列挙する
const allowedOrigins = new Set([
  'https://nexamart.com',
  'https://www.nexamart.com',
  'https://admin.nexamart.com',
]);
// テナントサブドメインの動的許可が必要な場合
const TENANT_SUBDOMAIN_PATTERN = /^https:\/\/[a-z0-9\-]+\.nexamart\.com$/;
if (allowedOrigins.has(origin) || TENANT_SUBDOMAIN_PATTERN.test(origin)) {
  // テナントスラグが登録済みかDBで検証した上で許可
}
```
重要: サブドメインを動的に許可する場合は、テナントとして登録済みのスラグのみを許可するホワイトリスト検証をDBレベルで実施すること。

---

### C-02: アクセストークンの localStorage 保存による XSS 漏洩リスク

**Section**: §4.1 認証フロー

**Issue**:
アクセストークンを `localStorage` に保存する設計は、XSS 脆弱性が存在する場合にトークンが JavaScript から読み取り可能となる。本設計では CSP と DOMPurify によるXSS対策が施されているが、CDN配信コンテンツ・サードパーティスクリプト・将来的なサニタイズバイパスによりXSSが発生した場合、`localStorage` のアクセストークンは即座に窃取される。

**Impact**: アクセストークン（60分有効）の窃取により、被害者のセッション完全奪取。マルチテナント環境では他テナントへの不正操作の起点となりうる。

**Countermeasure**: アクセストークンも `HttpOnly` Cookie として保存し、JavaScript からアクセス不可能にする。CSRF対策として `SameSite=Strict` または `SameSite=Lax` 属性を付与する（§6.3の CSRF 対策の再設計も必要）。

---

### C-03: 本番シークレット値のリポジトリ保存

**Section**: §8.1 シークレット管理

**Issue**:
`config/secrets.prod.yaml` に本番環境のシークレット値を記録し、「アクセス制限を設けたうえでリポジトリに含める」設計は重大なセキュリティリスクである。Git リポジトリのアクセス制御はシークレット管理の代替手段として不十分である。

**Impact**: リポジトリへの不正アクセス・内部脅威・Git 履歴の誤った公開により、DBパスワード・JWT署名鍵・外部APIキー（Stripe, SendGrid）が一括漏洩する。JWT署名鍵の漏洩は任意のトークン偽造を可能にする。

**Countermeasure**: `config/secrets.prod.yaml` のリポジトリへの保存を即時廃止する。本番シークレットへのアクセスは AWS Secrets Manager のIAMポリシーによる制御のみとし、CI/CDパイプラインからの取得も最小権限IAMロールを使用する。

---

### C-04: CSRF対策の単一層依存（JWT のみによる CSRF 緩和）

**Section**: §6.3 CSRF対策

**Issue**:
「JWT は認証済みユーザーのみ保持できるため CSRF 対策として十分」という設計判断は、アクセストークンの保存場所（`localStorage`）に依存した単一層の対策である。アクセストークンを Cookie に移行した場合（C-02 の対策適用時）、JWT ベースの CSRF 緩和は機能しなくなる。また、現設計でも `localStorage` から JavaScript でトークンを読み取れる前提は XSS を CSRF 対策の前提条件として組み込んでいる。

**Reporting Rule — Defense Layer Separation への適合**:
「JWT による CSRF 緩和」と「追加 CSRF 対策の欠如」は独立した所見として報告する。

**Impact**: localStorage への XSS が成功した場合、または Cookie ベースへ移行した場合、state-changing 操作への CSRF 攻撃が可能になる。

**Countermeasure**: `SameSite=Strict` Cookie 属性または Double Submit Cookie パターンによる CSRF トークンを明示的に設計する。JWT ベースの CSRF 緩和を補完する独立した対策として実装すること。

---

### C-05: 追加CSRF対策の欠如（独立所見）

**Section**: §6.3 CSRF対策

**Issue**（C-04から独立した所見）:
設計書には JWT 以外の CSRF 対策（CSRF トークン、`SameSite` Cookie 属性）が明示的に設計されていない。

**Impact**: JWT 依存の CSRF 緩和が無効化される条件下（Cookie 移行、XSS 攻撃）で、全 state-changing API への CSRF 攻撃が無防備になる。

**Countermeasure**: `SameSite=Strict` を Cookie に明示指定するか、同期トークン方式の CSRF トークンを設計に追加する。

---

## Significant Issues

### S-01: アクセストークン即時無効化不能設計

**Section**: §4.2 セッション管理

**Issue**:
アクセストークン（60分有効）のサーバーサイドブロックリストが存在しない設計では、権限変更・不正検知・強制ログアウトが発生しても最大60分間トークンが有効であり続ける。マルチテナント環境でのロール変更（テナント管理者の権限剥奪等）が即座に反映されない。

**Impact**: 権限を剥奪されたユーザーが最大60分間、剥奪前の権限でAPIにアクセス可能。セキュリティインシデント発生時の迅速な対応が不可能。

**Countermeasure**: Redis のブロックリストにアクセストークンの JTI（JWT ID）を保存し、即時無効化を可能にする。アクセストークンの有効期限を短縮（5-15分）し、リフレッシュトークンによる自動更新を設計する。

---

### S-02: テナント識別の X-Tenant-ID ヘッダー信頼設計における内部サービス間での偽装リスク

**Section**: §3.2 マルチテナント分離方式

**Issue**:
Kong ゲートウェイが付与する `X-Tenant-ID` ヘッダーをコアAPIサービスが「信頼済み」として扱う設計は、Kong をバイパスしてコアAPIサービスに直接アクセスできる経路が存在する場合（内部ネットワーク、ECSコンテナ間通信、設定ミス）に、任意テナントへのアクセスが可能になる。

**Impact**: 内部ネットワークからのリクエストに任意の `X-Tenant-ID` ヘッダーを付与することでテナント間データ分離が破られる可能性。マルチテナント環境での最大級のリスク。

**Countermeasure**: コアAPIサービスにおいて、`X-Tenant-ID` ヘッダーの値を JWT の `tenantId` クレームと必ず照合し、一致しない場合は拒否する。Kong ゲートウェイとコアAPIサービス間の通信を mTLS で認証し、直接アクセスをネットワーク層でブロックする。

---

### S-03: Stripe Webhook エンドポイントの署名検証未記載

**Section**: §7.3 外部サービス連携

**Issue**:
`/api/webhooks/stripe` エンドポイントの設計に Stripe Webhook 署名（`stripe-signature` ヘッダー）の検証が明示されていない。

**Impact**: 攻撃者が偽の Stripe Webhook イベントを送信し、未払い注文を支払い済みに書き換える等の不正操作が可能になる。

**Countermeasure**: Stripe の `stripe.webhooks.constructEvent()` を使用した署名検証を設計に明示する。署名秘密は AWS Secrets Manager で管理する。

---

### S-04: ファイルアップロードの MIME 型検証不足

**Section**: §6.5 ファイルアップロード

**Issue**:
MIME 型チェックを `Content-Type` ヘッダーのみで判定する設計は、攻撃者が悪意のあるファイル（実行ファイル、HTML ファイル、SVG 等）を画像に偽装してアップロードできる。拡張子検証なし・ウイルススキャン未導入が重複リスクを形成する。

**Impact**: XSS ペイロードを含む SVG ファイルや HTML ファイルをアップロードし、CloudFront 経由で配信されることで Stored XSS が発生する可能性。パブリックバケット経由での悪意あるファイル配信。

**Countermeasure**: `Content-Type` ヘッダーに加え、ファイルのマジックバイト（バイナリシグネチャ）による MIME 型検証を実施する。許可する拡張子を明示的にホワイトリスト化する（`.jpg`, `.jpeg`, `.png`, `.webp` 等）。SVG はXSS リスクのため禁止するか厳格なサニタイズを実施する。

---

### S-05: 個人情報フィールドのフィールドレベル暗号化欠如

**Section**: §5.1 保存データの暗号化

**Issue**:
「RDS暗号化により保護されているため、フィールドレベルでの追加暗号化は不要」という判断は、DB内部からのデータアクセス（DBA権限での直接クエリ、アプリケーション層のSQLインジェクション等）に対する保護が存在しないことを意味する。RDS TDE はディスク盗難やバックアップ窃取に対する保護であり、アプリケーション層の漏洩には無効である。

**Impact**: アプリケーション層での SQL インジェクション（Prisma バイパス等）や内部不正アクセスにより、氏名・住所・電話番号等のPIIが平文で取得可能。

**Countermeasure**: 特に機密性の高いPIIフィールド（住所、電話番号）にはフィールドレベル暗号化（AES-256）を適用し、鍵管理は AWS KMS を使用する。

---

## Moderate Issues

### M-01: レート制限設計の欠如（認証エンドポイント）

**Section**: §4.4 認証エンドポイント, §6 入力検証・攻撃防御

**Issue**:
ログイン（`/api/auth/login`）、パスワードリセット、トークンリフレッシュ（`/api/auth/refresh`）エンドポイントに対するレート制限が設計書に明示されていない。

**Impact**: ブルートフォース攻撃・クレデンシャルスタッフィング攻撃・リフレッシュトークン濫用に対して無防備。

**Countermeasure**: Kong ゲートウェイまたはアプリケーション層で認証エンドポイントへのレート制限（IP単位・アカウント単位）を設計する。アカウントロックアウトポリシーを明示する。

---

### M-02: 注文詳細取得 API の所有権検証欠如

**Section**: §7.2 注文API

**Issue**:
`GET /api/orders/:id` の権限が `buyer, tenant_admin` とされているが、`buyer` ロールのユーザーが他の `buyer` の注文IDを指定してアクセスできる（IDOR: Insecure Direct Object Reference）可能性が設計書に対処されていない。

**Impact**: 他ユーザーの注文情報（住所、決済情報等）への不正アクセス。

**Countermeasure**: `buyer` による注文詳細取得時は JWT の `userId` と注文の `userId` を照合するオーナーシップ検証を設計に明示する。

---

### M-03: 署名付きURL有効期限（7日）の過長設定

**Section**: §5.4 S3ストレージセキュリティ

**Issue**:
請求書・契約書類の署名付きURLの有効期限が7日は過長である。URLが漏洩した場合（ログ記録、ブラウザ履歴、リファラーヘッダー等）に長期間アクセス可能な状態が継続する。

**Impact**: 機密書類への意図せぬ第三者アクセス。

**Countermeasure**: 有効期限を用途に応じて短縮する（閲覧用: 15-60分、ダウンロード用: 5分程度）。アクセスログを記録し異常なアクセスを検知する。

---

### M-04: PII保持期間・削除ポリシーの未定義

**Section**: §5.3 個人情報（PII）管理

**Issue**:
退会時のデータ削除フローが「今後設計する」として未定義のまま設計書に残されている。

**Impact**: 規制要件（GDPR 等）への違反リスク。ユーザーの削除権（忘れられる権利）の実現手段がない。

**Countermeasure**: 退会時のデータ削除・匿名化フローを設計フェーズで確定させる。保持期間ポリシーを法的要件と照合して明示する。

---

### M-05: 監査ログの分離不足

**Section**: §8.4 監査ログ

**Issue**:
セキュリティイベント（認証失敗、ロール変更）を「アプリケーションの通常ログと同一の CloudWatch Logs ストリームに出力する」設計は、監査ログの改ざん・汚染・削除リスクを高める。通常ログは開発者が広くアクセスできるのに対し、監査ログはより制限されたアクセス制御が必要である。

**Impact**: 内部不正や侵害調査時に監査ログの信頼性が損なわれる可能性。コンプライアンス要件の違反。

**Countermeasure**: セキュリティ監査ログを専用ストリームまたは書き込み専用ログサービス（CloudWatch Logs with Write-Only IAM Policy、または AWS CloudTrail）に分離する。

---

## Minor Issues / Positive Aspects

### Positive Aspects

- Prisma ORM のパラメータ化クエリによる SQL インジェクション対策が設計に明示されている
- bcrypt（cost factor: 12）によるパスワードハッシュ化は適切
- リフレッシュトークンのサーバーサイドブラックリスト（Redis）は適切な設計
- CSP（`default-src 'self'`）と DOMPurify の組み合わせによるXSS多層防御
- クレジットカード情報の Stripe 委譲によるスコープ外化
- AWS Secrets Manager によるシークレット管理基盤（`config/secrets.prod.yaml` の問題を除く）
- ECS プライベートサブネット配置と Security Group 最小権限設計

### Minor: multer@1.4.4 の既知脆弱性確認要

**Section**: §8.2 依存ライブラリ管理

`multer@1.4.4` は既知の脆弱性が報告されているバージョンである。Presigned URL 経由のクライアント直接アップロード設計ではサーバー側 multer の使用範囲が限定されるが、使用箇所を特定し最新版への更新を検討すること。

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 5 |
| Significant | 5 |
| Moderate | 5 |
| Minor | 1 |

**最優先対応**: C-01（CORS バイパス）、C-03（本番シークレットのリポジトリ保存）、C-02（localStorage トークン保存）の順で対処することを推奨する。特に C-01 は `Access-Control-Allow-Credentials: true` との組み合わせにより、認証済みユーザーへの直接的な攻撃経路を形成している。
