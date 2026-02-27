# フロントエンド設計 決定事項

## 決定事項一覧（サマリテーブル）

| # | 決定項目 | 主な選択肢 | 決定の影響範囲 |
|---|---------|-----------|--------------|
| 1 | 状態管理ライブラリ | Zustand / Jotai / Redux Toolkit / React Context | パフォーマンス、DX、スケーラビリティ |
| 2 | サーバーステート管理 | TanStack Query / SWR / RTK Query | データ取得・キャッシュ・同期戦略 |
| 3 | ルーティング設計 | ファイルベース（Next.js App Router等） / 設定ベース（React Router等） | プロジェクト構造、ナビゲーション体験 |
| 4 | コンポーネント設計パターン | Feature-Sliced Design / Atomic Design / ハイブリッド | コードの組織化、再利用性、保守性 |
| 5 | スタイリング手法 | Tailwind CSS / CSS Modules / vanilla-extract / styled-components | バンドルサイズ、DX、デザインシステム統一性 |
| 6 | UIコンポーネントライブラリ | shadcn/ui / Radix UI / MUI / Mantine / 自作 | 開発速度、カスタマイズ性、a11y |
| 7 | フォームハンドリング | React Hook Form / Formik / 独自実装 | フォームUX、バリデーション統合、パフォーマンス |
| 8 | バリデーションライブラリ | Zod / Valibot / Yup | 型安全性、バンドルサイズ、API連携 |
| 9 | アイコン・アセット管理 | Lucide React / React Icons / SVGスプライト / カスタムアイコンセット | バンドルサイズ、一貫性、保守性 |
| 10 | レイアウト・ページテンプレート設計 | レイアウトコンポーネント / テンプレートパターン / CSS Grid + Flexbox | ページ構造の一貫性、ネスト戦略 |
| 11 | アクセシビリティ（a11y）方針 | WCAG 2.2準拠レベル（A/AA/AAA） | 対象ユーザー範囲、法的要件、テスト戦略 |
| 12 | 国際化（i18n）の採否 | react-i18next / next-intl / 不採用 | 多言語対応、ルーティング、コンテンツ管理 |
| 13 | アニメーション/トランジション方針 | Motion（旧Framer Motion） / CSS Transitions / View Transitions API | UX品質、バンドルサイズ、パフォーマンス |
| 14 | メタデータ・SEO設計 | Next.js Metadata API / react-helmet / 手動管理 | 検索エンジン可視性、OGP、構造化データ |

---

## 各項目の詳細

### 1. 状態管理ライブラリ

- **何を決めるか**: クライアントサイドの状態（UI状態、ユーザー設定、一時データ等）をどのライブラリで管理するか
- **選択肢**:
  - **Zustand**: ~3KB。ストアベースの集中管理。シンプルなAPI、ボイラープレート最小。中〜大規模アプリに最適
  - **Jotai**: ~4KB。アトムベースの分散管理。細粒度のリアクティビティ、不要な再レンダリングを最小化
  - **Redux Toolkit**: ~15KB（react-redux含む）。エコシステム成熟、DevTools充実、大規模チーム向け
  - **React Context + useReducer**: 追加ライブラリ不要。小規模・限定的な状態管理に
- **選定基準**:
  - アプリの状態の複雑さ（単純なUI状態 vs 複雑な相互依存状態）
  - チームの既存知識・学習コスト
  - バンドルサイズの制約
  - DevToolsの必要性
- **トレードオフ・注意点**:
  - Zustandは集中型のため、状態間の関係が明示的だが、巨大なストアになりやすい
  - Jotaiはアトム単位の再レンダリング最適化に優れるが、状態の全体像が把握しにくい
  - Redux Toolkitはエコシステムが最も成熟しているが、小規模アプリにはオーバーヘッド
  - サーバーステート（API取得データ）はサーバーステート管理ライブラリに委譲し、クライアントステートのみを対象とすること
- **2025-2026年のトレンド**:
  - ZustandとJotaiが急成長し、新規プロジェクトではReduxを選ばないケースが増加
  - 「サーバーステートとクライアントステートの分離」が標準的なプラクティスに定着
  - Signals（Preact Signals等）が注目されているが、React公式のSignals対応は未確定
  - Redux Toolkitは大規模エンタープライズでは依然として有力な選択肢

### 2. サーバーステート管理

