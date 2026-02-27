# リサーチ結果

## 調査日
2026-02-20

## 調査観点

決定ステートメント（シングルユーザーWebアプリの認証・アクセス制御方式の選定）から、以下の時間経過で変化しうる事実を特定した。

1. Cloudflare Access の料金プランと無料枠の条件（価格・ユーザー上限・機能制限）
2. Web Share Target API のブラウザ対応状況（特に POSTリクエスト受信とセッション互換性）
3. Hono JWT ミドルウェアの既知の脆弱性・セキュリティ修正状況
4. Web Share Target API と認証方式（セッション Cookie・認証ヘッダー）の互換性

## 調査結果

### 観点1: Cloudflare Access の料金プランと無料枠

- 検索クエリ: `Cloudflare Zero Trust Access free tier 50 users limit 2025`
- 主要な知見:
  - Cloudflare Zero Trust の無料プランは最大 50 ユーザーまで無償。シングルユーザーアプリであれば無料枠の範囲内に収まる。（出典: [Cloudflare Community - 50 user limit](https://community.cloudflare.com/t/50-user-limit-on-free-plan/546057)）
  - 51 ユーザー目からは Standard プランへの強制切り替えとなり、全席分 $7/シート/月が発生する（51 席で $357/月）。段階課金ではなく全量切り替えの点に注意。（出典: [Cloudflare Community - What happens if I exceed 50 users](https://community.cloudflare.com/t/what-happens-if-i-exceed-50-users/479340)）
  - シングルユーザー用途であれば、ユーザー数制限の問題は発生しない。

### 観点2: Web Share Target API のブラウザ対応状況

- 検索クエリ: `Web Share Target API browser support 2025 2026`
- 主要な知見:
  - Chrome（Android/Desktop）および Edge は Web Share Target API をサポート済み。Safari は iOS/macOS でサポート済み。Firefox は実験的対応（Desktop での PWA インストール非対応のため実質限定的）。（出典: [MDN - share_target](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/share_target)、[Can I use - manifest: share_target](https://caniuse.com/mdn-html_manifest_share_target)）
  - Web Share Target API を使用するには PWA としてインストールされている必要がある。インストール前はシェアターゲットとして登録されない。（出典: [Chrome for Developers - web-share-target](https://developer.chrome.com/docs/capabilities/web-apis/web-share-target)）
  - バイナリデータ（画像等）を含む共有には POST メソッドが必要（multipart/form-data）。テキストのみの共有は GET でも可能。

### 観点3: Web Share Target API POST リクエストと認証（セッション Cookie）の互換性

- 検索クエリ: `Web Share Target API POST request authentication session cookie PWA`
- 主要な知見:
  - Web Share Target API の POST リクエストは通常のフォーム送信と同様に扱われ、ブラウザが保持するセッション Cookie は自動的に付与される。（出典: [MDN - share_target](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/share_target)）
  - iOS Safari ではスタンドアロン（PWA）モードとブラウザモードでセッション・Cookie・LocalStorage が共有されない既知の問題がある。この制約は認証方式の選定に影響しうる。（出典: [Netguru - How to Share Cookie or State Between PWA and Safari](https://www.netguru.com/blog/how-to-share-session-cookie-or-state-between-pwa-in-standalone-mode-and-safari-on-ios)）
  - Authorization ヘッダーを使う JWT Bearer 認証は、ブラウザが自動付与しないため Web Share Target API の POST リクエストとは原則非互換。Cookie ベースのセッション管理または Cloudflare Access のような透過的な認証レイヤーが必要。

### 観点4: Hono JWT ミドルウェアのセキュリティ状況

- 検索クエリ: `Hono JWT middleware security best practices 2025`
- 主要な知見:
  - Hono の JWT ミドルウェアおよび JWK ミドルウェアで、アルゴリズム混同（algorithm confusion）に関する脆弱性が過去に報告されている（GHSA-f67f-6cw9-8mq4、GHSA-3vhc-576x-3qv4）。（出典: [Hono Security Advisory GHSA-f67f-6cw9-8mq4](https://github.com/honojs/hono/security/advisories/GHSA-f67f-6cw9-8mq4)、[GHSA-3vhc-576x-3qv4](https://github.com/honojs/hono/security/advisories/GHSA-3vhc-576x-3qv4)）
  - また、`aud`（Audience）クレームがデフォルトで検証されない問題（GHSA-m732-5p4w-x69g）も報告されており、いずれも最新バージョンで修正済み。最新版へのアップデートが推奨される。
  - 安全な実装には、アルゴリズムの明示指定・シークレットの環境変数管理・`aud` クレームの検証設定が必要。これらは設定ミスが発生しやすい実装上の注意点である。（出典: [Hono JWT Middleware docs](https://hono.dev/docs/middleware/builtin/jwt)）

### 観点5: Basic認証のセキュリティ評価とWeb Share Target API互換性

- 検索クエリ: `Basic authentication security HTTPS Web Share Target API service worker`
- 主要な知見:
  - Basic認証はHTTPS下では通信上の安全性は確保されるが、業界標準としては非推奨。シングルユーザー個人用途では許容される場合もある。
  - Web Share Target APIからのPOSTリクエストにBasic認証のAuthorizationヘッダーを自動付与する標準的な方法がない。サービスワーカーでヘッダーを注入する実装は通常のパターンから外れ、保守性に課題がある。

## サマリー

この決定に特に影響する主要な事実:

1. **Cloudflare Access はシングルユーザーなら無料で利用可能**: 無料枠（50ユーザー上限）の範囲内に収まるため、費用は発生しない。ただし将来マルチユーザー化した場合は $7/シート/月が全席分発生するコスト構造に注意。
2. **Web Share Target API の POST リクエストはセッション Cookie と互換**: ブラウザが保持するセッション Cookie は自動付与されるため、Cookie ベースのセッション管理（または Cloudflare Access のような透過的認証）は互換性がある。Authorization ヘッダーを使う Bearer JWT は非互換。
3. **iOS Safari スタンドアロンモードでの Cookie 共有問題**: iOS 環境でのスタンドアロン PWA はブラウザとセッションが分離される。iOS をターゲットとする場合、初回認証フローの設計に注意が必要。
4. **Hono JWT ミドルウェアには過去に脆弱性**: アルゴリズム混同や Audience 未検証の問題が報告されており、自前実装の場合は最新版使用・適切な設定が必須。設定ミスによるセキュリティリスクが存在する。
5. **Web Share Target API の利用には PWA インストールが前提**: 認証方式の選択に加え、PWA としてのインストール体験を考慮する必要がある。
