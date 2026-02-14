# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 4-6, Phase 5-6 の処理追加・明確化 | I-1, I-2, I-3 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）

#### 変更1: Phase 0 Step 4 批評エージェント返答処理の明示化
**対応フィードバック**: I-1: Phase 0 Step 4 批評エージェント返答処理 [architecture]

**変更内容**:
- **変更箇所**: L103-104（Step 4 の直後）
- **現在の記述**:
```
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

**Step 5: フィードバック統合・再生成**
```
- **改善後の記述**:
```
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

4つのサブエージェントの返答を受信し、各返答から「### 有効性批評結果」（または対応する批評結果セクション）を抽出する。各批評結果は以下の構造を持つ:
- 重大な問題（観点の根本的な再設計が必要）
- 改善提案（品質向上に有効）
- 確認（良い点）

**Step 5: フィードバック統合・再生成**
```

#### 変更2: Phase 0 Step 6 perspective.md 保存処理の追加
**対応フィードバック**: I-2: Phase 0 perspective 自動生成の perspective.md 保存処理 [effectiveness]

**変更内容**:
- **変更箇所**: L104-107（Step 5 の後）
- **現在の記述**:
```
**Step 5: フィードバック統合・再生成**
- 4件の批評から「重大な問題」セクションを抽出し、1件以上の重大な問題がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
- 重大な問題が0件の場合: 現行 perspective を維持する（改善提案のみでは再生成しない）
```
- **改善後の記述**:
```
**Step 5: フィードバック統合・再生成**
- 4件の批評から「重大な問題」セクションを抽出し、1件以上の重大な問題がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
- 重大な問題が0件の場合: 現行 perspective を維持する（改善提案のみでは再生成しない）

**Step 6: perspective.md の保存**
- perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_bench/{agent_name}/perspective.md` に Write で保存する（作業コピー。Phase 4 採点バイアス防止のため問題バンクは含めない）
```

**補足説明**: L58-60に既に同じ処理の記述があるが、それは「検索で見つかった場合」のパスであり、自動生成パス（Step 1-6）の完了後にも同じ処理が必要であることを明示する。

#### 変更3: Phase 5 と Phase 6 の間にプロンプト変数抽出処理を追加
**対応フィードバック**: I-3: Phase 6 Step 2 のプロンプト変数抽出処理 [effectiveness]

**変更内容**:
- **変更箇所**: L277-281（Phase 5 の終了後、Phase 6 の開始前）
- **現在の記述**:
```
サブエージェント完了後、サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。Phase 6 へ進む。

---

### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

#### ステップ1: プロンプト選択とデプロイ
```
- **改善後の記述**:
```
サブエージェント完了後、サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。

7行サマリから以下の変数を抽出する:
- `recommended`: 行頭が "recommended: " の行から値を取得
- `reason`: 行頭が "reason: " の行から値を取得
- `convergence`: 行頭が "convergence: " の行から値を取得
- `scores`: 行頭が "scores: " の行から値を取得
- `variants`: 行頭が "variants: " の行から値を取得
- `deploy_info`: 行頭が "deploy_info: " の行から値を取得
- `user_summary`: 行頭が "user_summary: " の行から値を取得

Phase 6 へ進む。

---

### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

#### ステップ1: プロンプト選択とデプロイ
```

#### 変更4: Phase 6 Step 2A での変数参照の明確化
**対応フィードバック**: I-3: Phase 6 Step 2 のプロンプト変数抽出処理 [effectiveness]

**変更内容**:
- **変更箇所**: L322-327（Phase 6 Step 2A のパス変数定義）
- **現在の記述**:
```
`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason
```
- **改善後の記述**:
```
`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
- `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- `{recommended_name}`: Phase 5 と Phase 6 の間で抽出した `recommended` 変数の値
- `{judgment_reason}`: Phase 5 と Phase 6 の間で抽出した `reason` 変数の値
```

## 新規作成ファイル

（なし）

## 削除推奨ファイル

（なし）

## 実装順序

1. **SKILL.md の変更1**: Phase 0 Step 4 の批評結果受信・抽出処理を明示化
   - 理由: 後続のステップ（Step 5）で批評結果を参照するため、先に受信処理を明確にする必要がある

2. **SKILL.md の変更2**: Phase 0 Step 6 の perspective.md 保存処理を追加
   - 理由: 自動生成パスの完了処理を明確にする（変更1と独立だが、Phase 0 内の処理なので順序に従う）

3. **SKILL.md の変更3**: Phase 5 と Phase 6 の間に7行サマリのパース処理を追加
   - 理由: Phase 6 で使用する変数の導出方法を明示する（変更4で参照される）

4. **SKILL.md の変更4**: Phase 6 Step 2A のパス変数定義を更新
   - 理由: 変更3で定義された変数の参照方法を明確にする（変更3に依存）

## 注意事項

- 変更によって既存のワークフローが壊れないこと
  - Phase 0 の Step 4-6 の処理追加は既存フローを補完するもので、動作変更はない
  - Phase 5-6 間のパース処理追加は既存の暗黙的動作を明示化するもので、実装上の変更はない
- すべての変更は SKILL.md 内で完結し、テンプレートファイルやその他のファイルへの変更は不要
- 変更箇所は互いに独立しており、並行して適用可能（ただし実装順序に従うことを推奨）