- **何を決めるか**: APIから取得するデータ（サーバーステート）のフェッチ、キャッシュ、同期、再検証をどのライブラリで管理するか
- **選択肢**:
  - **TanStack Query（React Query）**: 機能最も豊富。DevTools、楽観的更新、オフライン対応、ページネーション、無限スクロール対応
  - **SWR**: Vercel製。軽量（stale-while-revalidate戦略）、Next.jsとの親和性高い、シンプルなAPI
  - **RTK Query**: Redux Toolkitの一部。既にReduxを採用している場合に最適。コード生成対応
- **選定基準**:
  - 状態管理ライブラリとの統合（Reduxを使うならRTK Queryが自然）
  - キャッシュ戦略の複雑さ（楽観的更新、オフラインミューテーション等の要否）
  - DevToolsの充実度の重要性
  - バンドルサイズ（SWRが最軽量）
- **トレードオフ・注意点**:
  - TanStack Queryは機能豊富だが学習曲線がやや急
  - SWRはシンプルだが、複雑なキャッシュ操作（楽観的更新等）の実装が手間
  - RTK Queryはスタンドアロンでは使えず、Redux Toolkitが前提
  - staleTime/cacheTimeの適切な設定がパフォーマンスに直結する
- **2025-2026年のトレンド**:
  - TanStack Queryがデファクトスタンダードの地位を確立。v5でさらに型安全性が向上
  - SWRはVercel/Next.jsエコシステムでの利用が主流
  - Server Components（RSC）との使い分けが重要テーマに。RSCで初期データ取得、TanStack Queryでクライアント側のインタラクティブなデータ管理というパターンが増加

### 3. ルーティング設計

- **何を決めるか**: アプリケーションのページ遷移・URL構造をどのような方式で定義するか
- **選択肢**:
  - **ファイルベースルーティング**: Next.js App Router、Nuxt、Remix等のフレームワーク組み込み。ファイル/ディレクトリ構造がそのままURLに対応
  - **設定ベースルーティング**: React Router、TanStack Router等。コードで明示的にルート定義
- **選定基準**:
  - 採用するフレームワーク（Next.jsならファイルベースが標準）
  - ルーティングの複雑さ（動的ルート、ネストレイアウト、並列ルートの要否）
  - 型安全なルーティングの必要性（TanStack Routerが優位）
- **トレードオフ・注意点**:
  - ファイルベースはディレクトリ構造の可読性が高いが、複雑なルーティングロジックの表現に制約がある
  - 設定ベースは柔軟だが、ルート定義の管理が煩雑になりやすい
  - Next.js App Routerのレイアウトネスト、ローディングUI、エラーバウンダリの自動対応は生産性に大きく寄与
- **2025-2026年のトレンド**:
  - Next.js App Routerのファイルベースルーティングが主流。Parallel Routes、Intercepting Routesなどの高度なパターンも成熟
  - TanStack Routerが型安全性で注目を集めており、設定ベースの選択肢として台頭
  - View Transitions APIとの統合によるページ遷移アニメーションが標準化しつつある

### 4. コンポーネント設計パターン

- **何を決めるか**: コンポーネントの分類・整理の方針。UIの粒度とビジネスロジックの配置ルール
- **選択肢**:
  - **Feature-Sliced Design（FSD）**: 機能単位でスライスし、レイヤー（shared/entities/features/widgets/pages/app）で整理。ビジネスロジックとUIの両方を包含
  - **Atomic Design**: UI粒度で分類（Atoms/Molecules/Organisms/Templates/Pages）。UIコンポーネントの整理に特化
  - **ハイブリッド（推奨）**: 共有UIコンポーネントにAtomic Design、機能モジュールにFeature-basedを適用
  - **Compound Components**: 関連コンポーネントをグループ化し、暗黙的な状態共有を行うパターン（Select + Option等）
- **選定基準**:
  - プロジェクトの規模（小規模ならAtomic Designで十分、大規模ならFSD推奨）
  - ビジネスロジックの複雑さ（複雑ならFeature-basedが必須）
  - チームの分業体制（機能単位の分担ならFeature-basedが有利）
- **トレードオフ・注意点**:
  - Atomic Designのみでは、ビジネスロジックの配置場所が曖昧になりやすい
  - FSDは学習コストが高く、小規模プロジェクトではオーバーヘッド
  - ハイブリッドは柔軟だが、ルールを明文化しないとチーム内で不統一になる
  - Compound Componentsは再利用性が高いが、コンポーネント間の暗黙的依存に注意
