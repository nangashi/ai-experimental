# リサーチ結果

## 調査日
2026-02-16

## 調査観点

決定ステートメント「新規開発プロジェクトにおいて、Javaのビルドシステムとしてどのツール/方式を採用するか」に基づき、以下の時間経過で変化しうる事実を調査した。

1. Maven および Gradle の最新バージョンと主要機能
2. Gradle の最新パフォーマンス特性と機能強化
3. Maven の最新リリース状況と Maven 4 の進捗
4. 代替ビルドツール（Bazel、Buck2）のエコシステム動向
5. Java LTS バージョンのサポート状況とビルドツールの互換性

## 調査結果

### Maven および Gradle の最新バージョンと主要機能

- 検索クエリ: "Maven Gradle Java build tools 2026 comparison latest versions"
- 主要な知見:
  - Gradle の最新リリースは 2026年1月29日（バージョン 9.3.1）である（出典: [Gradle | Releases](https://gradle.org/releases/)）
  - Maven の最新安定版は 3.9.12 であり、全ユーザーに推奨されている（出典: [Maven Releases History](https://maven.apache.org/docs/history.html)）
  - パフォーマンス比較では、Gradle はほぼすべてのシナリオで Maven の少なくとも2倍高速であり、Build Cache を使用した大規模ビルドでは最大100倍高速である（出典: [Gradle vs Maven Comparison](https://gradle.org/maven-vs-gradle/)）
  - Maven ユーザーは Build Cache 導入により最大90%のビルド時間短縮を経験し、Gradle ユーザーは約50%の追加短縮を実現している（出典: [Maven vs Gradle, which is right for you?](https://buildkite.com/resources/comparison/maven-vs-gradle/)）
  - Gradle は Groovy または Kotlin DSL を使用し、簡潔なビルドスクリプトを記述可能。Maven は XML（pom.xml）を使用し、大規模プロジェクトでは設定ファイルが冗長になる傾向がある（出典: [Maven vs Gradle: Which Build Tool Should You Choose in 2025?](https://medium.com/@sunil17bbmp/maven-vs-gradle-which-build-tool-should-you-choose-in-2025-82f0ee8d5465)）
  - 2026年の Slant コミュニティランキングでは、Gradle が1位、Apache Maven が2位であり、ほとんどのユースケースで Gradle が推奨されている（出典: [Slant - Apache Maven vs Gradle detailed comparison](https://www.slant.co/versus/2107/11592/~apache-maven_vs_gradle)）

### Gradle の最新パフォーマンス特性と機能強化

- 検索クエリ: "Gradle 2026 latest version features performance"
- 主要な知見:
  - Gradle 9.3.1 が 2026年1月29日にリリースされ、開発中のマイルストーン版として 9.5.0-milestone-2 が存在する（出典: [Gradle 9.3.1 Release Notes](https://docs.gradle.org/current/release-notes.html)）
  - Gradle 9.3.1 は2件のセキュリティ脆弱性（リポジトリ処理関連）に対応している（出典: [Gradle 9.3.1 Release Notes](https://docs.gradle.org/current/release-notes.html)）
  - テストレポート機能が強化され、ネスト・パラメータ化・スイート形式のテストに対する詳細な HTML レポートを生成可能（出典: [Gradle 9.3.1 Release Notes](https://docs.gradle.org/current/release-notes.html)）
  - Configuration Cache により設定時間を大幅に削減可能。特に大規模コードベースで効果が高い（出典: [Improve the Performance of Gradle Builds](https://docs.gradle.org/current/userguide/performance.html)）
  - Kotlin 2 の機能活用により、Gradle 9.0.0 では Kotlin DSL スクリプトの不要な再コンパイルを回避し、ビルドロジック編集時のフィードバックループを最大2.5倍高速化（出典: [Gradle | What's new in Gradle 9.0.0](https://gradle.org/whats-new/gradle-9//)）
  - Gradle 8.8 以降、Tooling API の大規模タスクグラフ実行が最適化され、最新ビルドのパフォーマンスが最大12%向上（出典: [Improve the Performance of Gradle Builds](https://docs.gradle.org/current/userguide/performance.html)）

### Maven の最新リリース状況と Maven 4 の進捗

- 検索クエリ: "Maven 2026 latest version updates features"
- 主要な知見:
  - Maven の最新安定版は 3.9.12 である。全ユーザーに推奨されている（出典: [Maven Releases History](https://maven.apache.org/docs/history.html)）
  - Maven 4.0.0-rc-5 がリリース候補（Release Candidate）として提供されており、正式版リリースが近づいている（出典: [What's new in Maven 4?](https://maven.apache.org/whatsnewinmaven4.html)）
  - Maven 4 は Java 17 を必須とする。Maven 実行時に Java 17 が必要だが、コンパイル対象のソースコードは引き続き古い Java バージョンをサポート可能（出典: [What's new in Maven 4?](https://maven.apache.org/whatsnewinmaven4.html)）
  - Maven 4 では「fail on severity」ビルドパラメータが導入され、ログメッセージの深刻度に基づいてビルドを失敗させることが可能（出典: [What's new in Maven 4?](https://maven.apache.org/whatsnewinmaven4.html)）
  - Maven 4 では、Super POM で定義されたデフォルトバージョンに依存している場合に警告が表示される（出典: [What's new in Maven 4?](https://maven.apache.org/whatsnewinmaven4.html)）
  - Maven 4 対応には一部プラグインを最新バージョンにアップグレードする必要があり、Maven 拡張を使用している場合は互換性問題が発生する可能性がある（出典: [What's new in Maven 4?](https://maven.apache.org/whatsnewinmaven4.html)）
  - Maven Daemon 1.0.3 が利用可能であり、プレビュー版として Maven Daemon 2.0.0-rc-3 が存在する（出典: [Maven Releases History](https://maven.apache.org/docs/history.html)）

### 代替ビルドツール（Bazel、Buck2）のエコシステム動向

- 検索クエリ: "Java build tools ecosystem 2026 trends Bazel Buck2"
- 主要な知見:
  - Buck2 は Meta が開発したマルチ言語ビルドツールであり、Buck1 の完全な再実装。Rust で記述されている（Buck1 は Java で記述）（出典: [Build faster with Buck2: Our open source build system](https://engineering.fb.com/2023/04/06/open-source/buck2-open-source-large-scale-build-system/)）
  - Meta の内部テストでは、Buck2 は Buck1 の2倍の速度でビルドを完了し、Meta の数千人の開発者が毎日数百万件のビルドを実行している（出典: [Build faster with Buck2: Our open source build system](https://engineering.fb.com/2023/04/06/open-source/buck2-open-source-large-scale-build-system/)）
  - Buck2 は Starlark を使用し Bazel と類似しているが、ルール定義 API は Bazel と互換性がないため、既存の Bazel コードベースでは使用不可（出典: [Buck2 Unboxing](https://www.buildbuddy.io/blog/buck2-review/)）
  - Buck2 はまだ若いツールであり、エンタープライズユースケースを置き換えるには早期段階。コミュニティとエコシステムの成長が今後の鍵となる（出典: [Buck2 Unboxing](https://www.buildbuddy.io/blog/buck2-review/)）
  - Bazel は関数型評価モデルを採用した現代的なビルドシステムの中で、唯一大規模なコミュニティとエコシステムを構築している（出典: [The next generation of Bazel builds](https://blogsystem5.substack.com/p/bazel-next-generation)）

### Java LTS バージョンのサポート状況とビルドツールの互換性

- 検索クエリ: "Java LTS versions 2026 support build tool compatibility"
- 主要な知見:
  - 2026年時点の Java LTS バージョンは Java SE 8, 11, 17, 21, 25 である。次期 LTS リリースは Java 29（2027年9月）の予定（出典: [Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)）
  - Oracle JDK 21 は 2026年9月以降のアップデートから Java SE OTN ライセンスに移行予定。継続的にパーミッシブライセンス版を使用する場合は Oracle JDK 25 以降へのアップグレードが必要（出典: [Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)）
  - Java 17 は 2021年9月にリリースされ、2026年までプレミアサポート、2029年9月まで延長サポート予定（出典: [What is Java LTS and Why Does It Matter?](https://www.jrebel.com/blog/java-lts)）
  - Scala 3.8 以降は最小 JDK バージョンが 17 に引き上げられ、Scala 3.3.6+, 3.7.1+, 2.13.17+, 2.12.21+ は JDK 25 をサポート（出典: [JDK Compatibility | Scala Documentation](https://docs.scala-lang.org/overviews/jdk-compatibility/overview.html)）
  - Google Cloud Client Libraries for Java は Java 8, 11, 17, 21, 25 との互換性があり、テストされている（出典: [Supported Java Versions | Google Cloud Documentation](https://docs.cloud.google.com/java/docs/supported-java-versions)）

## サマリー

この決定に特に影響する主要な事実を以下に要約する。

1. **Gradle と Maven のバージョン状況**: Gradle は活発に開発が進み、2026年1月に 9.3.1 をリリース。Maven は安定版 3.9.12 と、Java 17 を必須とする Maven 4.0.0-rc-5（リリース候補）が並行して提供されている。Maven 4 の正式リリースが近づいているが、プラグインの互換性問題に注意が必要。

2. **パフォーマンス差**: Gradle は Maven の2倍以上高速であり、Build Cache 使用時は最大100倍の差が生じる。API ヘビーなバックエンドでは Gradle の並列タスク実行とローカルキャッシングが有効。Gradle は継続的にパフォーマンス最適化を実施しており（Configuration Cache、Kotlin DSL 最適化、Tooling API 改善等）、速度面での優位性は拡大傾向にある。

3. **エコシステムと成熟度**: Maven はエコシステムが成熟しているが、Gradle も 2026年のコミュニティランキングでトップを獲得し、エコシステムの成長が加速している。代替ツールとして Buck2 や Bazel が存在するが、Buck2 はエンタープライズ採用には早期段階であり、Bazel は学習コストが高く、Java プロジェクトでの主流採用には至っていない。

4. **Java LTS バージョンとの互換性**: Java 17, 21, 25 が現行 LTS であり、2027年9月に Java 29 が次期 LTS となる予定。Maven 4 は Java 17 を必須とするため、Java 8/11 環境での Maven 実行には Maven 3 系列を継続使用する必要がある。一方、ビルド対象のソースコードは引き続き古いバージョンの Java をサポート可能。

5. **柔軟性と保守性**: Gradle は Groovy/Kotlin DSL により柔軟で簡潔な設定が可能であり、複雑なビルド要件にも対応しやすい。Maven は XML ベースで標準化されているが、カスタマイズが困難であり、大規模プロジェクトでは冗長な設定ファイルが課題となる。
