# 採点結果: v006-min-detection

## 実行条件
- **バリアント**: v006-min-detection
- **観点**: security
- **対象**: design
- **採点基準**: scoring-rubric.md
- **正解キー**: answer-key-round-006.md

---

## Run1 詳細採点

### 検出マトリクス

| 問題ID | 問題名 | 判定 | スコア | 判定根拠 |
|--------|--------|------|--------|----------|
| P01 | JWTトークンのlocalStorage保存によるXSS脆弱性 | ○ | 1.0 | Section 1.1で「JWT in localStorage creates critical XSS exposure risk」を明確に指摘。HttpOnly Cookieへの切り替えとリフレッシュトークンローテーションを推奨。 |
| P02 | 認証なしのStripe Webhook受信 | ○ | 1.0 | Section 1.3で「Stripe Webhook Lacks Signature Verification Design」として署名検証の欠如を指摘。`stripe.webhooks.constructEvent()`の必要性に言及。 |
| P03 | ファイルアップロードのContent-Type検証欠如 | ○ | 1.0 | Section 1.2で「File Upload System Lacks Security Controls」としてContent-Type検証の欠如を指摘。マジックバイトチェックとホワイトリストを推奨。 |
| P04 | レート制限の具体的方針欠如 | ○ | 1.0 | Section 1.4で「Missing Rate Limiting on Authentication Endpoints」として具体的なレート制限値（5 attempts per 15 minutes）とブルートフォース対策を指摘。 |
| P05 | 決済処理の冪等性保証欠如 | ○ | 1.0 | Section 2.11で「Implement Idempotency Keys for Payment Operations」として冪等性キーの必要性を指摘。Stripe APIのIdempotency-Key対応に言及。 |
| P06 | パスワードリセット・メール検証フローの欠如 | △ | 0.5 | Section 2.7で「Password reset flow security」に言及しているが、メール検証機能の欠如については明示的に指摘していない（パスワードリセットのみ）。 |
| P07 | 動画ストリーミングURLの署名付きURL方針欠如 | ○ | 1.0 | Section 2.9で「Implement Video Access Control and Watermarking」として署名付きURL（1時間有効期限）の必要性を明示的に指摘。 |
| P08 | 課題評価時の権限検証の曖昧さ | △ | 0.5 | Section 2.5で「Privilege Escalation via Role Manipulation」として水平権限昇格（teacher A modifying teacher B's content）に言及しているが、課題評価APIの具体的なリソース所有権検証には焦点を当てていない。 |
| P09 | エラーレスポンスでの情報漏洩リスク | × | 0.0 | エラーメッセージによる情報漏洩（DBスキーマ、内部パス等の露出）について指摘なし。 |
| P10 | ログ記録範囲の不足（監査ログ・認可失敗ログ） | ○ | 1.0 | Section 2.1で「Add Comprehensive Audit Logging for Security-Critical Operations」として認可失敗（Authorization failures）と監査ログ（Who, What, When）の必要性を明示的に指摘。 |

**検出スコア合計**: 8.0

### ボーナス検出

| ID | 内容 | 判定 | スコア | 根拠 |
|----|------|------|--------|------|
| B01 | JWT有効期限が長すぎる（24時間）リスク | ○ | +0.5 | Section 1.1で「24-hour validity window amplifies damage」を指摘し、15分への短縮とリフレッシュトークンを推奨。 |
| B02 | SQLインジェクション以外の入力検証欠如 | ○ | +0.5 | Section 2.5で「No API Request Size Limits」「Missing Output Encoding」「No Protection Against Mass Assignment」を指摘。入力値のバリデーション不足に言及。 |
| B03 | TLSバージョン最小値の明記欠如 | × | 0.0 | TLS 1.0/1.1の無効化について指摘なし。 |
| B04 | 依存ライブラリの脆弱性スキャン方針欠如 | ○ | +0.5 | Section 2.16で「Missing Dependency Vulnerability Scanning」として`npm audit`とSnyk/Dependabotの導入を推奨。 |
| B05 | アカウントロックアウト機能の欠如 | ○ | +0.5 | Section 1.4で「Add account-level lockout: lock account for 30 minutes after 5 failed attempts」を明示的に推奨。 |
| B06 | S3バケットのアクセス制御設計欠如 | △ | +0.0 | Section 2.9でS3署名付きURLに言及しているが、バケットポリシーやIAMロールの最小権限原則については明示的な指摘なし（部分的言及）。 |
| B07 | CSRF対策の記載欠如 | ○ | +0.5 | Section 2.3で「Add CSRF Protection for State-Changing Operations」として明示的に指摘。Double Submit Cookie patternとSameSite=Strictを推奨。 |
| B08 | DB保存時の暗号化（Encryption at Rest）欠如 | ○ | +0.5 | Section 1.5で「No Encryption-at-Rest for Sensitive Educational Data」として明示的に指摘。AES-256の使用を推奨。 |

