# OBJ-1: PWA要件の実現容易性 — 評価結果

## 提案した代替案

OBJ-1「PWA要件の実現容易性」を最適化する観点から、以下の代替案を提案する。

- **React（Vite）**: vite-plugin-pwa の最も多くの実績・事例を持つ構成。ドキュメント・サンプル・Stack Overflow の回答が豊富であり、PWA実装で詰まった際の解決情報が最も入手しやすい。Service Worker のカスタマイズ（Workbox設定）についても、React + vite-plugin-pwa の組み合わせでの詳細な実装例が多数存在する。
- **SvelteKit（Vite）**: `@vite-pwa/sveltekit` という専用パッケージが提供されており、SvelteKit のルーティング（file-based routing）と PWA の統合が設計段階から考慮されている。Cloudflare Pages への `@sveltejs/adapter-cloudflare` による公式対応が存在する。また SvelteKit はページ遷移に関する Service Worker のキャッシュ統合（navigation preloading 等）が組み込まれており、PWA体験を向上させるパターンが公式ドキュメントに記載されている。
- **Vue（Vite）**: vite-plugin-pwa が標準で対応しており、React と同様の方法で PWA を構成できる。Vue 公式の実装事例は React に次ぐ規模があり、信頼できる。

## 評価

### React（Vite）

- 評価: ○
- 利点:
  - vite-plugin-pwa との組み合わせ事例が最も豊富。公式サンプル・GitHub Issues・Stack Overflow に実装例が多く、トラブル時の解決情報が入手しやすい。
  - Service Worker のキャッシュ戦略（Workbox のカスタマイズ）についても詳細な実装例が多数存在する。
  - Web Share Target API のエンドポイントは Workers（Hono）側で実装する（C10）ため、フロントエンドでの受け取り処理はルーティングとパラメーター取得のみ。React Router との統合実装例が豊富。
- 欠点:
  - vite-plugin-pwa は Vite ベースの全フレームワークで統一的に動作するため、React 固有の優位性は「情報量」に留まり、実装難易度そのものに大きな差はない。
  - フレームワーク固有のPWA機能（SvelteKit の navigation preloading 等）は持たない。
- 根拠: research.md「観点3」より、vite-plugin-pwa は全 Vite ベースフレームワークを統一サポート。PWA実装の難易度自体はフレームワーク非依存。React は情報量の多さが唯一の実質的優位性。
- CSD依存: S4（vite-plugin-pwa が安定動作する仮定）に依存。S10（Service Worker 実装を vite-plugin-pwa に委譲できる仮定）に依存。いずれも Supposition。

---

### Vue（Vite）

- 評価: ○
- 利点:
  - vite-plugin-pwa との組み合わせ事例が豊富（React に次ぐ規模）。
  - Nuxt が Cloudflare Workers GA に含まれており、Vue エコシステムの Cloudflare サポートは成熟している。
  - Web Share Target API の受け取り処理において、Vue Router との統合実装例が存在する。
- 欠点:
  - React と比較してコミュニティ規模・情報量が少ない分、トラブル時の解決情報が若干少ない。
  - React と同様、フレームワーク固有のPWA機能強化はなく、vite-plugin-pwa の標準機能の範囲での対応になる。
- 根拠: research.md「観点3」より。React との差は情報量の程度差であり、実装難易度に本質的な差はない。Cloudflare Pages への静的デプロイは問題なし（S3）。
- CSD依存: S4、S10 に依存（Supposition）。

---

### Svelte（Vite）/ SvelteKit

- 評価: ○
- 利点:
  - `@vite-pwa/sveltekit` パッケージが SvelteKit 向けに専用設計されており、SvelteKit の SSR ルーティングと PWA の整合性が考慮されている。
  - SvelteKit の navigation preloading など、フレームワーク組み込みの機能が PWA 体験を補完できる。
  - Cloudflare Pages への公式デプロイガイドが存在し（`@sveltejs/adapter-cloudflare`）、PWA + Cloudflare Pages の組み合わせの実績がある。
  - S6（SSR移行の可能性）が現実化した場合、SvelteKit は Cloudflare Pages Functions 対応アダプターが用意されており、PWA構成を維持したまま SSR 移行が可能。
- 欠点:
  - `@vite-pwa/sveltekit` は `vite-plugin-pwa` 本体と別パッケージであり、設定方法・統合手順が異なる。React/Vue と比べると設定の学習コストが若干高い（S4 の「設定方法・統合難易度が異なる可能性」）。
  - SvelteKit 固有の挙動（file-based routing、hooks.server.ts 等）と Service Worker の統合において、React/Vue にはない SvelteKit 特有の考慮事項が発生しうる。
  - Svelte 5 への大規模更新後、vite-pwa/sveltekit との統合事例が Svelte 4 時代より少ない可能性がある（情報の陳腐化リスク）。
- 根拠: research.md「観点3」「観点4」より。`@vite-pwa/sveltekit` は専用設計されているが、設定の複雑さが React/Vue より若干高い。Cloudflare Pages 公式サポートは成熟。
- CSD依存: S4（vite-plugin-pwa / @vite-pwa/sveltekit が安定動作する仮定、「設定方法・統合難易度が異なる可能性がある」と明記）、S10 に依存（Supposition）。

---

### SolidJS（SolidStart）

- 評価: △
- 利点:
  - vite-plugin-pwa は SolidJS（Vite ベース）にも対応しており、基本的な PWA 実装は他フレームワークと同様に可能。
  - Cloudflare Pages への `start-cloudflare-pages` アダプター経由での対応は存在する。
- 欠点:
  - SolidStart は 2.0.0-alpha が開発中であり（D3）、1.x と 2.x の間でのAPIの変化が予想される。PWA 実装に関連するドキュメント・サンプルも 1.x と 2.x が混在するリスクがある。
  - SolidJS のエコシステム規模は React の 1/10〜1/20 程度（research.md「観点1」）。vite-plugin-pwa + SolidJS の組み合わせ事例が少なく、トラブル発生時の解決情報が乏しい。
  - Cloudflare Workers 上での SolidStart サポートは 2025 Q2 時点でベータ段階（research.md「観点2」）。静的出力での Cloudflare Pages デプロイは可能だが、将来的な SSR 移行（S6）での信頼性が不確かである。
  - Web Share Target API の受け取り処理（フロントエンド側のルーティング・UI統合）について、SolidStart 固有の実装例が乏しい。
- 根拠: research.md「観点5」より。基本的な PWA 実装は可能だが、情報不足・移行期によるドキュメント混在・小規模エコシステムが重なり、トラブル発生時のリスクが高い。OBJ-1 の評価の視点「公式または信頼できるPWA実装事例・ドキュメントの充実度」で明確に劣る。
- CSD依存: D3（SolidStart 2.0 の API 変更が学習リソースを陳腐化させる速度が不明、Doubt）に強く依存。S4、S10 にも依存（Supposition）。
