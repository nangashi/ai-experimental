# Scoring Report: severity-first

## Detection Matrix

| Problem | Run1 | Run2 | Notes |
|---------|------|------|-------|
| P01: JWTトークンのlocalStorage保存によるXSS脆弱性 | ○ | ○ | Run1: 指摘1で「localStorage へのトークン保存は XSS 攻撃によるトークン窃取を許し」と明記、HTTPOnly Cookie への変更を推奨。Run2: 指摘1で同様の指摘 + cookie with HttpOnly/Secure/SameSite=Strict への変更を推奨 |
| P02: プロジェクト削除APIにおける権限チェックの曖昧性 | ○ | △ | Run1: 指摘5で「プロジェクト削除などの重要操作における認可ルールが不明確」と明記、リソースレベルでの所有権検証を推奨。Run2: 指摘3で包括的な入力検証に言及しているが削除API固有の権限チェックには触れていない。ただし指摘19のRBAC foundation言及は一般的 |
| P03: ファイルアップロードにおけるファイル種別検証の欠如 | ○ | ○ | Run1: 指摘4で「MIME タイプ検証、ファイル拡張子ホワイトリスト、マルウェアスキャンが設計されていない」と明記。Run2: 指摘7で同様の指摘 + file-type library による magic byte inspection を推奨 |
| P04: S3バケットのアクセス制御方針が不明確 | △ | ○ | Run1: 指摘7で「保存データ（at rest）の暗号化」全般に言及しているが S3 固有のアクセス制御（署名付きURL）には触れていない。Run2: 指摘7で「Use pre-signed URLs with 1-hour expiration for downloads」「Block public access completely」と明記 |
| P05: レート制限の具体的な設計が欠如 | ○ | ○ | Run1: 指摘2で「express-rate-limit を使用し、/api/v1/auth/login を IP あたり 5 回/15分」など具体的なレート値を明記。Run2: 指摘4で同様の具体的なレート制限設計を提案 |
| P06: パスワードリセット機能の設計が存在しない | × | × | Run1/Run2 ともにパスワードリセット機能の欠如を指摘していない |
| P07: 機密データの暗号化範囲が限定的 | ○ | ○ | Run1: 指摘7で「PostgreSQL の透過的データ暗号化（TDE）を有効化、S3 バケットは SSE-S3 または SSE-KMS で暗号化」と保存時暗号化を明記。Run2: 指摘9で同様の encryption at rest 対策を提案 |
| P08: 外部サービス連携におけるOAuth2.0のスコープ管理方針が不明確 | ○ | △ | Run1: 指摘8で「スコープ最小化: Slack は `chat:write`、GitHub は `repo:status` など必要最小限のスコープのみ要求」と明記。Run2: 指摘14で webhook security に言及しているが OAuth スコープ管理には触れていない |
| P09: 監査ログ（Audit Log）の設計が欠如 | ○ | ○ | Run1: 指摘6で「監査ログ設計が欠落」と明記、記録対象イベント（ログイン、ロール変更、プロジェクト削除等）を列挙。Run2: 指摘5で同様の audit logging の欠如と security event tracking の必要性を指摘 |

## Bonus/Penalty Analysis

### Run1 Bonus
| ID | Category | Justification | Score |
|----|----------|---------------|-------|
| B01 | 多要素認証（MFA）の欠如 | 指摘には MFA の明示的推奨がないため、ボーナス対象外 | 0 |
| B02 | アカウントロックアウト機能の欠如 | 指摘2で「5回の失敗後は30分間のアカウントロック」を推奨しており、ボーナス対象 | +0.5 |
| B03 | シークレット管理方針が不明確 | 指摘12で「AWS Secrets Manager を使用してDB接続情報、外部APIキー、暗号化キーを管理」と明記しており、ボーナス対象 | +0.5 |
| B04 | CSRF対策の欠如 | 指摘3で「csurf ミドルウェアを導入し、Double Submit Cookie パターンを実装」と明記しており、ボーナス対象 | +0.5 |
| B05 | バリデーションエラー詳細の情報漏洩リスク | 指摘11で「エラーレスポンスに含める情報の制限」と情報漏洩リスクを指摘しており、ボーナス対象 | +0.5 |

**Run1 Bonus Total**: 4件 × 0.5 = +2.0

### Run2 Bonus
| ID | Category | Justification | Score |
|----|----------|---------------|-------|
| B01 | 多要素認証（MFA）の欠如 | 指摘15で「mandatory MFA for admin roles」を推奨しており、ボーナス対象 | +0.5 |
| B02 | アカウントロックアウト機能の欠如 | 指摘4で「Implement account lockout: Disable account for 30 minutes after 5 failed login attempts」を推奨しており、ボーナス対象 | +0.5 |
| B03 | シークレット管理方針が不明確 | 指摘6で「Use AWS Secrets Manager or AWS Systems Manager Parameter Store」と明記しており、ボーナス対象 | +0.5 |
| B04 | CSRF対策の欠如 | 指摘2で「Implement Double Submit Cookie pattern」と明記しており、ボーナス対象 | +0.5 |
| B05 | バリデーションエラー詳細の情報漏洩リスク | 指摘12で「Define error exposure policy」と情報漏洩防止策を明記しており、ボーナス対象 | +0.5 |

**Run2 Bonus Total**: 5件 × 0.5 = +2.5

### Run1 Penalty
| Issue | Justification | Score |
|-------|---------------|-------|
| 指摘10「セッション管理設計が不明確」 | セッションタイムアウト・並行セッション制限はセキュリティスコープ内の正当な指摘であり、ペナルティ対象外 | 0 |
| 指摘15「APIのバージョニング戦略が不完全」 | 「セキュリティ強化を行う際に既存クライアントを破壊せずに移行する仕組み」はセキュリティ設計の一部であり、ペナルティ対象外 | 0 |

**Run1 Penalty Total**: 0件 × 0.5 = 0

### Run2 Penalty
| Issue | Justification | Score |
|-------|---------------|-------|
| 指摘11「Missing session management security」 | セッション管理はセキュリティスコープ内の正当な指摘であり、ペナルティ対象外 | 0 |
| 指摘13「Missing dependency security management」 | 依存ライブラリの脆弱性管理はセキュリティスコープ内（「インフラ・依存関係のセキュリティ」）であり、ペナルティ対象外 | 0 |

**Run2 Penalty Total**: 0件 × 0.5 = 0

## Score Calculation

### Run1
- P01 (○): 1.0
- P02 (○): 1.0
- P03 (○): 1.0
- P04 (△): 0.5
- P05 (○): 1.0
- P06 (×): 0.0
- P07 (○): 1.0
- P08 (○): 1.0
- P09 (○): 1.0

**Detection Score**: 7.5
**Bonus**: +2.0
**Penalty**: 0
**Run1 Total**: 7.5 + 2.0 - 0 = **9.5**

### Run2
- P01 (○): 1.0
- P02 (△): 0.5
- P03 (○): 1.0
- P04 (○): 1.0
- P05 (○): 1.0
- P06 (×): 0.0
- P07 (○): 1.0
- P08 (△): 0.5
- P09 (○): 1.0

**Detection Score**: 7.0
**Bonus**: +2.5
**Penalty**: 0
**Run1 Total**: 7.0 + 2.5 - 0 = **9.5**

### Summary
- **Mean**: (9.5 + 9.5) / 2 = **9.5**
- **SD**: 0.0
