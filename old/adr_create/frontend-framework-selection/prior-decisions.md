# 関連する既存決定

## 関連ADR

### ADR-0001: PWA+REST API構成のホスティング基盤選定
- 決定: Cloudflare Pages（フロントエンド）+ Cloudflare Workers（バックエンド）を採用する
- 今回の議題との関連: フロントエンドのデプロイ先が Cloudflare Pages に確定しているため、採用するフロントエンドフレームワークは Cloudflare Pages との互換性（静的サイトとしてビルド可能であること）を前提とする必要がある。また、バックエンドが Cloudflare Workers + Hono + TypeScript に確定しているため、フロントエンドはそのREST APIと通信する構成を前提とする
- 制約への影響: 今回の決定で確実（Certainty）として扱うべき事項:
  - フロントエンドのビルド成果物は Cloudflare Pages にデプロイ可能な静的ファイル形式（HTML/CSS/JS）であること
  - バックエンドは Cloudflare Workers + Hono + TypeScript（REST API）で確定済みであり、フロントエンドフレームワークの選定対象外
  - ホスティング基盤は Cloudflare Pages で確定済みであり、フロントエンドフレームワークの選定対象外
  - 月額コストは0円（無料ティア内）の制約が引き続き適用される（ADR-0001 の C3 より）
  - シングルユーザー構成であり、大規模スケーリングは不要（ADR-0001 の C4 より）
  - 画面表示3秒以内の要件が引き続き適用される（ADR-0001 の C5 より）

## 関連なし

（ADR-0001 は今回の議題と直接関連するため、関連なしのADRは存在しない）
