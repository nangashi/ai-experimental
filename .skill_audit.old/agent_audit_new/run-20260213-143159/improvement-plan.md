# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 perspective 自動生成の user_requirements 初期化追加、各種エラーハンドリング改善、中間確認追加 | C-1, I-1, I-2, I-3, I-6, I-7, I-8 |
| 2 | templates/phase1a-variant-generation.md | 修正 | user_requirements 未定義時の処理分岐を明記 | C-1 |
| 3 | SKILL.md | 修正 | Phase 1A/1B の返答簡略化 | I-4 |
| 4 | SKILL.md | 修正 | Phase 2 の返答簡略化 | I-5 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- effectiveness: C-1（user_requirements 生成条件不整合）
- ux: I-1（Phase 6 Step 1 プロンプト選択後の最終確認欠落）
- ux: I-2（Phase 0 パースペクティブ削除時の確認欠落）
- stability: I-3（Phase 0 Step 2 フォールバック検索の失敗時処理が暗黙的）
- effectiveness: I-6（Phase 0 Step 6 検証失敗時のエラー詳細不足）
- ux: I-7（Phase 1A Step 5 新規エージェント定義の自動保存前の確認欠落）
- effectiveness: I-8（proven-techniques.md の初期化処理欠落）

**変更内容**:

#### 変更1: Phase 0 パースペクティブ自動生成 — user_requirements 初期化（C-1対応）
- **場所**: 85-90行（パースペクティブ自動生成 Step 1）
- **現在の記述**:
```markdown
**Step 1: 要件抽出**
- エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を `{user_requirements}` として構成する
- エージェント定義が実質空または不足がある場合: `AskUserQuestion` で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項
```
- **改善後の記述**:
```markdown
**Step 1: 要件抽出**
- `{user_requirements}` を空文字列として初期化する
- エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を抽出し `{user_requirements}` に追加する
- エージェント定義が実質空または不足がある場合: `AskUserQuestion` で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項
```

#### 変更2: Phase 0 パースペクティブ削除時の確認追加（I-2対応）
- **場所**: 78-81行（パースペクティブ自動生成 既存ファイル処理）
- **現在の記述**:
```markdown
既に `.agent_bench/{agent_name}/perspective-source.md` が存在する場合:
- Read で読み込み、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功: 既存ファイルを使用し、自動生成をスキップする
- 検証失敗: 既存ファイルを削除し、自動生成を実行する
```
- **改善後の記述**:
```markdown
既に `.agent_bench/{agent_name}/perspective-source.md` が存在する場合:
- Read で読み込み、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功: 既存ファイルを使用し、自動生成をスキップする
- 検証失敗: `AskUserQuestion` で確認する
  - 提示内容: 「既存ファイルが不完全です（欠落セクション: {セクション名リスト}）。削除して再生成しますか？」
  - 選択肢: 「削除して再生成」「そのまま使用」「中断」
  - 削除して再生成: 既存ファイルを削除し、自動生成を実行する
  - そのまま使用: 既存ファイルを使用し、自動生成をスキップする
  - 中断: エラー出力してスキルを終了する
```

#### 変更3: Phase 0 Step 2 フォールバック検索の失敗時処理明記（I-3対応）
- **場所**: 68行
- **現在の記述**:
```markdown
      - 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する
      - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする
```
- **改善後の記述**:
```markdown
      - 一致した場合: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する
      - 見つかった場合: `.agent_bench/{agent_name}/perspective-source.md` に Write でコピーする
      - 見つからない場合: Step c（パースペクティブ自動生成）に進む
```

#### 変更4: Phase 0 Step 6 検証失敗時のエラー詳細追加（I-6対応）
- **場所**: 130-133行（パースペクティブ自動生成 Step 6）
- **現在の記述**:
```markdown
**Step 6: 検証**
- 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → perspective 解決完了
- 検証失敗 → エラー出力してスキルを終了する
```
- **改善後の記述**:
```markdown
**Step 6: 検証**
- 生成された perspective を Read し、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → perspective 解決完了
- 検証失敗 → エラー出力（欠落セクション一覧: {セクション名リスト}）してスキルを終了する
```

