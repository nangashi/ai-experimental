# コーディング規約

## 決定事項一覧（サマリテーブル）

| # | 決定事項 | 主な選択肢 | 決定の影響度 |
|---|---------|-----------|-------------|
| 1 | Linter 設定 | ESLint / Biome / ESLint + Biome 併用 | 高：コード品質の自動担保基盤 |
| 2 | Formatter 設定 | Prettier / Biome / dprint | 中：コードスタイルの統一 |
| 3 | TypeScript 設定方針 | strict mode レベル / 型定義戦略 | 高：型安全性とDXのバランス |
| 4 | 命名規則 | ケース規則 / ファイル名 / API endpoint 等 | 中：コードの一貫性・可読性 |
| 5 | コメント・ドキュメント方針 | JSDoc / TSDoc / ADR / インラインコメント | 低〜中：保守性・ナレッジ継承 |
| 6 | インポート順序・整理ルール | 自動ソート / グループ分け / ESLint ルール | 低：可読性・差分ノイズ低減 |
| 7 | エラーハンドリング規約 | Result 型 / try-catch / カスタムエラー | 高：システムの堅牢性に直結 |
| 8 | 非同期処理の規約 | async/await 統一 / エラー伝播方針 | 中：バグ防止・デバッグ容易性 |
| 9 | 不変性・純粋関数の方針 | Immutable 徹底 / 実用的使い分け | 中：予測可能性・テスト容易性 |
| 10 | Git commit メッセージ規約 | Conventional Commits / 独自規約 | 中：変更履歴の追跡性・自動化 |

## 各項目の詳細

### 1. Linter 設定

- **何を決めるか**: コード品質を自動チェックするツールの選定と設定方針
- **選択肢**:
  - **ESLint**: JavaScript/TypeScript エコシステムのデファクト。豊富なプラグインエコシステム（`@typescript-eslint`, `eslint-plugin-react`, `eslint-plugin-import` 等）
  - **Biome**: Rust 製の統合ツール（Linter + Formatter）。423+ lint ルール。単一バイナリ、設定ファイル1つ
  - **ESLint + Biome 併用**: Biome を formatter として使い、ESLint を型認識 lint に限定
- **選定基準**:
  - パフォーマンス：10,000ファイルの lint で ESLint 45.2秒 vs Biome 0.8秒（約56倍）
  - プラグインエコシステム：ESLint は数千のプラグインが存在。Biome はコアルールに集中、カスタムプラグインは限定的
  - 型認識 lint：ESLint + `@typescript-eslint` は TypeScript コンパイラを利用した完全な型チェック。Biome 2.0+ は独自の型推論（TypeScript-eslint カバレッジの約85%）
  - チームの既存知識：ESLint の設定・ルール知識がある場合の移行コスト
- **トレードオフ・注意点**:
  - Biome: プラグインエコシステムが ESLint に比べ限定的。React 固有のルールや特殊なプラグイン（`eslint-plugin-testing-library` 等）が必要な場合は ESLint が必要
  - ESLint: 設定の複雑さ（eslintrc → flat config 移行）、依存パッケージ数が多い（127+）
  - 併用: 2つのツールの設定を管理するオーバーヘッドが発生。ルールの重複・競合に注意
  - ESLint v9 で flat config が標準化。旧 eslintrc 形式からの移行が必要
- **2025-2026年のトレンド**:
  - Biome 2.0（2025年6月リリース）で型推論機能を獲得。新規プロジェクトでの採用が急増
  - 2026年1月時点で Biome v2.3。型認識 lint のカバレッジは着実に向上中
  - ESLint は flat config への移行が完了し、設定が簡素化。ただしプラグインの flat config 対応にばらつきあり
  - 「新規プロジェクトは Biome、既存プロジェクトは段階的移行」というコンセンサスが形成されつつある
  - モノレポ100k+ 行・CI 時間がクリティカルな環境では Biome の速度優位が決定的

### 2. Formatter 設定

- **何を決めるか**: コードフォーマットの自動整形ツールの選定と設定方針
- **選択肢**:
  - **Prettier**: JavaScript/TypeScript エコシステムのデファクト formatter。Opinionated（設定項目が意図的に少ない）
  - **Biome（Formatter）**: Prettier 互換の出力。Linter と統合されているため設定が一元化
  - **dprint**: Rust 製の高速 formatter。Prettier より設定の自由度が高い。プラグインベースで言語拡張
