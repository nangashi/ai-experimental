# [009/018] ArticleSaveForm + ArticleListPage + ArticleCard UI + E2Eテスト

**ブロック**: - Task 008（記事保存・一覧取得 Server Actions）— saveArticle Server Action、Zodスキーマ、getUnreadArticles/getUnreadCountロジック

## 目的

全18タスク中の第9タスク。`ArticleListPage`（未読一覧・未読件数・蓄積警告）・`ArticleSaveForm`（URL入力・バリデーションエラー・重複警告・タイトル取得失敗通知）・`ArticleCard`（タイトル・日時表示・外部リンク）・Playwrightセットアップ・E2Eテスト（記事保存→一覧表示のエンドツーエンドフロー）・レスポンシブ対応を実装することで、コアユーザーフローを完成させる。

## 受け入れ基準

- [ ] ブラウザからURLを入力→保存→未読一覧に表示されるE2Eフロー（`pnpm playwright test`）がパスすること
- [ ] 未読件数が1件以上の場合に件数が表示され、0件の場合に0が表示されるE2Eシナリオがパスすること
- [ ] 未読件数が20件を超えた場合に蓄積警告メッセージが表示されるE2Eシナリオがパスすること
- [ ] 無効なURL形式・空文字入力時にフォームインラインエラーが表示されるE2Eシナリオがパスすること
- [ ] 重複URLを保存しようとした場合に重複警告メッセージが表示されるE2Eシナリオがパスすること
- [ ] タイトル取得失敗時にインライン通知「タイトルを取得できませんでした（URLで保存しました）」が表示されること
- [ ] `ArticleCard` の外部リンクに `rel="noopener noreferrer"` が付与されていること
- [ ] スマートフォン・PC両ブラウザでレイアウトが崩れずに表示されること（モバイルファースト）
- [ ] `playwright.config.ts` が配置され、E2Eテスト基盤が整備されていること

> **規模に関する注記**: 本タスクは3つのUIコンポーネント + Playwrightセットアップ + E2Eテストを含み推定10+ファイルとなるが、コアデータパスのUI層を一括で検証可能とするため意図的に統合している（QG-1 warning認識済み）。

## 入力

- `detailed-design.md` §3.3（Server Componentデータ契約: ArticleListPage・ArticleSaveForm・ArticleCard）
- `architecture.md` §5.1（コンポーネント一覧: ArticleListPage・ArticleSaveForm・ArticleCard・ArticleCardActionsの責務）
- `standards.md` §3.1（コンポーネント設計パターン: Server Componentデフォルト・Client Componentは最小限）
- `standards.md` §4.3（XSS対策: `rel="noopener noreferrer"` 付与）
- `standards.md` §6.5（レスポンシブ設計: モバイルファースト・Tailwindブレイクポイント）
- `standards.md` §6.6（タッチ・マウス両立: 最小タッチターゲット44px）
- `development-process.md` §2.2（テストフレームワーク: Playwright E2E）
- `development-process.md` §2.4（E2Eテストファイル配置: `e2e/` ディレクトリ）