#### 変更5: Phase 0 proven-techniques.md 初期化処理追加（I-8対応）
- **場所**: 134-159行（共通処理の前に新規セクション追加）
- **追加内容**:
```markdown
#### proven-techniques.md の初期化（ファイル不在時のみ）

`.claude/skills/agent_bench_new/proven-techniques.md` を Read で確認する。
- **ファイル不在の場合**: 以下の初期内容を Write で保存する

```markdown
# 実証済みテクニック（エージェント横断）

## 使い方
このファイルは agent_bench_new スキルが自動更新します。エージェント横断で効果が実証されたテクニックを Tier 別に管理します。

## Tier 1: 高効果テクニック（2+ エージェントで実証）
（なし）

## Tier 2: 中効果テクニック（1 エージェントで実証）
（なし）

## Tier 3: 候補テクニック（評価中）
（なし）

## ベースライン構築ガイド
- 指示文は英語で記述する
- テーブル/マトリクス構造を活用する
- perspective の評価スコープに対応するセクション構成を採用する
```

#### 共通処理
```

#### 変更6: Phase 1A Step 5 新規エージェント定義の自動保存条件分岐追加（I-7対応）
- **場所**: Phase 1A セクション（163-179行）の委譲プロンプト修正
- **現在の記述**:
```markdown
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス（存在しない場合は「新規」と指定）
- ...
- エージェント定義が新規作成の場合、またはエージェント定義が既存だが不足している場合:
  - `{user_requirements}`: Phase 0 で収集した要件テキスト（空文字列の場合あり）
```
- **改善後の記述**:
```markdown
パス変数:
- `{agent_path}`: エージェント定義ファイルの絶対パス（存在しない場合は「新規」と指定）
- `{agent_exists}`: エージェント定義ファイルが存在する場合は "true"、存在しない場合は "false"
- ...
- `{user_requirements}`: Phase 0 で収集した要件テキスト（空文字列の場合あり）
```

**重要**: この変更は phase1a-variant-generation.md のテンプレート側で処理分岐を行うため、テンプレート側の修正も必要

#### 変更7: Phase 6 Step 1 プロンプト選択後の最終確認追加（I-1対応）
- **場所**: 330-339行（Phase 6 Step 1 デプロイ処理）
- **現在の記述**:
```markdown
ユーザーの選択に応じて:
- **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
  ```
  以下の手順でプロンプトをデプロイしてください:
  1. Read で {selected_prompt_path} を読み込む
  2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
  3. {agent_path} に Write で上書き保存する
  4. 「デプロイ完了: {agent_path}」とだけ返答する
  ```
- **ベースラインを選択した場合**: 変更なし
```
- **改善後の記述**:
```markdown
ユーザーの選択に応じて:
- **ベースライン以外を選択した場合**:
  1. `AskUserQuestion` で最終確認を行う
     - 提示内容: 「{selected_prompt_name} を {agent_path} にデプロイします（不可逆操作）。実行しますか？」
     - 選択肢: 「実行」「キャンセル」
  2. 「実行」の場合: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
     ```
     以下の手順でプロンプトをデプロイしてください:
     1. Read で {selected_prompt_path} を読み込む
     2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
     3. {agent_path} に Write で上書き保存する
     4. 「デプロイ完了: {agent_path}」とだけ返答する
     ```
  3. 「キャンセル」の場合: デプロイをスキップし、ステップ2（ナレッジ更新）に進む
- **ベースラインを選択した場合**: 変更なし
```

#### 変更8: Phase 1A/1B の返答簡略化（I-4対応）
- **場所**: 179行、201行（Phase 1A/1B の返答処理）
- **現在の記述（Phase 1A）**:
```markdown
サブエージェントの返答をテキスト出力し、Phase 2 へ進む。
```
- **改善後の記述（Phase 1A）**:
```markdown
サブエージェント完了後、「Phase 1A 完了: 3プロンプト生成（ベースライン + 2バリアント）」とテキスト出力し、Phase 2 へ進む。
```
- **現在の記述（Phase 1B）**:
```markdown
サブエージェントの返答をテキスト出力し、次の Phase へ進む。
```
- **改善後の記述（Phase 1B）**:
```markdown
サブエージェント完了後、「Phase 1B 完了: 3プロンプト生成（ベースライン + 2バリアント）」とテキスト出力し、Phase 2 へ進む。
```