- **2025-2026年のトレンド**:
  - Feature-Sliced Designが2025年のフロントエンドアーキテクチャガイドで推奨される5大アーキテクチャの一つに
  - Atomic Design単体の採用は減少傾向。UIライブラリ（shared/ui）の整理方法として部分的に活用
  - 「Atomic Design + Feature Slices」のハイブリッドが現実的なベストプラクティスとして定着

### 5. スタイリング手法

- **何を決めるか**: CSSの記述方法とスタイル管理のアーキテクチャ
- **選択肢**:
  - **Tailwind CSS**: ユーティリティファーストCSS。クラス名でスタイル記述。v4で大幅改善。68%の採用率（2025年）
  - **CSS Modules**: ファイルスコープのCSS。命名衝突なし。フレームワーク非依存
  - **vanilla-extract**: TypeScriptでCSS記述。ビルド時生成でランタイムゼロ。型安全
  - **styled-components / Emotion**: ランタイムCSS-in-JS。2025年以降は非推奨傾向
- **選定基準**:
  - デザインシステムの有無（Tailwindはデザイントークンの統一に強い）
  - パフォーマンス要件（ランタイムCSS-in-JSはSSR/RSCとの相性が悪い）
  - 型安全性の必要性（vanilla-extractが最も型安全）
  - UIコンポーネントライブラリとの互換性（shadcn/uiはTailwind前提）
- **トレードオフ・注意点**:
  - Tailwind CSSはHTML/JSXが冗長になりがちだが、未使用CSS除去で本番バンドルは10KB未満
  - CSS Modulesはシンプルだが、動的スタイリングや条件分岐が煩雑
  - vanilla-extractは型安全だがエコシステムがTailwindほど成熟していない
  - styled-componentsはランタイムオーバーヘッドとRSC非互換が致命的になりつつある
- **2025-2026年のトレンド**:
  - Tailwind CSS v4（2025年リリース）がOxideエンジンで高速化。採用率さらに拡大
  - ランタイムCSS-in-JS（styled-components等）からの脱却が加速
  - ネイティブCSSの進化（Container Queries、CSS Nesting、Cascade Layers）により、素のCSSの実用性が向上
  - Tailwind + CSS Modulesの組み合わせも一つの選択肢として認知

### 6. UIコンポーネントライブラリ

- **何を決めるか**: 既製のUIコンポーネントライブラリを採用するか、採用する場合はどれを選ぶか
- **選択肢**:
  - **shadcn/ui**: コピー&ペースト型。Radix UI + Tailwind CSS。完全なカスタマイズ権限。2025-2026年の最有力
  - **Radix UI**: ヘッドレスUI。スタイルなし、アクセシビリティ完備。自前デザインシステム向け
  - **MUI（Material UI）**: 100+コンポーネント。Material Design。エンタープライズ向け。週間DL 580万
  - **Mantine**: 100+コンポーネント。TypeScript-first。デザインの自由度が高い
  - **不採用（フルスクラッチ）**: 完全なデザインコントロール。開発コスト大
- **選定基準**:
  - カスタマイズ性の要求度（独自デザインが必要か、Material Designで十分か）
  - 開発速度の優先度
  - アクセシビリティ要件（Radix/shadcnはWCAG準拠が組み込み）
  - スタイリング手法との親和性（Tailwind採用ならshadcn/ui一択に近い）
- **トレードオフ・注意点**:
  - shadcn/uiはコード所有型のため、アップデートは手動マージが必要
  - MUIはMaterial Designからの脱却が困難。カスタマイズのtheme overrideが複雑
  - Radix UIはスタイリングが完全に自前のため、初期コストが高い
  - 2025年12月にshadcn/uiがRadix UIとBase UIの選択をサポート開始
- **2025-2026年のトレンド**:
  - shadcn/uiが新規Reactプロジェクトでの第一選択に。CLIによるコンポーネント追加が標準ワークフロー
  - ヘッドレスUI（Radix、Base UI）の採用増加。「ロジック+a11y」と「スタイリング」の分離が設計原則に
  - MUIはエンタープライズ既存プロジェクトでは堅実な選択肢として継続

### 7. フォームハンドリング

