# リサーチ結果

## 調査日
2026-02-19

## 調査観点

PWA+REST API構成のWebアプリケーションのホスティング基盤選定において、時間経過で変化しうる事実として以下の観点を特定した。

1. フロントエンド（PWA）ホスティングサービスの料金・無料枠・制限（Vercel、Netlify、Cloudflare Pages 等）
2. バックエンド（REST API）ホスティングサービスの料金・無料枠・制限（Railway、Render、Fly.io 等）
3. Render.com 無料枠のスリープ（コールドスタート）挙動の現状
4. 各プラットフォームの商用利用条件・利用規約の制限

## 調査結果

### 観点1: フロントエンド（PWA）ホスティングサービスの料金・無料枠

- 検索クエリ: "Vercel pricing 2025 2026 free tier limits hobby plan changes"、"AWS Amplify Netlify Cloudflare Pages PWA hosting comparison 2025 2026 pricing"
- 主要な知見:
  - **Vercel Hobby プラン（無料）**: 永続的な無料プランとして存在する。ただし**個人・非商用利用に限定**されており、収益を生む用途やビジネス利用は利用規約違反となる。無料枠の関数実行時間は最大60秒、エッジリクエストは月100万件。チームメンバーを追加するには有料プランへのアップグレードが必要。
  - **Vercel Pro プラン**: $20/ユーザー/月。使用量に応じたアドオン課金も発生する。
  - **Netlify**: 無料プランあり。月300ビルドクレジット、カスタムドメイン、SSLが含まれる。
  - **Cloudflare Pages**: 静的サイト・SPAのホスティングで競合。AWS Amplify との比較でコスト優位性が指摘されている。
  - **AWS Amplify**: 使用量ベースの課金体系。コスト上限がないため予算管理が必要。
  - 出典: [Vercel Pricing](https://vercel.com/pricing), [Vercel Hobby Plan](https://vercel.com/docs/plans/hobby), [Vercel Pricing Breakdown](https://flexprice.io/blog/vercel-pricing-breakdown), [Vercel vs Netlify vs Cloudflare Pages](https://www.digitalapplied.com/blog/vercel-vs-netlify-vs-cloudflare-pages-comparison)

### 観点2: バックエンド（REST API）ホスティングサービスの料金・無料枠

- 検索クエリ: "Railway hosting pricing 2025 2026 free tier backend REST API"、"Fly.io pricing 2025 2026 backend hosting free tier REST API"
- 主要な知見:
  - **Railway**: 永続的な無料枠は存在しない。無料枠は30日間のトライアル（$5クレジット）のみ。以降は Hobby プラン $5/月（$5クレジット含む）または Pro プラン $20/月（$20クレジット含む）。小規模プロジェクトはHobbyプランのクレジット内に収まることが多い。使用量ベース課金（メモリ・CPU・ストレージ・egress）。
  - **Fly.io**: 永続的な無料プランなし。使用量ベースの課金。shared CPU 256MB インスタンスは約$0.0027/時間（月約$1.94の連続稼働相当）。2026年1月以降、ボリュームスナップショットストレージへの課金が追加された。
  - **Render.com（無料枠）**: 無料枠でウェブサービスの起動が可能。ただし詳細は観点3で調査。
  - 出典: [Railway Pricing](https://railway.com/pricing), [Railway Pricing 2025](https://www.saaspricepulse.com/tools/railway), [Fly.io Pricing](https://fly.io/pricing/), [Fly.io Resource Pricing](https://fly.io/docs/about/pricing/)

### 観点3: Render.com 無料枠のスリープ（コールドスタート）挙動の現状

- 検索クエリ: "Render.com free tier 2025 2026 sleep cold start backend web service"
- 主要な知見:
  - **スリープ挙動**: 無料枠のウェブサービスは**約15分間の非アクティブ状態でスリープ**に入る。
  - **コールドスタート時間**: スリープ中にリクエストが来ると**約25秒の応答遅延**が発生する。
  - **回避策の存在**: Uptime Robot 等の外部サービスで定期的に ping を送る方法でスリープを回避できるが、これは追加の設定コストを要する。
  - この挙動はREST APIの応答性を要件とするアプリケーションでは実用上の問題となりうる。
  - 出典: [Render Free Tier Slow Initial Load](https://medium.com/@sauravhldr/fix-render-com-free-tier-slow-initial-load-cold-start-problem-using-free-options-and-easy-steps-c0b6c7af8276), [Render Free Tier Infographic](https://www.freetiers.com/directory/render)

### 観点4: 各プラットフォームの商用利用条件・利用規約

- 検索クエリ: "Vercel pricing 2025 2026 free tier limits hobby plan changes"（再参照）
- 主要な知見:
  - **Vercel Hobby プランは非商用限定**: ビジネス目的・収益目的での利用は明示的に禁止されている。商用プロジェクトでは Pro プラン以上が必要。
  - Netlify・Railway・Render は無料枠でも商用利用に明示的な制限があるかは今回の検索では確認できなかった。（各社利用規約の個別確認が必要）
  - 出典: [Vercel Hobby Plan](https://vercel.com/docs/plans/hobby), [Vercel Pricing Breakdown](https://flexprice.io/blog/vercel-pricing-breakdown)

## サマリー

この決定に特に影響する主要な事実（2026年2月時点）:

1. **Vercel の無料枠（Hobby）は非商用プロジェクト限定**: 商用利用の場合は月$20/ユーザー以上の有料プランが必要であり、フロントエンドのコスト計算に直接影響する。
2. **Railway・Fly.io に永続的無料枠は存在しない**: バックエンドホスティングは最低でも月数ドルのコストが発生する。無料での継続運用を前提とした計画は成立しない。
3. **Render.com 無料枠はコールドスタート問題あり**: 約25秒の初回応答遅延はREST APIの実用上の問題となりうる。有料プラン（$7/月〜）では常時稼働が保証される。
4. **フロントエンド・バックエンドを別プラットフォームに分離することが一般的**: Vercel（またはNetlify/Cloudflare Pages）をフロントエンド、Railway（またはRender/Fly.io）をバックエンドとする組み合わせが主流の選択肢。
5. **各プラットフォームの料金体系は頻繁に変化している**: 決定後も定期的に料金・無料枠条件の確認が必要。