#### 変更9: Phase 2 の返答簡略化（I-5対応）
- **場所**: 218行（Phase 2 の返答処理）
- **現在の記述**:
```markdown
サブエージェントの返答をテキスト出力し、Phase 3 へ進む。
```
- **改善後の記述**:
```markdown
サブエージェント完了後、「Phase 2 完了: テスト文書生成（埋め込み問題数: {N}）」とテキスト出力し、Phase 3 へ進む。ここで {N} は answer-key から抽出した問題数。
```

### 2. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: effectiveness: C-1（user_requirements 生成条件不整合）

**変更内容**:

#### 変更1: user_requirements 未定義時の処理分岐追加
- **場所**: 2-9行（Step 1-2）
- **現在の記述**:
```markdown
1. Read で以下のファイルを読み込む:
   - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
   - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
   - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）
2. エージェント定義ファイル {agent_path} を Read で確認する:
   - 存在すれば、その内容をベースライン（比較基準）とする。ただし、{user_requirements} が空文字列でない場合は、エージェント定義の不足部分を補うための追加要件として参照する
   - 存在しなければ: {user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する。アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する
```
- **改善後の記述**:
```markdown
1. Read で以下のファイルを読み込む:
   - {proven_techniques_path} （実証済みテクニック — ベースライン構築ガイドを含む）
   - {approach_catalog_path} （アプローチカタログ — 共通ルール・推奨構成・改善戦略を含む）
   - {perspective_source_path} （パースペクティブ — 評価スコープと問題バンクを含む）
2. エージェント定義ファイル {agent_path} を Read で確認する:
   - `{agent_exists}` が "true" の場合:
     - エージェント定義の内容をベースライン（比較基準）とする
     - `{user_requirements}` が空文字列でない場合は、エージェント定義の不足部分を補うための追加要件として参照する
   - `{agent_exists}` が "false" の場合:
     - `{user_requirements}` を基に、proven-techniques.md の「ベースライン構築ガイド」に従ってベースラインを新規生成する
     - `{user_requirements}` が空文字列の場合: perspective_source_path の「## 評価スコープ」セクションを参照し、評価観点に対応する基本構造を採用する
     - アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する
```

#### 変更2: Step 5 新規エージェント定義の自動保存条件分岐追加（I-7対応）
- **場所**: 12-13行（Step 5）
- **現在の記述**:
```markdown
5. エージェント定義ファイルが存在しなかった場合:
   - ベースラインの内容（Benchmark Metadata コメントを除く）を {agent_path} に Write で保存する（初期デプロイ）
```
- **改善後の記述**:
```markdown
5. `{agent_exists}` が "false" の場合:
   - ベースラインの内容（Benchmark Metadata コメントを除く）を {agent_path} に Write で保存する（初期デプロイ）
```

## 新規作成ファイル
なし

## 削除推奨ファイル
なし

## 実装順序
1. **templates/phase1a-variant-generation.md** — Phase 1A テンプレートの修正（user_requirements 未定義時の処理分岐、agent_exists パラメータ対応）
2. **SKILL.md** — 全ての変更を統合（Phase 0 の user_requirements 初期化、各種エラーハンドリング改善、proven-techniques.md 初期化、Phase 1A パラメータ追加、Phase 1A/1B/2 返答簡略化、Phase 6 最終確認追加）

依存関係:
- テンプレート（1）で参照する `{agent_exists}` パラメータは SKILL.md（2）で定義されるが、テンプレート側の処理分岐ロジックが先に必要
- SKILL.md の Phase 1A セクションがテンプレートの仕様に依存するため、テンプレート修正を先に実施

## 注意事項
- **user_requirements の初期化**: Phase 0 で必ず空文字列として初期化することで、未定義状態を防ぐ
- **agent_exists パラメータ**: Phase 0 で agent_path の読み込み結果に基づき "true"/"false" を設定し、Phase 1A テンプレートに渡す
- **proved-techniques.md の初期化**: Phase 0 で必ずファイル存在を確認し、不在時は初期内容を生成する
- **AskUserQuestion の追加**: I-1（デプロイ最終確認）、I-2（perspective 削除確認）により、不可逆操作前の確認ステップが追加される
- **返答簡略化**: Phase 1A/1B/2 のサブエージェント返答を簡略化することで、親コンテキストの節約を実現する。詳細情報はファイルに保存されているため、親では要約のみ保持
- **エラー詳細の追加**: Phase 0 Step 6（perspective 検証失敗）で欠落セクション一覧を出力することで、デバッグ性を向上
