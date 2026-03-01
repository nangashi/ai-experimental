# [015/018] HTTPセキュリティヘッダー + Error Boundary

**ブロック**: - Task 002（Next.jsプロジェクト基盤）— Next.jsプロジェクト構造（next.config.js、src/app/）

## 目的

全18タスク中の第15タスク。`next.config.js` へのHTTPセキュリティヘッダー設定（X-Frame-Options: DENY・X-Content-Type-Options: nosniff・Referrer-Policy: strict-origin-when-cross-origin）および Error Boundary（app/error.tsx + app/global-error.tsx）を実装することで、アプリケーションの防御的設定を確立する。

## 受け入れ基準

- [ ] `pnpm build && pnpm start` 後のレスポンスヘッダーに `X-Frame-Options: DENY` が含まれていること
- [ ] `pnpm build && pnpm start` 後のレスポンスヘッダーに `X-Content-Type-Options: nosniff` が含まれていること
- [ ] `pnpm build && pnpm start` 後のレスポンスヘッダーに `Referrer-Policy: strict-origin-when-cross-origin` が含まれていること
- [ ] `src/app/error.tsx` が配置されており、クライアントコンポーネントエラーを捕捉してエラーUI（リセットボタン等）を表示すること
- [ ] `src/app/global-error.tsx` が配置されており、最上位エラー境界として機能すること

## 入力

- `standards.md` §4.5（HTTPセキュリティヘッダー: X-Frame-Options・X-Content-Type-Options・Referrer-Policyの設定値）
- `architecture.md` §9.1（エラーハンドリング方針: Error Boundaryはクライアントコンポーネントの未処理エラーの最終補足に利用）
- `standards.md` §2.1（Error Boundary配置: `app/error.tsx`・`app/global-error.tsx`）