- **選定基準**:
  - Linter との統合：Biome を linter として採用する場合、formatter も Biome に統一すると設定が簡素化
  - パフォーマンス：10,000ファイルのフォーマットで Prettier 12.1秒 vs Biome 0.3秒（約40倍）
  - 互換性：Prettier の出力形式がデファクト標準。Biome は Prettier 互換を目指しているが完全一致ではない
  - エディタ統合：全ツールとも VS Code 拡張を提供。保存時自動フォーマットに対応
- **トレードオフ・注意点**:
  - Prettier: パフォーマンスが Biome/dprint に劣る。ただし大半のプロジェクトでは実用上問題ないレベル
  - Biome: Prettier との出力差分がわずかに存在する場合がある。既存プロジェクトの移行時に一括差分が発生
  - dprint: コミュニティ・ドキュメントが Prettier/Biome に比べ小規模
  - formatter の選定は linter の選定と連動させる（Biome linter + Prettier formatter は非推奨構成）
- **2025-2026年のトレンド**:
  - Biome を linter + formatter の統合ツールとして採用する構成が新規プロジェクトの第一候補
  - Prettier は依然として広く使われているが、新規プロジェクトでの採用率は低下傾向
  - dprint は Deno エコシステムで採用が増加しているが、React/Next.js エコシステムではマイナー

### 3. TypeScript 設定方針

- **何を決めるか**: TypeScript の厳格度レベル、型定義の管理方針
- **選択肢**:
  - **strict: true（推奨）**: `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes` 等を一括有効化
  - **段階的 strict 化**: まず `strict: false` で開始し、個別オプションを順次有効化
  - **型定義戦略**: 推論優先 / 明示的型注釈優先 / 境界のみ型注釈
- **選定基準**:
  - プロジェクト新規性：新規プロジェクトは `strict: true` で開始する理由がない。既存 JS → TS 移行は段階的
  - チームの TypeScript 習熟度：strict モードはエラーメッセージの理解に経験が必要
  - 外部ライブラリとの互換性：一部のライブラリは strict モードで型エラーが発生する場合がある
- **トレードオフ・注意点**:
  - `strict: true` は新規プロジェクトで必須レベルの推奨。後から有効化すると大量のエラー修正が発生
  - `any` の使用は原則禁止。やむを得ない場合は `unknown` を使用し、型ガードで narrowing する
  - 戻り値の型注釈：公開 API（exported 関数）は明示的型注釈、内部関数は推論を活用
  - `as` によるキャストは原則禁止。型ガードまたは `satisfies` 演算子を使用
  - `tsconfig.json` の `compilerOptions` で有効にすべき追加オプション：
    - `noUncheckedIndexedAccess: true`（配列・オブジェクトのインデックスアクセスに undefined を含める）
    - `exactOptionalProperties: true`（optional property に undefined の明示的代入を禁止）
    - `noUnusedLocals: true`, `noUnusedParameters: true`
- **2025-2026年のトレンド**:
  - `strict: true` + `noUncheckedIndexedAccess` が新規プロジェクトの標準構成
  - `satisfies` 演算子（TypeScript 4.9+）の活用が一般化。`as const satisfies Config` パターンが型安全な設定定義の定番に
  - TypeScript 5.x の新機能（`const` 型パラメータ、改善された型推論）を積極的に活用
  - Zod / Valibot 等のバリデーションライブラリからの型推論が「型定義の単一ソース」として定着
  - `@total-typescript/tsconfig` 等の共有 tsconfig ベースが新規プロジェクトの出発点として普及

### 4. 命名規則

- **何を決めるか**: ファイル名、変数名、コンポーネント名、API endpoint 等の命名規則
- **選択肢**:
  - ファイル名：`kebab-case` / `PascalCase` / `camelCase`
  - 変数・関数名：`camelCase`（事実上の標準）
  - 型・インターフェース：`PascalCase`（事実上の標準）
  - 定数：`SCREAMING_SNAKE_CASE` / `camelCase`
  - コンポーネント：`PascalCase`（React の要件）
  - API endpoint：`/kebab-case` / `/snake_case` / `/camelCase`
- **選定基準**:
  - フレームワーク規約との整合性：Next.js は `kebab-case` のファイル名を推奨、Angular は feature.type.ts 形式
  - OS 互換性：macOS はファイル名の大文字小文字を区別しないため、`PascalCase` ファイル名は CI（Linux）との不一致を引き起こしうる
  - API 消費者の慣習：REST API は一般的に `kebab-case`、JSON のキーは `camelCase` が主流
