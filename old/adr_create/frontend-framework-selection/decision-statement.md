# 決定ステートメント

## 議題
Cloudflare Pages + Cloudflare Workers（Hono+TypeScript）構成のリーディングリスト管理PWAにおいて、フロントエンドフレームワークとしてどの技術を採用するか

## スコープ
- 対象: フロントエンドのUIフレームワーク/ライブラリの選定。PWA対応（Web Share Target API含む）、レスポンシブ対応（Android+PC）、Cloudflare Pagesとの互換性、学習目的としての適性を評価する
- 対象外: バックエンド技術（Cloudflare Workers + Hono + TypeScript で確定済み — ADR-0001）、ホスティング基盤（Cloudflare Pages で確定済み — ADR-0001）、CSSフレームワーク/UIコンポーネントライブラリ、データベース選定、認証方式

## 可逆性
medium
フレームワーク変更はUIコード全体の書き直しが必要だが、バックエンドAPI（Hono）には影響しない。初期段階（CRUD UIが小規模）での変更コストは比較的低い。
