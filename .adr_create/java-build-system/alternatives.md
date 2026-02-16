# 代替案一覧

## 採用候補

### ALT-1: Gradle (Kotlin DSL)
- 概要: Kotlin DSL によるタイプセーフなビルド定義。Build Cache、Configuration Cache、Convention Plugins 等の機能を活用し、パフォーマンスと拡張性を両立する
- 提案元: OBJ-1（保守性：型安全性とIDEサポート）、OBJ-2（パフォーマンス：Build Cache/Configuration Cache）、OBJ-3（統合性：Spring Boot公式サポート）、OBJ-4（拡張性：プログラマティックなビルドロジック）、OBJ-5（標準化：Convention Plugins）

### ALT-2: Maven
- 概要: XML ベースの宣言的ビルド定義。Convention over Configuration の徹底と成熟したエコシステムにより、標準化と保守性を重視する
- 提案元: OBJ-1（保守性：可読性とドキュメント充実）、OBJ-3（統合性：Spring Boot公式第一サポート）、OBJ-5（標準化：業界標準としての実績）

### ALT-3: Gradle (Groovy DSL)
- 概要: Groovy DSL による柔軟なビルド定義。Gradle の伝統的な記述方式で、参考資料が豊富。動的型付けによる簡潔な記述が特徴
- 提案元: OBJ-1（保守性：簡潔な記述）、OBJ-4（拡張性：柔軟なスクリプティング）

## 除外した代替案
- Bazel: 除外理由 — 学習コストが極めて高く（D1関連）、Spring Boot 3.x の公式プラグインが存在しない（C4制約）。モノレポ・超大規模プロジェクト向けであり、今回のスコープに合致しない
- Buck2: 除外理由 — エコシステムが未成熟で長期サポートが不透明（C3制約）。Spring Boot 3.x の統合が存在しない（C4制約）
- Ant + Ivy: 除外理由 — Spring Boot 3.x の公式統合が存在しない（C4制約）。エコシステムが縮小傾向にあり長期運用に不適（C3制約）
