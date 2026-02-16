# 採点結果: v002-variant-priority-balance

## スコアサマリ
Mean=9.5, SD=0.5
Run1=10.0(検出9.5+bonus1-penalty0), Run2=9.0(検出8.5+bonus1-penalty0), Run3=9.5(検出9.5+bonus0-penalty0)

## 検出マトリクス
| ID | カテゴリ | 深刻度 | Run1 | Run2 | Run3 |
|----|---------|--------|------|------|------|
| P01 | 認証・認可設計 | 重大 | ○ | ○ | ○ |
| P02 | 入力検証・攻撃防御 | 中 | × | × | × |
| P03 | 入力検証・攻撃防御 | 中 | ○ | ○ | ○ |
| P04 | 入力検証・攻撃防御 | 中 | ○ | ○ | ○ |
| P05 | 脅威モデリング(Information Disclosure) | 中 | ○ | ○ | ○ |
| P06 | データ保護 | 重大 | ○ | ○ | ○ |
| P07 | データ保護 | 中 | ○ | ○ | ○ |
| P08 | データ保護 | 軽微 | ○ | △ | △ |
| P09 | データ保護 | 重大 | ○ | ○ | ○ |
| P10 | 脅威モデリング(Repudiation), インフラ・依存関係・監査 | 中 | ○ | ○ | ○ |
| P11 | 認証・認可設計 | 重大 | ○ | ○ | ○ |
| P12 | インフラ・依存関係・監査 | 中 | ○ | △ | ○ |
| P13 | インフラ・依存関係・監査 | 軽微 | ○ | ○ | ○ |
| P14 | 脅威モデリング(Tampering) | 軽微 | × | × | × |
| P15 | 入力検証・攻撃防御 | 軽微 | △ | △ | △ |

## ボーナス・ペナルティ詳細

### Run1
- Bonus: B06 (JWTトークン失効メカニズムの欠如), B02 (リソース枯渇攻撃への対策不足 - セッションタイムアウト設計の形で言及)
- Penalty: なし

### Run2
- Bonus: B06 (JWTトークン失効メカニズムの欠如), B01 (JWTペイロードへの機密データ格納リスク - 間接的にJWT署名アルゴリズム設計の議論で言及)
- Penalty: なし

### Run3
- Bonus: なし
- Penalty: なし

## エラー分析（抽象的）

### Missed/Partial by Category
| Category | Problems | ○ | △ | × | Stability | Prompt Gap |
|----------|----------|---|---|---|-----------|------------|
| 認証・認可設計 | 2 | 2 | 0 | 0 | 高 | なし（完全検出） |
| 入力検証・攻撃防御 | 5 | 3 | 1 | 1 | 高 | CSRF対策の明示的検出が欠如 |
| データ保護 | 4 | 3 | 0.67 | 0 | 中 | 内部通信暗号化の検出にばらつき（Run1: 完全検出, Run2/3: 部分検出） |
| 脅威モデリング(Information Disclosure) | 1 | 1 | 0 | 0 | 高 | なし（完全検出） |
| 脅威モデリング(Repudiation) | 1 | 1 | 0 | 0 | 高 | なし（完全検出） |
| 脅威モデリング(Tampering) | 1 | 0 | 0 | 1 | 高 | データ完全性検証の検出指示が欠如 |
| インフラ・依存関係・監査 | 3 | 2.67 | 0.33 | 0 | 中 | シークレット管理のローテーション・KMS連携の検出が不安定 |

### Improvement Directions

#### 入力検証・攻撃防御カテゴリ（P02: CSRF対策）
- **Prompt Gap**: 評価基準4（Input Validation & Attack Defense）でCSRF保護の設計確認を指示しているが、3回とも未検出。プロンプト内でCSRF対策を**明示的な必須チェック項目**として強調する必要がある。
- **現状**: 「CORS/origin control, and CSRF protection are designed」とあるが、CORS設定は全回検出（P03）したのに対し、CSRF対策は検出されていない。
- **改善方向**: CSRF対策を独立したチェックポイントとして分離し、「state-changing operations（POST/PUT/DELETE）にCSRF保護が設計されているか」を評価基準4の冒頭に明記する。CORSとCSRFは異なる攻撃防御であることを明示。

#### データ保護カテゴリ（P08: 内部通信暗号化）
- **Prompt Gap**: 評価基準3（Data Protection）で「encryption at rest and in transit, **including internal communication**」と明記しているが、Run2/Run3で部分検出にとどまった。
- **現状**: Run1は「バックエンド内部通信の暗号化欠如」を明示的に検出したが、Run2は「内部通信もTLSで暗号化する設計を明記」と一般的に言及、Run3も「バックエンド-DB間、マイクロサービス間」と一般的な記述にとどまり、設計書のギャップ（API Gateway-バックエンド、バックエンド-DB）を完全に特定していない。
- **改善方向**: 「内部通信暗号化の検証では、設計書に記載された外部通信暗号化と、未記載の内部通信（バックエンド↔DB、マイクロサービス間等）を区別し、後者の欠如を明示的に指摘すること」を評価基準3に追記する。