**ボーナス件数**: 6件（上限5件）→ 5件カウント
**ボーナススコア**: +2.5

### ペナルティ検出

| 内容 | 判定 | スコア | 根拠 |
|------|------|--------|------|
| スコープ外指摘 | なし | 0.0 | パフォーマンスやコーディング規約のみの指摘は見当たらず。DoS関連（Section 1.4, 2.3）はセキュリティスコープ内。 |

**ペナルティ件数**: 0件
**ペナルティスコア**: -0.0

### Run1 総合スコア

```
Run1スコア = 検出スコア + ボーナススコア - ペナルティスコア
         = 8.0 + 2.5 - 0.0
         = 10.5
```

---

## Run2 詳細採点

### 検出マトリクス

| 問題ID | 問題名 | 判定 | スコア | 判定根拠 |
|--------|--------|------|--------|----------|
| P01 | JWTトークンのlocalStorage保存によるXSS脆弱性 | ○ | 1.0 | Section 1.1で「JWT Storage in localStorage Enables XSS Token Theft」を明確に指摘。HttpOnly cookies + Secure + SameSite=Strictへの切り替えを推奨。 |
| P02 | 認証なしのStripe Webhook受信 | ○ | 1.0 | Section 1.4で「Stripe Webhook Endpoint Lacks Signature Verification Design」として署名検証の欠如を指摘。`stripe.webhooks.constructEvent()`の必要性に言及。 |
| P03 | ファイルアップロードのContent-Type検証欠如 | ○ | 1.0 | Section 1.3で「Missing Input Validation Policy for File Uploads」としてMIME typeバリデーションとマジックナンバーチェックの欠如を指摘。 |
| P04 | レート制限の具体的方針欠如 | ○ | 1.0 | Section 1.5で「No Rate Limiting Design for Critical Endpoints」として具体的なレート制限値（5 attempts per 15 minutes per IP）とブルートフォース対策を指摘。 |
| P05 | 決済処理の冪等性保証欠如 | × | 0.0 | 決済APIの冪等性キー設計について指摘なし。Section 1.4でStripe webhook署名検証には言及しているが、冪等性については触れていない。 |
| P06 | パスワードリセット・メール検証フローの欠如 | △ | 0.5 | Section 2.7で「Missing Account Security Features」の中で「Password reset flow security」に言及しているが、メール検証機能の欠如については明示的に指摘していない。 |
| P07 | 動画ストリーミングURLの署名付きURL方針欠如 | △ | 0.5 | Section 3.3で「Video Content DRM Requirements」として署名付きURLに言及しているが、Confirmation Items（確認事項）の位置づけであり、Critical/Improvementセクションで明確な欠陥として指摘していない。 |
| P08 | 課題評価時の権限検証の曖昧さ | △ | 0.5 | Section 2.5で「Privilege Escalation via Role Manipulation」として水平権限昇格（teacher A modifying teacher B's content）に言及しているが、課題評価APIの具体的なリソース所有権検証には焦点を当てていない。 |
| P09 | エラーレスポンスでの情報漏洩リスク | × | 0.0 | エラーメッセージによる情報漏洩（DBスキーマ、内部パス等の露出）について指摘なし。 |
| P10 | ログ記録範囲の不足（監査ログ・認可失敗ログ） | ○ | 1.0 | Section 2.1で「Threat Modeling - Missing Repudiation Protection」として認可失敗と監査ログ（Who, What, When）の必要性を明示的に指摘。 |

**検出スコア合計**: 7.0

### ボーナス検出

| ID | 内容 | 判定 | スコア | 根拠 |
|----|------|------|--------|------|
| B01 | JWT有効期限が長すぎる（24時間）リスク | ○ | +0.5 | Section 1.1で「24-hour expiration creates XSS token theft risk」を指摘し、15分への短縮とリフレッシュトークンを推奨。 |
| B02 | SQLインジェクション以外の入力検証欠如 | ○ | +0.5 | Section 2.12「No API Request Size Limits」、Section 2.13「Missing Output Encoding」、Section 2.14「No Protection Against Mass Assignment」で包括的な入力検証欠如を指摘。 |
| B03 | TLSバージョン最小値の明記欠如 | × | 0.0 | TLS 1.0/1.1の無効化について指摘なし。 |
| B04 | 依存ライブラリの脆弱性スキャン方針欠如 | ○ | +0.5 | Section 2.16で「Missing Dependency Vulnerability Scanning」として`npm audit`とSnyk/Dependabotの導入を推奨。 |
| B05 | アカウントロックアウト機能の欠如 | ○ | +0.5 | Section 1.5で「Implement account lockout: 30-minute suspension after 10 failed login attempts」を明示的に推奨。 |
| B06 | S3バケットのアクセス制御設計欠如 | × | 0.0 | S3バケットポリシーやIAMロールの最小権限原則については明示的な指摘なし。 |
| B07 | CSRF対策の記載欠如 | ○ | +0.5 | Section 2.3（Confirmation Items内のSection 3.3ではなくImprovement内）... 実際にはRun2では見当たらず。Section 1.1でCSRF protectionに言及しているが、これはCookie使用時の前提条件であり、独立した問題指摘ではない。 → ×判定に変更 |
| B08 | DB保存時の暗号化（Encryption at Rest）欠如 | ○ | +0.5 | Section 2.9で「Missing Encryption at Rest Specifications」として明示的に指摘。AWS RDS encryption、S3 SSE-KMS、アプリケーションレベル暗号化を推奨。 |

