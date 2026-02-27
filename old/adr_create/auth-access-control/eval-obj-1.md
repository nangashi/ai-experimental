# OBJ-1: Web Share Target API との互換性 — 評価結果

## 提案した代替案

- **Cloudflare Access（エッジ認証）**: Web Share Target API の POST リクエストはブラウザが保持するセッション Cookie に相当する認証トークン（cf_authorization Cookie）を自動付与する形で動作するため、Authorization ヘッダー不要の透過的な認証レイヤーを提供できる。C7（Authorization ヘッダーの非自動付与）の制約を回避できる唯一のエッジレベル認証方式であり、この目的に最も適している。
- **Cookie ベースのセッション管理（自前実装）**: Web Share Target API からの POST リクエストにはブラウザが保持するセッション Cookie が自動付与されることが research.md 観点3で確認されている。Authorization ヘッダーを使わずにセッション Cookie で認証を行うことで、C7 の制約を満たしながら互換性を確保できる。
- **エンドポイント別ハイブリッド構成（Share Target エンドポイントのみ例外処理）**: Web Share Target API を受け取るエンドポイントのみ認証をバイパスまたは別方式（Cookie/ワンタイムトークン）を適用し、他の API エンドポイントは JWT Bearer 認証を維持する構成。S9（全エンドポイント一律認証の仮定）を崩すことで JWT との共存を実現する。

## 評価

### Cloudflare Access（エッジ認証）

- 評価: ◎
- 利点: cf_authorization Cookie がブラウザに保持され、Web Share Target API の POST リクエスト時にも自動付与される。Workers 側でのカスタム認証処理が不要なため、C7（Authorization ヘッダー非自動付与）の制約を透過的に回避できる。エッジレベルで認証が完結するため、Share Target POST リクエストが Workers に到達する前に認証済みとなる。
- 欠点: D1（iOS Safari スタンドアロン PWA モードでの Cookie 共有問題）の影響を受ける可能性がある。iOS でのスタンドアロン PWA モードとブラウザモードで cf_authorization Cookie が共有されない場合、Share Target からのリクエストが認証エラーになる可能性がある。
- 根拠: research.md 観点3より、Cookie ベースの認証は Web Share Target API の POST リクエストと互換性がある。Cloudflare Access は cf_authorization Cookie を使用するため、この知見が直接適用される。ただし iOS Safari のスタンドアロン/ブラウザ間 Cookie 分離問題（D1）がどの程度 cf_authorization Cookie にも影響するかは未検証（D3 と同様の懸念）。
- CSD依存: D1（iOS Safari スタンドアロン PWA モードでの Cookie 共有問題）、D3（Web Share Target API 経由の POST リクエスト時のセッション Cookie の実際の動作）

---

### Cookie ベースのセッション管理（自前実装）

- 評価: ○
- 利点: research.md 観点3で「Web Share Target API の POST リクエストはブラウザが保持するセッション Cookie を自動付与する」と確認されており、Cookie ベースのセッション管理は原則として互換性がある。Authorization ヘッダーへの依存がないため C7 の制約をクリアできる。
- 欠点: D1（iOS Safari スタンドアロン PWA モードでの Cookie 共有問題）の影響を直接受ける。iOS でのスタンドアロン PWA とブラウザのセッションが分離される場合、初回認証フローの追加実装が必要になる可能性がある。D3（Cloudflare Workers + Hono 環境での実際の Cookie 動作）も未検証であり、Cookie の Secure/SameSite 属性の設定次第では Share Target POST が失敗する可能性がある。
- 根拠: research.md 観点3（MDN の仕様確認）による。ただし iOS Safari の既知問題（D1）と Cloudflare Workers 環境での動作未検証（D3）が残存リスクとして存在するため、◎ではなく ○ と評価する。
- CSD依存: D1（iOS Safari スタンドアロン PWA モードでの Cookie 共有問題）、D3（Web Share Target API 経由の POST リクエスト時のセッション Cookie の実際の動作の未検証）

---

### エンドポイント別ハイブリッド構成（Share Target エンドポイントのみ例外処理）

- 評価: △
- 利点: JWT Bearer 認証を主体としつつ、Web Share Target API を受け取るエンドポイントのみ別の認証手段（Cookie・ワンタイムトークン等）を適用することで、OBJ-1 の要件を技術的には満たせる。Authorization ヘッダーに依存しない特定エンドポイントを設けることで C7 の制約をそのエンドポイントのみ回避できる。
- 欠点: エンドポイント別の認証分岐はアーキテクチャの複雑性を高める。Share Target エンドポイントの例外処理が設定ミスやロジックミスによりセキュリティホールになるリスクがある。また S9（全エンドポイント一律認証の仮定）を崩すことを前提とし、その仮定が確認されていない現時点では条件付きの評価にとどまる。追加実装コストが発生する点で「追加実装コストなしに互換性を確保できるか」という評価の視点を満たさない。
- 根拠: 技術的には実現可能だが、OBJ-1 の評価の視点「追加の実装コスト（ワークアラウンド）なしに互換性を確保できるか」に対して否定的な評価となる。この方式は実装コストが高く、設定ミスリスクも伴う。
- CSD依存: S9（認証は全 API エンドポイントに一律の方式で適用する、という仮定の崩壊が前提）

---

### JWT Bearer 認証（Authorization ヘッダー）

- 評価: ×
- 利点: なし（この目的に対して根本的な非互換性がある）
- 欠点: C7（Web Share Target API の POST リクエストに Authorization ヘッダーはブラウザから自動付与されない）という確実（Certainty）の制約に直接抵触する。Web Share Target API 経由のリクエストはすべて認証エラーとなり、OBJ-1 の要件を満たせない。research.md 観点3でも「Authorization ヘッダーを使う JWT Bearer 認証は、ブラウザが自動付与しないため Web Share Target API の POST リクエストとは原則非互換」と確認されている。
- 根拠: C7（Certainty）および research.md 観点3（MDN・Chrome for Developers の確認）による。Certainty に抵触するため ×。
- CSD依存: なし（C7 という確実な制約に基づく判断）

---

### Basic認証

- 評価: ×
- 利点: なし（この目的に対して根本的な非互換性がある）
- 欠点: research.md 観点5より、Web Share Target API からの POST リクエストに Basic 認証の Authorization ヘッダーを自動付与する標準的な方法がない。C7 と同様の問題が発生する。サービスワーカーでヘッダーを注入する実装は通常のパターンから外れ、保守性に課題がある（実装コストも高い）。
- 根拠: C7（Certainty）および research.md 観点5による。JWT Bearer 認証と同じ根本的な問題（Authorization ヘッダーの非自動付与）を抱えるため ×。
- CSD依存: なし（C7 という確実な制約に基づく判断）
