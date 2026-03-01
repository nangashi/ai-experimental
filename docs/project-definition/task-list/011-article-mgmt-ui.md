# [011/018] ArticleCardActions UI + 既読一覧タブ + E2Eテスト

**ブロック**: - Task 009（コアUI + E2E）— ArticleListPage・ArticleCard・Playwrightセットアップ
- Task 010（記事管理 Server Actions）— markAsRead/markAsUnread/deleteArticle Server Actions、getReadArticlesロジック

## 目的

全18タスク中の第11タスク。`ArticleCardActions`（Client Component: 既読化・未読戻し・削除ボタン）・`ArticleListPage` への既読一覧タブ切替機能追加・E2Eテスト（既読化→未読一覧から除外→既読一覧に表示、未読戻し、削除のフロー）を実装することで、記事状態管理のUIフロー全体を完成させる。

## 受け入れ基準

- [ ] 記事の既読化ボタンを押す→未読一覧から消える→既読一覧タブに表示されるE2Eフローがパスすること
- [ ] 既読一覧の記事に対して未読戻しボタンを押す→未読一覧に復帰するE2Eフローがパスすること
- [ ] 削除ボタンを押す→一覧から消えるE2Eフローがパスすること
- [ ] `ArticleCardActions` が `src/components/article-card-actions.tsx` に配置され、`"use client"` 指定のClient Componentとして実装されていること
- [ ] `ArticleListPage` に未読一覧・既読一覧のタブ切替UIが追加されていること

## 入力

- `detailed-design.md` §3.3（Server Componentデータ契約: ArticleListPageのデータ入力=デフォルト未読一覧・タブ切替で既読一覧、ソースServiceメソッド=getUnreadArticles・getReadArticles・getUnreadCount）
- `detailed-design.md` §3.1（markAsRead・markAsUnread・deleteArticle Server Action仕様: トリガー元=ArticleCardActions）
- `architecture.md` §5.1（ArticleCardの責務: ArticleCardActionsをClient Componentとして切り出し・コールバックprops設計、ArticleListPageの責務: 未読/既読一覧の表示）
- `architecture.md` §5.2（コンポーネント間依存関係: ArticleCard・ArticleListPage・Server Actions）
- `standards.md` §3.1（コンポーネント設計パターン: ArticleCard=Server Component・ArticleCardActions=Client Component・コールバックprops経由の操作受渡し）
- `standards.md` §6.1（アイコン・アセット管理: Lucide React使用）
- `development-process.md` §2.2（テストフレームワーク: Playwright E2E）
- `development-process.md` §2.4（E2Eテストファイル配置: `e2e/` ディレクトリ）