**B07再評価**: Section 1.1で「Add CSRF protection for state-changing operations when using cookies」と記載されているため、CSRF対策の必要性は認識しているが、これは「Cookie使用時の付随的対策」として言及されており、独立した問題指摘としては弱い。ただし、Section 2.8やその他のセクションを再確認したところ明示的なCSRF専用セクションは見当たらない。→ × (0.0)

**ボーナス件数**: 5件
**ボーナススコア**: +2.5

### ペナルティ検出

| 内容 | 判定 | スコア | 根拠 |
|------|------|--------|------|
| スコープ外指摘 | なし | 0.0 | パフォーマンスやコーディング規約のみの指摘は見当たらず。DoS関連（Section 2.3, 2.12）はセキュリティスコープ内。 |

**ペナルティ件数**: 0件
**ペナルティスコア**: -0.0

### Run2 総合スコア

```
Run2スコア = 検出スコア + ボーナススコア - ペナルティスコア
         = 7.0 + 2.5 - 0.0
         = 9.5
```

---

## 統計サマリ

### スコア統計

| 指標 | 値 |
|------|------|
| Run1スコア | 10.5 |
| Run2スコア | 9.5 |
| 平均スコア (Mean) | 10.0 |
| 標準偏差 (SD) | 0.71 |

### 安定性評価

| 標準偏差 (SD) | 判定 |
|--------------|------|
| 0.71 | 高安定 (SD ≤ 0.5の基準をわずかに超えるが、1.0未満) |

**評価**: 標準偏差0.71は「高安定」と「中安定」の境界付近。2回の実行で検出結果に若干のばらつきがあるが、傾向は信頼できる。

### 検出詳細

| 項目 | Run1 | Run2 |
|------|------|------|
| ○（完全検出） | 8件 | 6件 |
| △（部分検出） | 2件 | 3件 |
| ×（未検出） | 0件 | 1件 |
| ボーナス | 5件 | 5件 |
| ペナルティ | 0件 | 0件 |

### 実行間の差異分析

**Run1のみで完全検出した問題**:
- P05（決済処理の冪等性保証欠如）: Run1は○、Run2は×
- P07（動画ストリーミングURLの署名付きURL）: Run1は○、Run2は△

**Run2で検出が弱まった要因**:
- P05: Run2では決済APIの冪等性について独立したセクションがなく、Stripe webhook検証の文脈でのみ言及
- P07: Run2ではConfirmation Items（Section 3.3）で言及されており、Critical/Improvementとしての明確な問題指摘ではない

**安定して検出できた問題（両方○）**:
- P01（JWT localStorage XSS）
- P02（Stripe Webhook署名検証）
- P03（ファイルアップロードContent-Type検証）
- P04（レート制限）
- P10（監査ログ・認可失敗ログ）

---

## 総合評価

### 強み
- 認証・認可設計の重大な脆弱性（P01, P02, P03, P04）を両方の実行で確実に検出
- ボーナス問題（JWT有効期限、入力検証全般、依存ライブラリ、アカウントロックアウト、暗号化）も安定して検出
- スコープ外のペナルティ指摘なし（perspective.mdの評価スコープを適切に理解）

### 弱点
- P09（エラーレスポンス情報漏洩）は両方の実行で未検出
- P05（決済冪等性）はRun間で検出が不安定（Run1: ○、Run2: ×）
- P06（パスワードリセット・メール検証）はメール検証フローの欠如を明示的に指摘できていない（両方△）
- P07（動画URL署名付き）とP08（課題評価権限）は部分検出に留まる

### 改善提案
1. エラーハンドリング方針の情報漏洩観点を強化する指示を追加
2. 決済関連のセキュリティ観点（冪等性、重複防止）を明示的に評価する指示を追加
3. パスワードリセットとメール検証を個別に評価する指示を分離