- **トレードオフ・注意点**:
  - ファイル名に `PascalCase` を使うと macOS/Windows と Linux 間でのケース不一致問題が発生するリスクがある。コンポーネントファイルのみ `PascalCase` を許可し、それ以外は `kebab-case` とする折衷案が実用的
  - インターフェースに `I` プレフィックスは付けない（TypeScript 公式ガイドラインに反する）
  - Enum は `PascalCase`（型名）+ `PascalCase`（メンバー）。Google TypeScript Style Guide 準拠
  - Boolean 変数は `is`, `has`, `should`, `can` 等のプレフィックスを推奨
  - async 関数は具体的な目的を示す名前にする（`getData` ではなく `fetchUserProfile` 等）
- **2025-2026年のトレンド**:
  - ファイル名 `kebab-case` が Next.js / Nuxt / Angular で事実上の標準に統一されつつある
  - `@typescript-eslint/naming-convention` ルールによる命名規則の自動強制が一般化
  - API endpoint は `kebab-case`（REST）が主流。GraphQL は field 名 `camelCase`
  - 「型とインターフェースの命名に差をつけない」（`I` プレフィックスや `Type` サフィックスを使わない）方針が定着

### 5. コメント・ドキュメント方針

- **何を決めるか**: コード内コメントの書き方、API ドキュメントの生成方法、設計記録の管理
- **選択肢**:
  - **JSDoc / TSDoc**: 関数・クラス・型にドキュメントコメントを付与。`@param`, `@returns`, `@example` 等のタグ
  - **ADR（Architecture Decision Record）**: 設計判断とその理由を記録するドキュメント形式
  - **インラインコメント最小化**: 型と関数名で意図を伝え、コメントは「なぜ」のみ記述
- **選定基準**:
  - API の公開範囲：外部公開 API は TSDoc 必須。内部コードは型推論とわかりやすい命名で代替
  - チーム規模：大規模チームほどドキュメントの価値が高い
  - ツール連携：TSDoc は VS Code のホバー表示やドキュメント生成ツール（TypeDoc）と連携
- **トレードオフ・注意点**:
  - 過剰なコメントはメンテナンスコストを増大させ、コードとの乖離が発生するリスク
  - 「What」ではなく「Why」をコメントする原則。コードを読めばわかることは書かない
  - TSDoc は TypeScript に特化した仕様で、JSDoc のスーパーセットではない（互換性に注意）
  - TODO コメントには担当者と期限を付与する（例: `// TODO(@username): 2026-03 までに対応`）
  - ADR は docs/adr/ に連番で管理。テンプレート：タイトル、ステータス、コンテキスト、決定、結果
- **2025-2026年のトレンド**:
  - AI コーディングアシスタントがコードを読むことを前提に、TSDoc の重要性が再評価されている
  - ADR の採用が中小規模プロジェクトにも拡大。テンプレートの標準化が進んでいる
  - GitHub Copilot / Claude Code が TSDoc から関数の使い方を理解するため、AI 向けのドキュメンテーションという新たな動機が発生
  - `CLAUDE.md` や `.github/copilot-instructions.md` 等の AI アシスタント向けプロジェクト説明ファイルが新たなドキュメント形式として定着

### 6. インポート順序・整理ルール

- **何を決めるか**: import 文のグループ分けと自動ソートルール
- **選択肢**:
  - **eslint-plugin-simple-import-sort**: 自動修正対応のシンプルなインポートソートプラグイン
  - **eslint-plugin-import の import/order**: グループ定義が柔軟（builtin, external, internal, parent, sibling, index, object, type）
  - **Biome の organize imports**: Biome 内蔵のインポート整理機能
  - **prettier-plugin-organize-imports**: TypeScript Language Server を利用した Prettier プラグイン
- **選定基準**:
  - Linter/Formatter との整合性：Biome 採用時は内蔵機能を使用。ESLint + Prettier 構成ならプラグインを選択
  - 自動修正：保存時に自動ソートされることが必須。手動管理は非現実的
  - グループ分けの柔度：プロジェクト固有のエイリアス（`@/`）を適切にグループ化できるか
- **トレードオフ・注意点**:
  - 推奨グループ順序（上から下へ）：
    1. Node.js 組み込みモジュール（`node:fs`, `node:path`）
    2. 外部パッケージ（`react`, `next`, `zod` 等）
    3. 内部エイリアス（`@/features/...`, `@/shared/...`）
    4. 親ディレクトリ（`../`）
    5. 同階層（`./`）
    6. 型のみのインポート（`type` imports）
  - 各グループは空行で区切る
  - `eslint-plugin-simple-import-sort` が最も設定が簡単で、多くのプロジェクトの要件を満たす
  - TypeScript の `type` import（`import type { ... }`）は最後のグループに配置するのが一般的
