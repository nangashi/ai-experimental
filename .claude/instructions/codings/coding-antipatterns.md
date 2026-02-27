# AI Coding Antipatterns

Self-check guidelines for code generation and editing: dead code management, design principle application boundaries, and over-abstraction prevention.

## デッドコード除去の明示的確認

- **scope**: 既存コードを修正・置換する場面、特に新しい実装を追加する際
- **action**: 新しい実装を追加する際、置き換え対象の古い実装を削除したか明示的に確認する。タスク近傍にあるという理由だけで理解していないコードを変更しない。コメントを副作用的に削除しない。
- **rationale**: デッドコード蓄積は80%問題の主要パターン。エージェントは自分が生成した不要コードを片付けず、古い実装を残したまま新しい実装を追加する傾向がある。AI生成コードのコード重複が人間の4倍に増加するという定量データもこれを裏付ける。
- **source**: docs/knowledge/ai-code-quality.md

## 値オブジェクトの適用条件を明示する

- **scope**: バリデーションやドメインロジックを持つ値を表現する場合
- **action**: 値にバリデーションルール、計算ロジック、フォーマット変換などのドメインロジックが存在する場合のみ値オブジェクトとして専用クラスを作成する。バリデーションもロジックもない単純な値（ID文字列、フラグ値等）にはプリミティブ型またはtype aliasを使用する。
- **rationale**: 過剰適用はclassitis（小さなクラスの増殖）と浅いモジュール化を招く。AIは指示がないと「値はすべて専用クラスにすべき」と過剰適用する傾向がある（実験で確認）。
- **conditions**: プロトタイプや小規模ツール。現代言語のvalue class/newtypeで実行時オーバーヘッドを除去できる場合は適用コストが低い。
- **source**: docs/knowledge/changeability-design-principles.md

## 完全コンストラクタの技術的例外を認識する

- **scope**: ドメインオブジェクトの構築設計
- **action**: オブジェクトはコンストラクタで全フィールドを初期化しバリデーションを通過した状態でのみ生成可能にする。ただしORM/DIフレームワークが技術的に引数なしコンストラクタを要求する場合は例外として許容し、その理由をコメントで記録する。パラメータ爆発の場合はビルダーパターンを併用する。
- **rationale**: 技術制約を無視した完全コンストラクタの強制は実装不可能な設計を生む。例外を認めないと実務での適用が不可能になる。
- **conditions**: ORM/DI等のフレームワーク制約。パラメータが多数でビルダーパターンを使用する場合。
- **source**: docs/knowledge/changeability-design-principles.md

## 不変性の性能例外を計測ベースで判断する

- **scope**: データ構造の可変/不変選択
- **action**: フィールド・変数はデフォルトで不変にする。性能が最優先の領域で可変データ構造を選択する場合は、必ず計測に基づいて判断する。
- **rationale**: ほぼ全ての設計思想家が不変性を支持する稀有な合意点。並行処理の安全性、予測可能性、デバッグ容易性で優位。
- **conditions**: パフォーマンスクリティカルな局所的処理で、計測により性能差が実証された場合のみ。
- **source**: docs/knowledge/changeability-design-principles.md

## データクラスの適用範囲をドメイン層に限定する

- **scope**: データのみを保持しロジックを持たないクラスの評価
- **action**: ドメイン層においてデータのみを保持しロジックを持たないクラスは低凝集の兆候として扱う。DTO、イベント、コマンド、APIレスポンス等のデータ転送目的クラスは対象外とする。関数型パラダイムを採用している場合も対象外とする。
- **rationale**: データクラス=低凝集はドメイン層に限定される原則。データ転送目的クラスにまで適用するとロジック混入による層の責務混乱を招く。
- **conditions**: DTO・イベント・コマンド等のデータ転送目的クラス。関数型パラダイム採用時。インフラ層のデータ構造。
- **source**: docs/knowledge/changeability-design-principles.md

## 副作用を持つstaticメソッドのみを排除対象とする

- **scope**: staticメソッドの設計判断
- **action**: 副作用（DB書き込み、ファイルI/O、外部API呼び出し等）や外部状態への依存を持つstaticメソッドを避ける。入力のみに依存し副作用を持たない純粋関数は、static/パッケージレベル関数として正当である。
- **rationale**: 副作用を持つstaticはテスト時のスタブ差し替えを困難にするが、純粋関数のstaticは完全に正当。AIは「staticは避けるべき」を過剰適用し、純粋関数まで排除しようとする。
- **conditions**: 純粋関数。数学的計算、型変換、フォーマット処理。関数型プログラミングやGoのパッケージレベル関数。
- **source**: docs/knowledge/changeability-design-principles.md

## デメテルの法則の適用除外を明示する

- **scope**: オブジェクト間のメッセージパッシング設計
- **action**: オブジェクトは直接の協力者のメソッドのみを呼び出す。3段階以上のメソッドチェーンは内部構造への依存を示す違反の兆候。ただしFluent APIやビルダーパターンの同一オブジェクトへの操作は除外する。
- **rationale**: 内部構造への依存を制限することで変更の波及を局所化する。Fluent APIは同一オブジェクトへの連続操作であり、デメテルの法則違反ではない。
- **conditions**: Fluent API / ビルダーパターン。ナビゲーション的アクセスが言語の慣習として確立している場合。
- **source**: docs/knowledge/changeability-design-principles.md

