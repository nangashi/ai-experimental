# 代替案一覧

## 採用候補

### ALT-1: Cloudflare Access（Zero Trust エッジ認証）
- 概要: Cloudflare Zero Trust の認証レイヤーを Workers の前段に配置。IdP（GitHub・Google等）経由で認証し、cf_authorization Cookie で透過的にセッション管理。Workers 側に認証コードを書かない。
- 提案元: OBJ-1（Web Share Target 互換性）、OBJ-2（セキュリティ強度）、OBJ-3（実装簡潔さ）で最有力として提案

### ALT-2: Cookie セッション + Workers KV（ステートフル）
- 概要: Hono カスタムミドルウェアでセッション管理を自前実装。セッションIDを HttpOnly/Secure/SameSite=Strict Cookie で発行し、Workers KV にセッション情報を保存。即時ログアウト・セッション無効化が可能。
- 提案元: OBJ-1（Cookie 互換性）、OBJ-2（Cookie 属性によるセキュリティ）、OBJ-3（Workers 完結型実装）で提案

### ALT-3: 署名付き Cookie / JWT in Cookie（ステートレス）
- 概要: JWT を Cookie として保持し、Hono JWT ミドルウェアで Workers 内完結の署名検証を行うステートレス方式。Workers KV 不要。Workers Secrets にシークレットを保存。
- 提案元: OBJ-4（最小レイテンシ）、OBJ-5（コスト持続可能性）で最有力として提案

## 除外した代替案
- JWT Bearer 認証（Authorization ヘッダー）: 除外理由 — C7（Web Share Target POST で Authorization ヘッダー非自動付与）に直接抵触。OBJ-1 で × 評価。
- Basic 認証: 除外理由 — C7 と同様の問題（Authorization ヘッダー非互換）。OBJ-1 で ×、OBJ-2 で × 評価。業界非推奨。
- エンドポイント別ハイブリッド構成: 除外理由 — 実装複雑性が高く、他の方式（ALT-1〜3）で Web Share Target 互換性を確保可能。OBJ-1 で △ 評価。