- **何を決めるか**: フォームの状態管理、バリデーション統合、送信処理の方式
- **選択肢**:
  - **React Hook Form**: 非制御コンポーネントベース。再レンダリング最小化。Zod/Yup連携。shadcn/ui公式対応
  - **Formik**: 制御コンポーネントベース。成熟しているが、パフォーマンスでRHFに劣る
  - **Conform**: Server Actions対応。プログレッシブエンハンスメント重視
  - **ネイティブフォーム + useActionState**: React 19 / Next.js Server Actions活用
- **選定基準**:
  - フォームの複雑さ（単純な入力 vs 複雑なウィザード形式）
  - バリデーションライブラリとの統合（@hookform/resolversでZod/Valibot対応）
  - UIコンポーネントライブラリとの統合（shadcn/uiはReact Hook Form公式対応）
  - Server Actionsの活用度
- **トレードオフ・注意点**:
  - React Hook FormはControllerラッパーが必要なUIライブラリ（MUI等）で若干煩雑
  - Formikはメンテナンスが低調。新規プロジェクトでは非推奨傾向
  - Server Actions + ネイティブフォームはJS無効環境でも動作するが、リアルタイムバリデーションには不向き
  - watchの多用はパフォーマンス劣化の原因になるため、必要最小限に
- **2025-2026年のトレンド**:
  - React Hook Form + Zodの組み合わせがデファクトスタンダード
  - shadcn/uiの`<Form>`コンポーネントがReact Hook Form + Zodを標準統合
  - Server Actionsとの組み合わせパターンが成熟（クライアント側バリデーション + サーバー側バリデーション）
  - Conform（Server Actions特化）が注目度を上げている

### 8. バリデーションライブラリ

- **何を決めるか**: 入力値・APIレスポンス・環境変数等のランタイムバリデーションに使うライブラリ
- **選択肢**:
  - **Zod**: TypeScript-first。最も普及。エコシステム充実。~17.7KB（esbuild）
  - **Valibot**: モジュラー設計。ツリーシェイキング最適化。~1.37KB（ログインフォーム相当）
  - **Yup**: 成熟。Formikとの統合が歴史的に強い。Zodに比べ型推論が弱い
  - **Zod Mini**: Zodの軽量版。~6.88KB。APIはZodと互換
- **選定基準**:
  - バンドルサイズの制約（モバイル向けならValibot優位）
  - エコシステムの充実度（Zodが最も広い：React Hook Form、tRPC、next-safe-action等）
  - スキーマの複雑さ（大規模スキーマならValibotのパフォーマンス優位）
  - z.inferによる型推論の活用度
- **トレードオフ・注意点**:
  - ZodはバンドルサイズがValibotの約13倍だが、エコシステム統合が圧倒的
  - Valibotはバンドル最小だが、サードパーティ統合が発展途上
  - YupはTypeScript型推論が弱く、新規プロジェクトではZod/Valibotに劣後
  - バリデーションスキーマをフロント・バック共有（monorepo）する場合、Zodの普及度が有利
- **2025-2026年のトレンド**:
  - Zod v4がリリースされ、パフォーマンスがValibot並に改善（ランタイム速度）。ただしバンドルサイズではValibot優位維持
  - Valibot v1が安定し、本番利用が増加。バンドルサイズ重視のプロジェクトで採用
  - 「フォームバリデーション」「APIレスポンスパース」「環境変数バリデーション」のすべてを同一ライブラリで統一するパターンが標準化

### 9. アイコン・アセット管理

- **何を決めるか**: アイコンの提供方法、アセット（画像・フォント等）の管理と最適化方針
- **選択肢**:
  - **Lucide React**: shadcn/uiのデフォルト。1000+アイコン。ツリーシェイキング対応
  - **React Icons**: 複数アイコンセット統合（FontAwesome, Material, Feather等）。便利だがバンドルに注意
  - **SVGスプライト**: カスタムSVGをスプライトシートで管理。完全なコントロール
  - **@iconify/react**: 200+アイコンセット統合。オンデマンドロード対応
- **選定基準**:
  - UIコンポーネントライブラリとの統合（shadcn/ui → Lucide）
  - 必要なアイコン数・種類
  - バンドルサイズ制約（ツリーシェイキングの対応度）
  - カスタムアイコンの有無
- **トレードオフ・注意点**:
  - React Iconsは全アイコンをバンドルに含めやすいため、named importを徹底する
  - SVGスプライトは初期設定コストが高いが、HTTP/2環境では効率的
  - Next.js Image Optimization（next/image）と画像アセットの最適化を合わせて検討
  - フォントの最適化（next/font、サブセット化）も併せて決める