## CQSの正当な例外を許容する

- **scope**: メソッドの状態変更と値返却の分離判断
- **action**: メソッドはデフォルトで「状態を変更するコマンド」か「値を返すクエリ」のどちらか一方のみを行う。ただしアトミック操作、自然なAPI（stack.pop()）、分割が呼び出し側の複雑さを著しく増す場合は例外として許容し理由を記録する。
- **rationale**: Bertrand Meyerが提唱し、Martin Fowlerも「非常に有用な原則」と評価。ただしFowlerは「pop()のようにクエリとコマンドを一体にしたほうが著しく便利な場合がある」と指摘。
- **conditions**: アトミック操作（並行処理）。pop()のような自然なAPI。分割が呼び出し側の複雑さを著しく増す場合。
- **source**: docs/knowledge/changeability-design-principles.md

## 条件分岐の構造化に閾値条件を設定する

- **scope**: 同一条件の分岐が複数箇所に散在している場合
- **action**: 同一条件の分岐が2ファイル以上に散在している場合、ポリモーフィズムまたはパターンマッチで構造化する。単一箇所の単純な分岐には適用しない。
- **rationale**: 単一箇所の分岐にクラス階層を導入することはclassitisと浅いモジュール化を招く。AIは「条件分岐は悪」と過剰適用する。
- **conditions**: 単一箇所の単純な分岐。型の追加より振る舞いの追加が頻繁な場合。
- **source**: docs/knowledge/changeability-design-principles.md

## ファーストクラスコレクションの適用条件を明示する

- **scope**: ビジネスルールを持つコレクションの設計
- **action**: コレクションにビジネスルールや不変条件が存在する場合、専用クラスにカプセル化する。ビジネスルールのない単純なコレクションには適用しない。
- **rationale**: ビジネスルールを持たないコレクションのラッパーは浅いモジュールの典型例。AIは「コレクションはすべてラップすべき」と過剰適用する。
- **conditions**: ビジネスルールのない単純なコレクション。言語のコレクションAPIで十分に表現できる場合。
- **source**: docs/knowledge/changeability-design-principles.md

## サブクラスの都合でスーパークラスを変更しない

- **scope**: 継承関係の設計
- **action**: 継承関係において、子クラスの要求で親クラスを変更してはならない。サブクラスの追加がスーパークラスの修正を必要としない安定したインターフェースを設計する。
- **rationale**: 開放閉鎖原則（OCP）の具体的適用。サブクラスの追加によるスーパークラスの変更は、他のサブクラスに予期しない影響を波及させる。
- **conditions**: 過度に安定性を求めるとスーパークラスが過剰に抽象的になる場合がある。そもそも継承よりコンポジションを優先すべき場面が多い。
- **source**: docs/knowledge/changeability-design-principles.md

## 共通化判断を目的の一致に基づかせる

- **scope**: コードの共通化・再利用判断
- **action**: コードの見た目が似ていても、ビジネス上の目的が異なるなら共通化しない。共通化の判断は「コードの見た目」ではなく「意図の一致」に基づく。目的が同じと判断した場合は共通化を推奨する。
- **rationale**: Sandi Metzは「間違った抽象は重複より遥かにコストが高い」と述べた。Dan Abramovも安易な共通化が将来の変更を困難にする実体験を紹介。DRY原典著者もDRYは見た目の類似ではなく知識の重複を対象とすると明言。
- **conditions**: 「目的が同じかどうか」の判断基準が曖昧になりがち。チーム内で「目的」の定義が共有されていない場合、適用困難。
- **source**: docs/knowledge/changeability-design-principles.md

## 目的駆動命名をドメイン層に限定する

- **scope**: ドメイン層のクラス名・メソッド名の命名
- **action**: ドメイン層のクラス名・メソッド名は、技術的な「何であるか」ではなく、ビジネス上の「何のためか」で命名する。インフラ層やフレームワーク連携のコードでは技術的な命名が適切。
- **rationale**: Eric Evans（DDD/ユビキタス言語）、Martin Fowler（Intention Revealing Name）、Kent Beck（Simple Design — Reveals Intention）のいずれとも整合。
- **conditions**: インフラ層、技術的ユーティリティ、フレームワーク連携コード。
- **source**: docs/knowledge/changeability-design-principles.md

## 役割駆動設計の適用規模を明示する

- **scope**: 大規模ドメインでのモデル分割判断
- **action**: 大規模ドメインで、同一エンティティの異なる役割が明確に識別でき、役割間の振る舞いが異なる場合に限り、役割ごとにモデルを分割する。小規模プロジェクトでは1つのモデルで十分。
- **rationale**: Eric Evans（DDD/Bounded Context）の方針と整合。John Ousterhoutは「過度な分割は浅いモジュールの増殖を招く」と警告。YAGNIは「将来のための分割は実際に複雑さが正当化するレベルに達してから」と主張。
- **conditions**: 小規模プロジェクト。役割間で共有するデータが多く、分割コストが利益を上回る場合。
- **source**: docs/knowledge/changeability-design-principles.md