- **2025-2026年のトレンド**:
  - Biome の organize imports 機能が成熟し、ESLint プラグインに代わる選択肢として確立
  - TypeScript 5.x の `verbatimModuleSyntax` と組み合わせた `import type` の強制が標準化
  - `eslint-plugin-perfectionist` の `sort-imports` ルールが `eslint-plugin-import` の代替として台頭
  - ESLint flat config 対応のインポート整理プラグインが出揃い、移行障壁が低下

### 7. エラーハンドリング規約

- **何を決めるか**: アプリケーション全体のエラー処理パターンと、エラー型の設計方針
- **選択肢**:
  - **Result 型パターン**: 判別共用体（Discriminated Union）で成功/失敗を型安全に表現
    ```typescript
    type Result<T, E = Error> =
      | { success: true; data: T }
      | { success: false; error: E };
    ```
  - **try-catch 方針**: 標準の例外機構を使用。catch でのエラー型ガードを規約化
  - **カスタムエラークラス**: `AppError`, `ValidationError`, `NotFoundError` 等のエラー階層を定義
  - **neverthrow ライブラリ**: `Result<T, E>` 型とメソッドチェーン（`map`, `mapErr`, `andThen`）を提供
- **選定基準**:
  - 型安全性：Result 型は戻り値の型でエラーの可能性を明示するため、呼び出し側でのハンドリング漏れを防止
  - チームの関数型プログラミング経験：Result 型のメソッドチェーンには一定の学習コスト
  - フレームワーク互換性：React の ErrorBoundary、Next.js の error.tsx は例外ベースの設計
  - ライブラリとの整合性：多くのサードパーティは例外を throw するため、境界での変換が必要
- **トレードオフ・注意点**:
  - Result 型と例外の混在はコードベースの一貫性を損なう。境界を明確にする（外部ライブラリとの境界で変換等）
  - JavaScript は任意の値を throw できるが、必ず `Error` またはそのサブクラスのみを throw する規約とする（スタックトレース確保）
  - カスタムエラーには `code` プロパティ（機械可読）と `message`（人間可読）を含める
  - HTTP レイヤーのエラー処理と ドメインロジックのエラー処理は分離する
  - `catch(e)` の `e` は `unknown` 型（TypeScript 4.4+, `useUnknownInCatchVariables`）。型ガード必須
- **2025-2026年のトレンド**:
  - neverthrow や ts-results 等の Result 型ライブラリの採用が増加。特にバックエンドのドメインロジック層で普及
  - フロントエンドでは TanStack Query / SWR のエラーハンドリングに任せ、ドメイン層で Result 型を使う二層構造が一般的
  - TypeScript の `using` 宣言（Explicit Resource Management）が安定し、リソース解放のエラーハンドリングが改善
  - ECMAScript の Safe Assignment Operator（`?=`）提案が注目されているが、2026年2月時点では Stage 1 で未確定
  - Zod の `.safeParse()` が返す Result 型ライクな構造（`{ success, data, error }`）がバリデーション層のエラーハンドリング標準に

### 8. 非同期処理の規約

- **何を決めるか**: async/await の使用方針、Promise のエラー伝播ルール、並行処理パターン
- **選択肢**:
  - **async/await 統一**: `.then()/.catch()` チェーンを禁止し、async/await に統一
  - **エラー伝播方針**: 各レイヤーでの catch 範囲と再 throw ルール
  - **並行処理**: `Promise.all` / `Promise.allSettled` / `Promise.race` の使い分け
- **選定基準**:
  - 可読性：async/await はフラットな制御フローで読みやすい
  - エラーハンドリング：try-catch ブロックのスコープと catch の粒度を規約化する必要がある
  - パフォーマンス：独立した非同期処理は `Promise.all` で並行実行すべき（直列の await を避ける）
- **トレードオフ・注意点**:
  - `await` の付け忘れは実行時にのみ発覚する。`@typescript-eslint/no-floating-promises` ルールで検出
  - `@typescript-eslint/no-misused-promises`：Promise を boolean コンテキスト（if 文等）で使うことを防止
  - 戻り値の型を明示的に `Promise<T>` と注釈することで、await 付け忘れを型レベルで検出可能
  - `Promise.all` は1つでも reject されると全体が reject。部分的な成功が必要な場合は `Promise.allSettled` を使用
  - トップレベル await は ESM 環境でのみ使用可能。CJS 環境との互換性に注意
  - 非同期イテレーション（`for await...of`）はストリーム処理に限定し、配列の非同期処理には使わない
