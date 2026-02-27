# リサーチ結果

## 調査日
2026-02-19

## 調査観点

決定ステートメント（Cloudflare Pages + Workers 上の PWA 用フロントエンドフレームワーク選定）から、時間経過で変化しうる事実として以下の観点を特定した。

1. 主要フロントエンドフレームワーク（React / Vue / Svelte / SolidJS）の現在の人気・普及状況（npm ダウンロード数、コミュニティ規模）
2. Cloudflare Pages / Workers との各フレームワークの互換性・公式サポート状況
3. PWA・Web Share Target API の各フレームワークにおける対応状況
4. Svelte 5 の安定リリース状況と TypeScript サポート
5. SolidJS / SolidStart の安定リリース状況と Cloudflare デプロイ対応

## 調査結果

### 観点1: フレームワーク人気・普及状況

- 検索クエリ: `React vs Vue vs Svelte vs SolidJS 2025 2026 frontend framework comparison npm downloads popularity`
- 主要な知見:
  - React は Stack Overflow Developer Survey で 44.7% の採用率。npm ダウンロード数・求人数ともに最大規模のコミュニティを維持している。
  - Vue.js は採用率 17.6% で 2 位。中規模プロジェクトに適したバランス型フレームワークとして安定した地位を維持。
  - Svelte は採用率 7.2% ながら、State of JS 2024 における「今後も使いたいフレームワーク」（Admired）で 62.4% と最高スコアを記録し、開発者満足度が最も高い。
  - SolidJS は採用率 2% 未満であり、エコシステム・学習リソースの規模において他の主要フレームワークと大きな差がある。
  - 出典: [FrontendTools.tech](https://www.frontendtools.tech/blog/best-frontend-frameworks-2025-comparison), [Calmops JavaScript Framework Comparison](https://calmops.com/programming/javascript/javascript-framework-comparison/)

### 観点2: Cloudflare Pages / Workers との互換性・公式サポート

- 検索クエリ: `Cloudflare Pages frontend framework compatibility Vite SvelteKit SolidStart React 2025`
- 主要な知見:
  - 2025 年 4 月時点で、以下のフレームワークが Cloudflare Workers 上で GA（Generally Available）となった: React Router v7 (Remix), Astro, Hono, Vue.js (Nuxt), SvelteKit。
  - SvelteKit は `@sveltejs/adapter-cloudflare` を追加するだけで Cloudflare Pages に対応できる。Cloudflare 公式ドキュメントにデプロイガイドが存在する。
  - SolidStart は `start-cloudflare-pages` Vite アダプター経由で Cloudflare Pages に対応。Cloudflare Workers 上での SolidStart サポートは 2025 Q2 時点でベータ段階とされていた。
  - React（Vite ベース）は Cloudflare Pages に静的出力として問題なくデプロイ可能。フルスタック利用の場合は React Router v7 (Remix) / OpenNext 経由の Next.js が選択肢となる。
  - Vue.js（Vite ベース）も同様に静的出力としてデプロイ可能。Nuxt が Cloudflare Workers GA に含まれる。
  - 出典: [Cloudflare Pages Framework Guides](https://developers.cloudflare.com/pages/framework-guides/), [Cloudflare Changelog: Full Stack on Workers GA](https://developers.cloudflare.com/changelog/2025-04-08-fullstack-on-workers/), [SvelteKit on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-a-svelte-kit-site/), [SolidStart on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-a-solid-start-site/)

### 観点3: PWA・Web Share Target API 対応状況

- 検索クエリ: `PWA Web Share Target API support React Svelte Vue SolidJS 2025` / `vite-plugin-pwa Web Share Target API manifest configuration 2025`
- 主要な知見:
  - `vite-plugin-pwa` は React / Vue / Svelte / SolidJS を含む全ての Vite ベースフレームワークに対応した統一的な PWA プラグインである。フレームワーク固有の PWA 対応の差はほぼない。
  - SvelteKit 向けには `@vite-pwa/sveltekit` パッケージが別途提供されており、SvelteKit の SSR ルーティングと統合した形で PWA 対応が可能。
  - Web Share Target API の実装は、マニフェストの `share_target` プロパティに `action` エンドポイントを設定し、そのエンドポイントをサーバーサイド（Cloudflare Workers / Pages Functions）で受け取る構成となる。この実装パターンはフレームワーク非依存であり、いずれのフレームワークでも同等に実現できる。
  - vite-plugin-pwa の Issue #133 にて Web Share Target API の Workers 側実装例がドキュメント化の議論として存在している。
  - 出典: [vite-pwa/sveltekit](https://github.com/vite-pwa/sveltekit), [vite-plugin-pwa](https://github.com/vite-pwa/vite-plugin-pwa), [vite-pwa-org](https://vite-pwa-org.netlify.app/guide/)

### 観点4: Svelte 5 の安定リリース・TypeScript サポート

- 検索クエリ: `Svelte 5 release stable learning resources TypeScript support 2025`
- 主要な知見:
  - Svelte 5 は 2024 年末に安定リリース（Stable）済みであり、プロジェクト史上最大の変更を含む地上再構築版。
  - Svelte 5 はネイティブ TypeScript サポートを導入。コンポーネントマークアップ内での TypeScript 記述に前処理不要となった。Svelte CLI の Props・ページパラメーターの型推論も強化された。
  - Svelte 4 との後方互換性はほぼ維持されており、既存コードベースからの移行コストは比較的低い。
  - 2025 年 10 月時点でも継続的にアップデートが行われていることが確認できる（"What's new in Svelte: October 2025"）。
  - 出典: [Svelte 5 is alive](https://svelte.dev/blog/svelte-5-is-alive), [Svelte blog](https://svelte.dev/blog), [MDN TypeScript support in Svelte](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Frameworks_libraries/Svelte_TypeScript)

### 観点5: SolidJS / SolidStart の安定性と Cloudflare 対応

- 検索クエリ: `SolidJS SolidStart stable release Cloudflare deployment 2025 npm weekly downloads`
- 主要な知見:
  - SolidStart 1.0 が 2024 年に正式リリース済み。現在の安定版は 1.2.x（2 ヶ月前に更新）。
  - SolidStart 2.0.0-alpha が 2025 年末〜2026 年初に向けて開発中であり、1.x 系と 2.x 系の間で API の変化が予想される。
  - `solid-js` の npm 週次ダウンロード数は約 108〜149 万件。エコシステム規模は React の 1/10〜1/20 程度。
  - Cloudflare Pages へのデプロイは `start-cloudflare-pages` アダプター経由で対応済み。Cloudflare Workers サポートは 2025 Q2 時点でベータ段階。
  - SolidStart 2.0 への移行期にあるため、学習リソースやコミュニティサポートが 1.x と 2.x で混在するリスクがある。
  - 出典: [SolidStart on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-a-solid-start-site/), [SolidStart 1.0 blog](https://www.solidjs.com/blog/solid-start-the-shape-frameworks-to-come), [SolidStart releases](https://github.com/solidjs/solid-start/releases)

## サマリー

この決定に特に影響する主要な事実（2026-02-19 時点）:

1. **Cloudflare Pages との互換性はいずれのフレームワークでも問題ない**: React（Vite）、Vue（Vite）、SvelteKit（adapter-cloudflare）、SolidStart（start-cloudflare-pages）はすべて公式サポートあり。バックエンド（Hono）との分離構成（静的フロント + Workers API）では、フレームワークの SSR 能力は Cloudflare 互換性の観点ではほぼ差がない。

2. **PWA / Web Share Target API 実装はフレームワーク非依存**: `vite-plugin-pwa` が全 Vite ベースフレームワークを統一的にサポート。Web Share Target の受け取りエンドポイントは Cloudflare Workers（Hono）側で実装するため、フロントエンドフレームワーク選定の決定要因にならない。

3. **Svelte 5 は安定リリース済みで TypeScript サポートが強化された**: Svelte 4 との後方互換性も保たれており、学習コストと TypeScript 統合の観点では成熟した選択肢になっている。

4. **SolidJS は小規模エコシステムかつ SolidStart 2.0 移行期**: 学習目的での採用では、情報不足・コミュニティサポートの薄さがリスクになりうる。1.x→2.0 移行期によるドキュメント混在も懸念点。

5. **React は最大のエコシステムを持つが、フレームワーク採用自体の最新トレンドは多様化**: Svelte は開発者満足度で最高評価を受けており、小規模 PWA での採用事例も増加している。