#### 脅威モデリング(Tampering)カテゴリ（P14: データ完全性検証）
- **Prompt Gap**: 評価基準1（Threat Modeling - STRIDE）で「Tampering (data integrity verification)」を評価項目に挙げているが、3回とも未検出。
- **現状**: プロンプトは「Complete STRIDE Assessment: For each of the six STRIDE categories, explicitly determine whether the design document addresses the threat」と指示しているが、Tamperingカテゴリへの注意喚起が不足している。Run2/Run3でM3「データ改ざん検知メカニズム」として検出しているが、正解キーの「診察記録等の重要データに対する改ざん検知メカニズム（ハッシュ、デジタル署名、監査証跡等）の設計が記載されていない」という具体的な欠如を指摘していない。
- **改善方向**: STRIDE-Tの評価では「重要データ（医療記録、財務情報等）に対する改ざん検知メカニズム（ハッシュ、デジタル署名、監査証跡等）の設計の有無を確認する」ことを評価基準1に明記する。

#### インフラ・依存関係・監査カテゴリ（P12: シークレット管理）
- **Prompt Gap**: 評価基準5（Infrastructure, Dependencies & Audit）で「secret management covers key lifecycle (generation, rotation, revocation, access control)」と指示しているが、Run2で部分検出となった。
- **現状**: Run1/Run3は「ローテーション、KMS連携、アクセス制御の欠如」を明示的に指摘したが、Run2は「Secret rotation policies」等と一般的に記述し、正解キーの「Parameter Storeから取得するとあるが、ローテーション、アクセス制御、暗号化（KMS連携等）の設計が記載されていない」という具体的なギャップを完全に捉えていない。
- **改善方向**: 「シークレット管理の評価では、設計書に記載された取得方法（Parameter Store等）に加え、未記載のライフサイクル要素（ローテーション、KMS連携、アクセス制御、失効プロセス）を個別に確認し、欠如している要素を明示的にリストアップすること」を評価基準5に追記する。

#### 入力検証・攻撃防御カテゴリ（P15: XSS/ファイルアップロード検証）
- **Prompt Gap**: 評価基準4でXSS対策とファイルアップロード検証を含むが、3回とも部分検出（△）にとどまった。
- **現状**: Run1はXSS対策を詳細に指摘しているが、正解キーの「ファイルアップロード検証（拡張子・MIMEタイプ・サイズ制限）の欠如」を明示的に指摘していない。Run2/Run3も同様。
- **改善方向**: 「入力検証方針の評価では、XSS対策（出力エスケーピング）、コマンドインジェクション対策、ファイルアップロード検証を**個別のチェックポイント**として確認すること」を評価基準4に明記する。

### Strengths to Preserve

#### 認証・認可設計カテゴリ（P01, P11）
- **有効なプロンプト要素**: 「API Endpoint Authorization Checklist」が高い効果を発揮。
  - P01（JWT localStorage保存）: 3回とも完全検出
  - P11（API認可チェック詳細の欠如）: 3回とも完全検出
- **評価**: プロンプト内の「Resource access endpoints: Check that ownership/membership verification is specified」が、正解キーの「エンドポイントごとの認可チェック（必要ロール、リソース所有権チェック等）の詳細が不足」という指摘を確実に引き出している。

#### データ保護カテゴリ（P06, P07, P09）
- **有効なプロンプト要素**: 「Data Protection Coverage: Assess both encryption measures (at rest and in transit, including internal communication) and data governance policies (classification, retention, deletion)」が効果的。
  - P06（ログへの機密データ出力）: 3回とも完全検出
  - P07（データ分類・保持期間方針）: 3回とも完全検出
  - P09（保存時データ暗号化）: 3回とも完全検出
- **評価**: 暗号化とデータガバナンスを**両方評価する**という明示的な指示が、設計書の欠如を包括的に検出させている。

#### 入力検証・攻撃防御カテゴリ（P03, P04）
- **有効なプロンプト要素**: 「Attack Surface Coverage: Systematically check for validation and defense mechanisms across all attack vectors. Absence of CORS configuration, rate limiting on authentication endpoints, or other defensive measures constitutes a security gap.」が効果的。
  - P03（CORS設定の未定義）: 3回とも完全検出
  - P04（認証エンドポイントのレート制限）: 3回とも完全検出
- **評価**: CORS設定と認証エンドポイントのレート制限を**具体例として明記**したことが、確実な検出につながっている。

#### インフラ・依存関係・監査カテゴリ（P10, P13）
- **有効なプロンプト要素**: 「Distinguish between general application logging and security audit logging」（P10）と「vulnerability management policies for third-party libraries」（P13）の明示的な指示が効果的。
  - P10（セキュリティ監査ログ）: 3回とも完全検出
  - P13（依存ライブラリの脆弱性管理）: 3回とも完全検出
- **評価**: 一般的なロギングとセキュリティ監査ログの**区別を明示**したことが、正解キーの「一般的なアプリケーションログはあるが、セキュリティ監査ログの設計が記載されていない」という指摘を確実に引き出している。

#### 脅威モデリングカテゴリ（P05, P10）
- **有効なプロンプト要素**: 「Complete STRIDE Assessment: For each of the six STRIDE categories, explicitly determine whether the design document addresses the threat」が、STRIDE-I（Information Disclosure）とSTRIDE-R（Repudiation）の検出に効果を発揮。
  - P05（エラーメッセージの情報露出）: 3回とも完全検出（STRIDE-I）
  - P10（セキュリティ監査ログ）: 3回とも完全検出（STRIDE-R）
- **評価**: STRIDE 6カテゴリの網羅的評価を明示したことが効果的。ただし、STRIDE-T（Tampering）は未検出であり、改善余地がある。
