# リサーチ結果

## 調査日
2026-02-16

## 調査観点

決定ステートメント（新規開発プロジェクトにおいて、どのJavaバージョンを採用するか）から特定した、時間経過で変化しうる事実の観点を以下に列挙する。

1. LTSバージョンのサポートスケジュール（2026年時点での有効期限と移行推奨時期）
2. Java 21 と Java 17 の性能差（最新のベンチマーク結果）
3. 主要フレームワークのJavaバージョン互換性要件（特にSpring Boot 3系）
4. 最新の非LTSバージョン（Java 23）の機能と位置づけ

## 調査結果

### LTSバージョンのサポートスケジュール

- 検索クエリ: `Java LTS versions 2026 support schedule`
- 主要な知見:
  - Java SE 8, 11, 17, 21, 25がLTSリリース。次回LTSは2027年9月のJava 29を予定
  - **Java 11**: Oracle Java 11は2026年9月にEOLを迎える
  - **Java 17**: 2021年9月リリース。Premier Supportは2026年まで、Extended Supportは2029年9月まで
  - **Java 21**: NFTC（No-Fee Terms and Conditions）版の最終リリースは2026年9月予定。以降は有償サブスクリプションが必要
  - **Java 25**: 2025年9月リリースの最新LTS。標準的な長期サポートを受ける
  - Oracle JDKのサポート構造: Premier Support（最低5年間）+ Extended Support（LTSのみ、追加3年間）
- 出典: [Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html), [Oracle JDK | endoflife.date](https://endoflife.date/oracle-jdk), [All Java Versions: Complete Release History & LTS Schedule (2026)](https://houseofbrick.com/blog/java-versions-update/)

### Java 21 と Java 17 の性能差

- 検索クエリ: `Java 21 vs Java 17 performance benchmarks 2026`
- 主要な知見:
  - Azulのベンチマークでは、OpenJDK 17はベースラインより6%高速、OpenJDK 21は12%高速
  - Timefoldの分析では、ほとんどのケースで小幅な性能向上を確認。ただし「Conference Scheduling」ベンチマークは例外的
  - 全体としてJava 17→21で漸進的な性能向上が見られる
  - **Generational ZGCの改善**: 生スループット性能ではJDK 17以降で大きな差はないが、Generational ZGCを使用すると10%の改善
  - **Virtual Threads**: 生の速度向上は穏やかだが、Virtual Threadsによる並行処理の革新が大きな利点。軽量スレッド管理でリソース消費を大幅削減し、高並行アプリケーションのパフォーマンスを向上
- 出典: [Benchmarks Show Faster Java Performance Improvement - Azul](https://www.azul.com/blog/benchmarks-show-faster-java-performance-improvement/), [How fast is Java 21? | Timefold](https://timefold.ai/blog/java-21-performance), [Java 21 vs. Java 17: A Performance and Feature Deep Dive - Oreate AI Blog](https://www.oreateai.com/blog/java-21-vs-java-17-a-performance-and-feature-deep-dive/c969fd91c50d8abb9f9e4a78a4817803), [JDK 21: The GCs keep getting better](https://kstefanj.github.io/2023/12/13/jdk-21-the-gcs-keep-getting-better.html)

### 主要フレームワークのJavaバージョン互換性要件

- 検索クエリ: `Spring Boot 3 Java version requirements compatibility`
- 主要な知見:
  - **Spring Boot 3.0の最小要件**: Java 17が必須。Java 8またはJava 11からのアップグレードが必要
  - Java 17をLTS最新版として要求する最初の主要フレームワーク
  - Java 17が必要な理由: 最新のLTSリリースであり、数年間のセキュリティパッチと更新が保証される
  - Spring Boot 3はJDK 19でもテスト済み。より新しいバージョン（19以降）でも動作
  - Spring Boot 3.4.5および3.x系全般でJava 17が最小バージョン
  - 追加要件: Spring Framework 6以上が必要
- 出典: [Spring Boot 3.0 Release Notes](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.0-Release-Notes), [Why Spring Boot 3 Requires Java 17 and Above: A Detailed Explanation](https://anilr9.medium.com/why-spring-boot-3-requires-java-17-and-above-a-detailed-explanation-70831ea227a3), [Spring And Spring Boot Versions](https://www.marcobehler.com/guides/spring-and-spring-boot-versions)

### 最新の非LTSバージョンの機能と位置づけ

- 検索クエリ: `Java 23 features release date new capabilities`
- 主要な知見:
  - **リリース日**: 2024年9月17日
  - **サポート期間**: 短期JDKリリースで、Premier Supportは6ヶ月間のみ
  - **主要な正式機能**（3件）:
    - Markdown Documentation Comments: JavaDocをMarkdownで記述可能に
    - Generational Z Garbage Collector: ZGCのデフォルトがGenerationalモードに変更。若いオブジェクトを頻繁に収集し性能向上
    - Memory-Access Methods Deprecation: sun.miscのメモリアクセスメソッドが非推奨化（VarHandle APIとForeign Functions & Memory APIに置き換え）
  - **主要なプレビュー機能**（8件含む）:
    - Primitive Type Patterns: プリミティブ型のパターンマッチング拡張
    - Module Import Declarations: モジュール全体のインポートを簡潔に記述
    - Structured Concurrency: 構造化並行性（Third Preview）
    - Flexible Constructor Bodies: コンストラクタ本体でのフィールド初期化の柔軟性向上
- 出典: [JDK 23: What is new in Java 23?](https://symflower.com/en/company/blog/2024/what-is-new-in-java-23/), [JDK 23: The new features in Java 23 | InfoWorld](https://www.infoworld.com/article/2336682/jdk-23-the-new-features-in-java-23.html), [What's New With Java 23 | JRebel](https://www.jrebel.com/blog/whats-new-java-23), [JDK 23](https://openjdk.org/projects/jdk/23/)

## サマリー

2026年2月時点で、この決定に特に影響する主要な事実は以下の通り:

1. **Java 11のEOL迫る**: Oracle Java 11は2026年9月にEOLを迎えるため、新規プロジェクトでの採用は推奨されない
2. **Java 21の無償版期限**: Java 21のNFTC版は2026年9月で終了し、以降は有償化。ただしOpenJDKディストリビューション（Eclipse Temurin等）は引き続き無償で利用可能
3. **Spring Boot 3がJava 17を最小要件化**: 主要フレームワークがJava 17以上を要求する流れが明確化。Java 8/11では最新エコシステムに追従できない
4. **Java 21の性能とVirtual Threads**: Java 17比で10-12%の性能向上。特にVirtual Threadsによる並行処理の革新が、高並行性アプリケーションでの大きな利点
5. **Java 25がLTS最新版**: 2025年9月リリースの最新LTS。長期サポートを受けられるが、エコシステムの成熟度はJava 17/21より低い可能性