- **2025-2026年のトレンド**:
  - Lucide Reactがshadcn/uiの普及に伴い急成長
  - アイコンのオンデマンドロード（Iconify）が大規模プロジェクトで採用増加
  - SVGをReactコンポーネントとしてインポートするパターン（SVGR）が継続して主流

### 10. レイアウト・ページテンプレート設計

- **何を決めるか**: アプリ全体のレイアウト構造、共通テンプレートの設計方針
- **選択肢**:
  - **Next.js App Router レイアウト**: layout.tsx でネストレイアウト。ルートグループで条件分岐
  - **レイアウトコンポーネント**: Header/Sidebar/Main/Footer等の組み合わせ。手動構成
  - **CSS Grid + Flexbox**: レイアウトシステムをCSS Gridで構築。コンポーネントは薄く
- **選定基準**:
  - フレームワークのレイアウト機能の活用度
  - レイアウトのバリエーション数（認証前/後、管理画面/公開画面等）
  - サイドバー・ヘッダーの状態管理（開閉状態、レスポンシブ対応）
- **トレードオフ・注意点**:
  - Next.js App Routerのlayout.tsxは再レンダリングされない（状態維持）という利点があるが、動的レイアウト切替が制約になる場合がある
  - ルートグループ（(auth), (dashboard)等）でレイアウトを切り替えるパターンを活用
  - レイアウトシフト（CLS）を防ぐため、固定高さのヘッダー・固定幅のサイドバーを検討
  - モバイルとデスクトップでレイアウト構造が大きく異なる場合、条件レンダリングの戦略が必要
- **2025-2026年のトレンド**:
  - Next.js App Routerのレイアウトシステムが成熟。Parallel Routes + Intercepting Routesでモーダル等の高度なUIパターン
  - CSS Container Queriesの活用により、コンポーネント単位のレスポンシブ対応が容易に
  - ダッシュボード向けのレイアウトテンプレート（shadcn/uiのBlocks等）の活用が増加

### 11. アクセシビリティ（a11y）方針

- **何を決めるか**: 準拠するWCAGレベル、テスト方法、開発プロセスへの組み込み方
- **選択肢**:
  - **WCAG 2.2 Level A**: 最低限の準拠。基本的なアクセシビリティ
  - **WCAG 2.2 Level AA（推奨）**: 業界標準。色コントラスト4.5:1、キーボード操作、スクリーンリーダー対応
  - **WCAG 2.2 Level AAA**: 最高レベル。すべてのサイトに適用するのは現実的でない
- **選定基準**:
  - 法的要件（EU: 2025年6月からアクセシビリティ準拠が義務化）
  - 対象ユーザーの範囲
  - 開発コストとのバランス
  - UIコンポーネントライブラリの組み込みa11y対応（Radix/shadcnはWCAG準拠済み）
- **トレードオフ・注意点**:
  - ヘッドレスUIライブラリ（Radix等）の採用で、ARIA属性・キーボードインタラクションの実装コストを大幅削減可能
  - eslint-plugin-jsx-a11yを開発時に導入し、CIで静的チェック
  - Axe DevToolsやLighthouseで定期的な自動テスト
  - スクリーンリーダーテスト（VoiceOver, NVDA）は手動テストが必要
  - カラーコントラスト: 通常テキスト4.5:1、大きいテキスト3:1
- **2025-2026年のトレンド**:
  - WCAG 2.2が基準。WCAG 3.0が策定中（2026年以降にリリース見込み）
  - EU アクセシビリティ指令（2025年6月施行）により、欧州向けサービスはLevel AA準拠が事実上必須
  - 自動テストツール（Axe、Playwright a11y）の統合がCI/CDパイプラインで標準化
  - アクセシブルなAIチャットUI（ストリーミング表示のライブリージョン対応等）が新しいテーマ

### 12. 国際化（i18n）の採否

- **何を決めるか**: 多言語対応を行うか。行う場合、どのライブラリ・アーキテクチャを採用するか
- **選択肢**:
  - **react-i18next**: 汎用React i18n。週間DL 630万。プラグイン豊富（言語検出、遅延読込等）
  - **next-intl**: Next.js特化。SSR/SSGフレンドリー。ルーティング統合
  - **不採用**: 単一言語。将来的に追加する場合の設計指針だけ定めておく
