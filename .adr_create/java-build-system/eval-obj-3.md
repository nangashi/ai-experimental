# OBJ-3: エコシステムとの統合性 — 評価結果

## 提案した代替案

この目的を最適化する観点から、以下の代替案を提案する。

- **Maven**: Spring Boot 3.x の公式ドキュメント・スターターが最優先でサポートするツールであり、Java 21 との統合も標準的。エコシステムが成熟しており、必要なプラグインはほぼ全て利用可能。
- **Gradle**: Spring Boot 3.x の公式サポートが強く、Groovy/Kotlin DSL により Spring Boot プラグインとの統合が簡潔。Java 21 の全機能をサポートし、IDE（IntelliJ IDEA、Eclipse）およびCI/CDツールとの統合が成熟している。
- **Maven Wrapper / Gradle Wrapper**: ビルドツール本体ではなく実行環境の標準化手段だが、エコシステム統合の文脈で重要。プロジェクト固有のビルドツールバージョンを保証し、CI/CD環境との整合性を確保する。

## 評価

### Maven

- 評価: ○
- 利点:
  - Spring Boot 3.x の公式ドキュメントおよびスターターは Maven を第一にサポート。pom.xml の標準的な構成例が豊富に提供されている
  - Java 21 のサポートは確立しており、Maven 3.9.12（安定版）で問題なく動作する。Maven 4 では Java 17 を実行環境として必須とするが、ビルド対象のソースコードは引き続き Java 21 を含む全てのバージョンをサポート可能
  - エコシステムが成熟しており、必要なプラグイン（surefire, failsafe, jacoco, checkstyle, spotbugs 等）は全て利用可能で安定している
  - IDE（IntelliJ IDEA、Eclipse、VS Code）は Maven プロジェクトを標準サポートし、自動的にプロジェクト構造を認識する
  - CI/CDツール（GitHub Actions、GitLab CI、Jenkins）は Maven を標準的にサポートし、キャッシュ戦略も確立している
- 欠点:
  - Maven 4 への移行時にプラグインの互換性問題が発生する可能性がある（research.md の知見: 一部プラグインを最新バージョンにアップグレードする必要あり）
  - カスタムプラグインの開発が Gradle と比較して煩雑である（Groovy/Kotlin DSL ではなく Java でのプラグイン開発が必要）
- 根拠:
  - Spring Boot 公式ドキュメントは Maven と Gradle の両方を扱うが、多くのガイドおよびスターター生成（Spring Initializr）では Maven がデフォルト選択肢として提示される
  - Maven Central Repository は事実上の標準リポジトリであり、依存関係の解決においてエコシステムの中心的存在
  - research.md の知見: Maven 3.9.12 が全ユーザーに推奨される安定版であり、2026年時点で広く使用されている
- CSD依存: なし（既存決定 ADR-0001 で Java 21 が確定しており、Maven の Java 21 サポートは確実）

### Gradle

- 評価: ◎
- 利点:
  - Spring Boot 3.x の公式サポートが強い。Spring Boot Gradle Plugin は活発に開発されており、DSL を使った簡潔な設定が可能（`plugins { id 'org.springframework.boot' version '3.x.x' }` 形式）
  - Java 21 の全機能を完全サポート。Gradle 9.3.1（最新版）は Java 21 と完全に互換性がある
  - 必要なプラグインは Maven と同等に利用可能（JUnit 5、JaCoCo、Checkstyle、SpotBugs 等）であり、Gradle Plugin Portal を通じて最新版を取得できる
  - IDE 統合が成熟している。IntelliJ IDEA は Gradle をネイティブサポートし、Kotlin DSL の補完・リファクタリングも提供。Eclipse（Buildship プラグイン）および VS Code（Gradle for Java 拡張）も標準的にサポート
  - CI/CD統合が強力。GitHub Actions、GitLab CI、Jenkins は Gradle を標準サポートし、Build Cache および Configuration Cache を活用した高速化が可能
  - Gradle Wrapper により、プロジェクト固有のバージョン管理と CI/CD 環境の整合性が保証される
- 欠点:
  - Kotlin DSL を採用する場合、チームが Kotlin に不慣れだと初期学習コストが発生する（Groovy DSL であれば緩和されるが、Kotlin DSL が推奨されている）
  - Maven と比較してプラグインの品質にばらつきがある（サードパーティプラグインの場合）
- 根拠:
  - Spring Boot 公式ドキュメントは Gradle を Maven と同等に扱い、Spring Initializr では Gradle（Groovy / Kotlin）を選択肢として提供している
  - research.md の知見: Gradle 9.3.1 が 2026年1月29日にリリースされ、活発に開発が進んでいる。2026年の Slant コミュニティランキングでは Gradle が1位を獲得
  - Gradle Plugin Portal（plugins.gradle.org）には30,000以上のプラグインが登録されており、エコシステムの成長が加速している
- CSD依存: なし（既存決定 ADR-0001 で Java 21 が確定しており、Gradle の Java 21 サポートは確実）

### Ant + Ivy

- 評価: △
- 利点:
  - Java 21 自体のコンパイルは可能（`javac` タスクを直接呼び出す）
  - Ivy により依存関係管理は可能であり、Maven Central Repository からの依存解決もサポートされる
