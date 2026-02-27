# 代替案一覧

## 採用候補

### ALT-1: React（Vite + React 19）
- 概要: 既存スキルを最大限活用できる最大エコシステムのフレームワーク。Vite ベース SPA として Cloudflare Pages に静的デプロイ。SSR 移行時は React Router v7 / OpenNext 経由が必要
- 提案元: OBJ-1（情報量の多さ）、OBJ-2（既存スキル活用）、OBJ-4（静的デプロイの安定性）、OBJ-5（最大エコシステム・Meta 支援）

### ALT-2: Vue 3（Vite + Vue）
- 概要: React 経験者に学習障壁が低く、Composition API で React hooks に近い開発体験を提供。Nuxt が Cloudflare Workers GA に含まれ、SSR 移行パスも存在
- 提案元: OBJ-1（React に次ぐ事例数）、OBJ-2（React との近似性による低い移行コスト）、OBJ-3（リアクティビティの違いを学べる）、OBJ-5（安定した 3.x 系）

### ALT-3: Svelte 5 / SvelteKit
- 概要: コンパイル時リアクティビティという根本的に異なる設計思想。Svelte 5 の Runes システムで現代的なシグナルパターンを体験可能。`@sveltejs/adapter-cloudflare` による公式 Cloudflare 対応が最も手厚い
- 提案元: OBJ-1（@vite-pwa/sveltekit 専用パッケージ）、OBJ-3（最高の学習価値）、OBJ-4（Cloudflare GA 対応・SSR 移行が最もシームレス）、OBJ-5（高い開発者満足度）

### ALT-4: SolidJS / SolidStart
- 概要: React に似た JSX 構文で仮想 DOM を使わないシグナルベースのリアクティビティ。学習価値は高いが、SolidStart 2.0 移行期によるドキュメント混在リスクとエコシステムの小ささが課題
- 提案元: OBJ-3（シグナルベースのリアクティビティの純粋な実装）

## 除外した代替案

なし（S9 により Preact / Qwik / Lit 等は評価対象外としたが、制約による除外ではなく評価コスト削減のための限定）
