# OBJ-4: Cloudflare Pagesとの統合安定性 — 評価結果

## 提案した代替案

- **React (Vite)**: Viteベースの標準SPAとしてCloudflare Pagesに静的出力デプロイが可能。公式ガイドが存在し、最も実績のある構成。SSR移行が必要になった場合はReact Router v7 (Remix) または OpenNext経由のNext.jsが選択肢となるが、現在のVite+HonoのAPI分離構成からの移行コストは大きい
- **SvelteKit (Svelte)**: `@sveltejs/adapter-cloudflare` を追加するだけでCloudflare Pages対応が完結し、SSR移行も同一フレームワーク内で可能。2025年4月にCloudflare Workers上でGA認定を取得しており、Cloudflare公式の公認フレームワーク群に含まれる点でこの目的に最も特化した選択肢

## 評価

### React (Vite)

- 評価: ○
- 利点:
  - ViteベースSPAとしてCloudflare Pagesへの静的デプロイが完全に確立されている。公式ドキュメント・コミュニティ事例ともに豊富で、デプロイ失敗リスクが最も低い
  - ビルド設定は `vite.config.ts` のみで完結し、追加アダプターは不要。設定の複雑さが最小限
  - 現時点の構成（静的SPA + Hono API分離）においてアダプター依存がなく、将来のCloudflare側仕様変更への影響を受けにくい
- 欠点:
  - SSR移行が必要になった場合、React単体ではCloudflare Pages Functionsとの統合経路が明確でない。React Router v7 (Remix) またはNext.js (OpenNext) への移行が必要となり、フレームワーク自体の変更を伴う
  - Cloudflare WorkersのGA対応フレームワーク一覧（2025年4月）に「React」単体は含まれていない（React Router v7/Remixとして含まれる）。フルスタック移行時の選択肢が間接的
- 根拠: research.mdの観点2より「React (Vite) は Cloudflare Pages に静的出力として問題なくデプロイ可能」が確認済み。SSRへの移行経路は間接的（React Router v7/OpenNext経由）
- CSD依存: S6（静的出力前提だがSSR移行は可能、という仮定）に依存。S6が崩れてSSRが不要であれば◎に格上げされる。逆にSSRが早期に必要になれば△に格下げされうる

---

### Vue.js (Vite)

- 評価: ○
- 利点:
  - ViteベースSPAとしてCloudflare Pagesへの静的デプロイが確立済み。ReactのVite構成と同等の安定性
  - SSR移行が必要になった場合、Nuxtが2025年4月のCloudflare Workers GA対応フレームワークに含まれており、同一エコシステム（Vue → Nuxt）内でSSR移行が可能
  - ビルド設定の複雑さはReact (Vite) と同等で最小限
- 欠点:
  - VuetifyなどのUI連携でSSRを採用する場合のCloudflare Workers対応は、Nuxtへの移行が前提であり、Nuxt固有の学習コストが追加発生する
  - Cloudflare固有の設定（例: Node.js互換性フラグ）が必要になるケースがある（Nuxt利用時）
- 根拠: research.mdの観点2より「Vue.js (Vite) も同様に静的出力としてデプロイ可能。NuxtがCloudflare Workers GAに含まれる」が確認済み
- CSD依存: S6（SSR移行の可能性）に依存。SSR不要であればReactと同等の◎相当だが、移行経路の存在（Nuxt → GA）はReactより明確

---

### Svelte (SvelteKit)

- 評価: ◎
- 利点:
  - `@sveltejs/adapter-cloudflare` を追加するだけでCloudflare Pages対応が完結する。Cloudflare公式ドキュメントに「Deploy a SvelteKit site」ガイドが存在し、公式サポートが最も手厚い
  - SvelteKitは2025年4月のCloudflare Workers GA対応フレームワーク一覧に正式に含まれており、Cloudflareとの統合が公認されている
  - SSR移行が必要になった場合もアダプターを変更するだけで同一フレームワーク内で対応可能。フレームワーク変更が不要で移行コストが最小
  - 静的出力（`adapter-static`）とSSR（`adapter-cloudflare`）を同一コードベースで切り替えられる柔軟性がある
- 欠点:
  - SvelteKit専用のビルド設定が必要（`svelte.config.js` + `vite.config.ts`）。React/VueのViteのみ構成と比べてファイル数が増える
  - アダプターへの依存が生まれるため、アダプター側でCloudflare仕様変更が吸収されない場合、Svelte/Cloudflare両コミュニティの対応を待つ必要がある
- 根拠: research.mdの観点2より「SvelteKit は `@sveltejs/adapter-cloudflare` を追加するだけで Cloudflare Pages に対応できる。Cloudflare 公式ドキュメントにデプロイガイドが存在する」「SvelteKit は Cloudflare Workers 上で GA」が確認済み
- CSD依存: S3（SvelteKitがViteベースでCloudflare Pages対応済み）、S6（SSR移行時のPages Functions対応）。いずれも現時点で検証済みであり依存リスクは低い

---

### SolidJS (SolidStart)

- 評価: △
- 利点:
  - `start-cloudflare-pages` アダプター経由でCloudflare Pagesへのデプロイが公式サポートされており、Cloudflare公式ドキュメントにデプロイガイドが存在する
  - SolidStartはメタフレームワークとして設計されており、アダプターによるSSR/静的出力の切り替えが可能
- 欠点:
  - Cloudflare Workers上でのSolidStartサポートは2025年Q2時点でベータ段階。SSR移行のオプションとして不安定な状態にある
  - SolidStart 2.0.0-alphaが開発中であり、1.x系のアダプター構成が2.0系で変化する可能性がある。安定性の観点でリスクが高い
  - 2025年4月のCloudflare Workers GA対応フレームワーク一覧にSolidStartは含まれていない（他の主要フレームワークに比べてCloudflare統合の公認度が低い）
  - アクティブな移行期（SolidStart 1.x → 2.0）にあるため、ビルド設定・アダプター設定が将来変更される可能性が高い
- 根拠: research.mdの観点5より「Cloudflare Pages へのデプロイは `start-cloudflare-pages` アダプター経由で対応済み。Cloudflare Workers サポートは 2025 Q2 時点でベータ段階」「SolidStart 2.0.0-alpha が 2025 年末〜2026 年初に向けて開発中」が確認済み
- CSD依存: D3（SolidStart 2.0 の API 変更速度が不明）に直接依存。D3のリスクがこの目的においても具体化しうる。S5（メジャーバージョンが安定しているという仮定）に依存しており、SolidStartにおいてはこの仮定が成立しない可能性が高い
