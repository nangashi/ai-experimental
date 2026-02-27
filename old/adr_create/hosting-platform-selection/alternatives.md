# 代替案一覧

## ALT-1: Cloudflare Pages（FE）+ Cloudflare Workers（BE）

- 提案元: OBJ-1, OBJ-2, OBJ-3, OBJ-4, OBJ-5
- 概要: フロントエンド・バックエンドをともにCloudflareのエッジネットワーク上で統一運用。Pages は静的PWA配信、Workers はエッジランタイムでREST APIを実行。コールドスタートが原理的に発生しにくい。
- 主な特徴: 単一プラットフォーム統一、エッジ実行、月10万リクエスト/日の無料枠
- 主なリスク: Workers は V8 Isolate ベースの独自ランタイム（Node.js 非完全互換）。ベンダーロックインリスクが高い（OBJ-5）。CPU時間制限（無料: 10ms）あり。

## ALT-2: Netlify（FE）+ Render.com 無料枠（BE）

- 提案元: OBJ-1, OBJ-2, OBJ-3, OBJ-4, OBJ-5
- 概要: フロントエンドに Netlify 無料プラン、バックエンドに Render.com 無料枠を組み合わせる分離構成。両者ともGit連携自動デプロイ対応。
- 主な特徴: 標準ランタイム（Node.js/Docker）対応、両プラットフォームとも永続無料枠
- 主なリスク: Render.com 無料枠のスリープ仕様（C7）によるコールドスタート問題。3秒以内要件（C5）との両立が困難。ping回避策は規約リスクあり。

## ALT-3: Vercel（FE）+ Render.com 無料枠（BE）

- 提案元: OBJ-1, OBJ-3, OBJ-4, OBJ-5
- 概要: フロントエンドに Vercel Hobby プラン、バックエンドに Render.com 無料枠を組み合わせる分離構成。広く採用されている構成。
- 主な特徴: Vercel の高速CDN、Render の標準ランタイム対応
- 主なリスク: Vercel Hobby は非商用限定（C6）。D1（商用利用の有無）次第で月$20/ユーザーの有料プランが必要となり、C3（月額0円）と矛盾。Render のコールドスタート問題も同様。

## ALT-4: Cloudflare Pages（FE）+ Render.com 無料枠（BE）

- 提案元: OBJ-3, OBJ-5
- 概要: フロントエンドに Cloudflare Pages、バックエンドに Render.com 無料枠を組み合わせる分離構成。両プラットフォームとも標準技術ベースで、ベンダーロックインリスクが最も低い。
- 主な特徴: プラットフォーム固有API依存が最小、部分移行が容易
- 主なリスク: Render.com のコールドスタート問題は ALT-2/ALT-3 と同様。2プラットフォーム管理の運用負荷。

## ALT-5: Vercel（FE）+ Netlify Functions（BE）

- 提案元: OBJ-2
- 概要: フロントエンドに Vercel、バックエンドに Netlify Functions（AWS Lambda ベースのサーバーレス関数）を組み合わせる構成。スリープ仕様はないがコールドスタートは発生しうる。
- 主な特徴: サーバーレス関数のためスリープなし、Lambda コールドスタートは数百ms〜数秒レベル
- 主なリスク: コールドスタートの不確実性（C5 達成は保証されない）。FE/BE が異なるサービスで構成管理が複雑。D1 による Vercel 利用リスクは ALT-3 と同様。