- **2025-2026年のトレンド**:
  - `@typescript-eslint/no-floating-promises` が厳格 lint 設定の必須ルールとして定着
  - Server Components（React Server Components）での async/await が一般化し、サーバーサイドの非同期パターンがシンプル化
  - AbortController / AbortSignal を用いたキャンセル処理の標準化が進行
  - Web Streams API の活用が増加（AI チャットのストリーミングレスポンス等）

### 9. 不変性・純粋関数の方針

- **何を決めるか**: データの不変性（Immutability）をどこまで強制するか、純粋関数をどこに適用するか
- **選択肢**:
  - **徹底的な不変性**: `readonly`, `Readonly<T>`, `ReadonlyArray<T>` を全面適用。Object.freeze を併用
  - **実用的な使い分け**: ドメインモデルは不変、UI 状態は可変を許容
  - **ライブラリ依存**: Immer を使用して「可変スタイルで不変操作」を実現
- **選定基準**:
  - フレームワークの要件：React は不変性前提の状態管理。Vue は reactive なので可変スタイル
  - パフォーマンス：大量データの deep copy はコストが高い。構造共有（structural sharing）を使うライブラリを検討
  - チームの慣習：不変性に不慣れなチームでは Immer が学習コストを低減
- **トレードオフ・注意点**:
  - TypeScript の `readonly` はコンパイル時のみの制約。ランタイムでは変更可能
  - `as const` で深いレベルまでの readonly 化が可能（リテラル型の保持にも有効）
  - Array のメソッド：`.sort()`, `.reverse()`, `.splice()` は破壊的。`.toSorted()`, `.toReversed()`, `.toSpliced()`（ES2023+）を使用
  - 純粋関数の適用範囲：ドメインロジック、ユーティリティ関数、バリデーションは純粋関数。副作用はアプリケーション層の境界に集約
  - Immer は便利だが、バンドルサイズ（約5KB gzip）と、「見た目は可変だが実際は不変」という認知的ギャップに注意
- **2025-2026年のトレンド**:
  - ES2023 の非破壊的配列メソッド（`.toSorted()` 等）の採用が一般化。`Array.prototype.sort()` の使用が lint で警告される設定が増加
  - `Record & Tuple` 提案（Stage 2）は進行中だが、2026年時点で未確定
  - React の useState / useReducer + Immer パターンが状態管理の標準的アプローチ
  - Zustand, Jotai 等の軽量状態管理で不変性は暗黙的に担保される方向

### 10. Git commit メッセージ規約

- **何を決めるか**: コミットメッセージの形式、自動化との連携
- **選択肢**:
  - **Conventional Commits**: `<type>[optional scope]: <description>` 形式。自動バージョニング・CHANGELOG 生成に対応
  - **独自規約**: プロジェクト固有のプレフィックスや形式
  - **制約なし**: 自由形式（非推奨）
- **選定基準**:
  - 自動化ニーズ：semantic-release, conventional-changelog を使うなら Conventional Commits が前提
  - チーム規模：小規模でも Conventional Commits は初期コストが低く、恩恵が大きい
  - レビューの効率：統一されたフォーマットにより、PR レビュー時の変更意図把握が容易に
- **トレードオフ・注意点**:
  - Conventional Commits の基本 type:
    - `feat`: 新機能追加（minor バージョンアップ）
    - `fix`: バグ修正（patch バージョンアップ）
    - `docs`: ドキュメントのみ変更
    - `style`: コードスタイル変更（フォーマット等。意味の変更なし）
    - `refactor`: リファクタリング（機能変更なし、バグ修正なし）
    - `perf`: パフォーマンス改善
    - `test`: テスト追加・修正
    - `chore`: ビルドプロセス・補助ツールの変更
    - `ci`: CI 設定の変更
  - Breaking change: type の後に `!` を付与、またはフッターに `BREAKING CHANGE:` を記載（major バージョンアップ）
  - subject は命令形（imperative mood）で記述：「Add feature」「Fix bug」（「Added」「Fixed」ではない）
  - subject は72文字以内。body は空行の後に詳細を記述、72文字で折り返し
  - commitlint + husky でコミット時に自動検証。CI でも検証を実施
- **2025-2026年のトレンド**:
  - Conventional Commits が事実上の標準として広く採用。特に OSS プロジェクトでは必須に近い
  - AI コーディングアシスタント（GitHub Copilot, Claude Code）が Conventional Commits 形式のメッセージを自動生成
  - semantic-release + Conventional Commits による完全自動バージョニング・リリースフローの普及
  - commitlint の設定を `@commitlint/config-conventional` で標準化し、カスタマイズは最小限にする方針が主流
  - Squash merge + PR タイトルを Conventional Commits 形式にする運用が GitHub Flow で一般的