- **選定基準**:
  - ターゲットユーザーの言語・地域
  - 初期リリースで多言語が必要か、将来対応か
  - フレームワークとの統合（Next.jsならnext-intlが自然）
  - 翻訳ワークフロー（開発者が直接翻訳 vs 翻訳管理ツール連携）
- **トレードオフ・注意点**:
  - 後から国際化を追加するコストは高い（テキストのハードコーディング除去等）
  - 不採用の場合でも、日付/数値のフォーマットはIntl APIで地域対応を検討
  - 翻訳キーの命名規約を事前に定めないと、保守コストが増大
  - RTL（右から左）言語対応が必要な場合、レイアウトの論理的プロパティ（logical properties）の採用を検討
- **2025-2026年のトレンド**:
  - next-intlがNext.js App Routerとの統合を深化。Server Components対応も成熟
  - LLMを活用した翻訳ワークフロー（自動翻訳 + 人間レビュー）の導入が増加
  - ICU MessageFormatによる複数形・性別対応が標準的なプラクティスに

### 13. アニメーション/トランジション方針

- **何を決めるか**: UI上のアニメーション・トランジションの実装方法と適用範囲
- **選択肢**:
  - **Motion（旧Framer Motion）**: React向け最有力。宣言的API。レイアウトアニメーション対応。~34KB（LazyMotionで6KB）
  - **CSS Transitions / Animations**: ゼロバンドルコスト。シンプルなトランジション向け
  - **View Transitions API**: ブラウザネイティブ。ページ遷移アニメーション。Next.js統合進行中
  - **GSAP**: 高度なアニメーション。タイムライン制御。ゲーム・マーケティングサイト向け
- **選定基準**:
  - アニメーションの複雑さ（単純なfade/slide vs 複雑なレイアウトアニメーション）
  - バンドルサイズの制約
  - アクセシビリティ（prefers-reduced-motionへの対応）
  - 開発者の学習コスト
- **トレードオフ・注意点**:
  - Motionはバンドルサイズが大きいため、LazyMotionで必要な機能だけロードする
  - CSS Transitionsは低コストだが、enterアニメーション（display:noneからの遷移）の制御が難しい
  - prefers-reduced-motionメディアクエリで、ユーザーの設定に応じてアニメーションを抑制する必要がある
  - パフォーマンス: transform/opacityのみをアニメーションすることでGPU合成を活用
- **2025-2026年のトレンド**:
  - Motion v11（Framer Motionのリブランド）がReact 19 Concurrent Rendering対応を強化
  - View Transitions APIのブラウザサポートが拡大。Chrome/Edgeで安定、Safari/Firefoxも対応進行中
  - CSS Scroll-driven Animationsがネイティブで利用可能に
  - 「意味のあるアニメーションのみ」という設計原則が浸透。過度な装飾アニメーションは忌避傾向

### 14. メタデータ・SEO設計

- **何を決めるか**: ページのメタデータ（title, description, OGP）管理方法と、SEO対応のレベル
- **選択肢**:
  - **Next.js Metadata API**: App Router標準。metadata オブジェクト / generateMetadata関数。Server Component専用
  - **react-helmet / react-helmet-async**: クライアントサイドレンダリング向け。フレームワーク非依存
  - **手動管理**: HTMLテンプレートに直接記述
- **選定基準**:
  - フレームワーク（Next.js App RouterならMetadata APIが最適）
  - 動的メタデータの必要性（ユーザー生成コンテンツのOGP等）
  - SSR/SSGの活用（SEO重視ならSSR/SSGが必須）
  - 個人ツール/社内ツールの場合のSEO必要性
- **トレードオフ・注意点**:
  - 個人ツールでもOGP設定は共有時に有効。最低限のtitle + descriptionは設定推奨
  - Next.js Metadata APIのtitle.templateで「ページ名 | サイト名」パターンを一元管理
  - robots.ts / sitemap.tsを適切に設定し、不要なページのインデックスを防止
  - JSON-LD構造化データは検索結果のリッチスニペットに影響
  - Dynamic OG Images（opengraph-image.tsx）でSNS共有時のビジュアルを自動生成
- **2025-2026年のトレンド**:
  - Next.js Metadata APIが成熟し、metadataBaseを起点とした一元管理が標準
  - Dynamic OG Images生成（Satori/Vercel OG）が標準プラクティスに
  - Core Web VitalsがSEOランキング要因として引き続き重要（LCP, INP, CLS）
  - AI Overview（Google）の台頭により、構造化データの重要性がさらに増加