- 欠点:
  - Spring Boot 3.x の公式統合が存在しない。Spring Boot プラグインは Maven / Gradle 専用であり、Ant 用のプラグインは提供されていない
  - Spring Boot の実行可能 JAR（Fat JAR）を生成するには、カスタムタスクを記述する必要があり、保守負荷が高い
  - IDE の Ant サポートは限定的。IntelliJ IDEA および Eclipse は Ant ビルドを実行できるが、自動的なプロジェクト構造認識やリファクタリングは Maven / Gradle と比較して弱い
  - CI/CD 統合では、Ant ビルドを手動で設定する必要がある（キャッシュ戦略も自前で実装）
  - エコシステムが縮小傾向にある。新しいライブラリやフレームワークは Ant をサポート対象外とする場合が多い
- 根拠:
  - Spring Boot 公式ドキュメントには Ant に関する記述がなく、Build Systems セクションでは Maven と Gradle のみを扱っている
  - Ant は 2000年代初頭の主流ツールであったが、2026年時点では事実上レガシーツールとして扱われている
- CSD依存: なし

### Bazel

- 評価: △
- 利点:
  - Java 21 をサポート（`java_binary`, `java_library` ルールで対応可能）
  - 大規模モノレポジトリおよびマルチモジュール構成で、ビルドの並列性とキャッシングが強力
  - ビルドの再現性が高く、エルミート性（hermetic build）を保証する
- 欠点:
  - Spring Boot 3.x の公式プラグインが存在しない。Spring Boot の実行可能 JAR を生成するには、カスタム Starlark ルールを記述する必要がある
  - IDE 統合が限定的。IntelliJ IDEA には Bazel プラグインが存在するが、Maven / Gradle と比較してサポート範囲が狭い
  - エコシステムが Java 単一プロジェクトよりもマルチ言語モノレポジトリに最適化されており、Spring Boot アプリケーション単体の開発には過剰である
  - 学習コストが高い。BUILD ファイルの記述は Maven / Gradle と大きく異なり、チームの習熟に時間がかかる
  - CI/CD 統合には専用のキャッシュインフラ（Bazel Remote Cache）が推奨されるが、セットアップコストが高い
- 根拠:
  - Spring Boot 公式ドキュメントには Bazel に関する記述がない
  - research.md の知見: Bazel は関数型評価モデルを採用した現代的なビルドシステムの中で唯一大規模なコミュニティを構築しているが、Java 単一プロジェクトでの主流採用には至っていない
- CSD依存: なし

### Buck2

- 評価: ×
- 利点:
  - Java をサポート（Meta 社内で使用されている）
  - ビルド速度が非常に高速（research.md の知見: Buck2 は Buck1 の2倍の速度）
- 欠点:
  - Spring Boot 3.x の公式統合が存在しない
  - Java 21 の動作実績が不明確（Buck2 のドキュメントに Java 21 に関する明示的な記述が少ない）
  - エコシステムが非常に若く、エンタープライズユースケースを置き換えるには早期段階（research.md の知見）
  - IDE 統合が未成熟（IntelliJ IDEA プラグインは実験的段階）
  - ルール定義 API が Bazel と互換性がないため、既存の Bazel エコシステムのコードを再利用できない（research.md の知見）
  - CI/CD 統合の事例が少なく、実運用での検証が不足している
- 根拠:
  - research.md の知見: Buck2 はまだ若いツールであり、コミュニティとエコシステムの成長が今後の鍵となる
  - Spring Boot 公式ドキュメントには Buck2 に関する記述がない
- CSD依存: なし

### Maven Wrapper のみ使用（ビルドツールは Maven 確定前提）

- 評価: ○（Maven 本体の評価に準ずる）
- 利点:
  - Maven 本体のエコシステム統合性（Spring Boot 3.x、Java 21、IDE、CI/CD）を継承する
  - プロジェクト固有の Maven バージョンを保証し、CI/CD 環境との整合性を確保する（「mvnw」コマンド経由で実行）
  - GitHub Actions、GitLab CI では Maven Wrapper を使用することが推奨されており、統合が容易
- 欠点:
  - Maven 本体の欠点（Maven 4 移行時のプラグイン互換性問題、カスタムプラグイン開発の煩雑さ）を継承する
- 根拠:
  - Maven Wrapper は Maven 本体の実行方法の標準化手段であり、エコシステム統合性は Maven 本体と同一
- CSD依存: なし

### Gradle Wrapper のみ使用（ビルドツールは Gradle 確定前提）

- 評価: ◎（Gradle 本体の評価に準ずる）
- 利点:
  - Gradle 本体のエコシステム統合性（Spring Boot 3.x、Java 21、IDE、CI/CD）を継承する
  - プロジェクト固有の Gradle バージョンを保証し、CI/CD 環境との整合性を確保する（「gradlew」コマンド経由で実行）
  - GitHub Actions、GitLab CI では Gradle Wrapper を使用することが推奨されており、Build Cache および Configuration Cache との統合が容易
- 欠点:
  - Gradle 本体の欠点（Kotlin DSL の学習コスト、サードパーティプラグインの品質ばらつき）を継承する
- 根拠:
  - Gradle Wrapper は Gradle 本体の実行方法の標準化手段であり、エコシステム統合性は Gradle 本体と同一
- CSD依存: なし
