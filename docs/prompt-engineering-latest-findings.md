# プロンプトエンジニアリング最新知見 (2025-2026)

汎用的なプロンプトエンジニアリングテクニックの最新研究・実践知見をまとめたドキュメント。

---

## 1. 基本テクニックの有効性再評価

### 1.1 Chain-of-Thought (CoT) の価値低下

Wharton大学の研究 (2025) により、CoTプロンプティングの効果がモデルの進化とともに低下していることが明らかになった。

| モデル種別 | 平均改善 | 完全正答率 | 応答時間増加 |
|-----------|---------|-----------|------------|
| 非推論モデル (GPT-4o-mini等) | +4.4〜13.5% | 混合結果（易問で劣化も） | +35〜600% |
| 推論モデル (o3-mini, o4-mini等) | +2.9〜3.1% | ほぼ変化なし | +20〜80% |
| Gemini Flash 2.5 (推論) | **-3.3%** | 劣化 | 大幅増 |

**重要な発見:**
- CoTは「簡単な問題で本来正答できるものを誤答にする」変動性を導入する
- 推論モデルは内部で既にCoT的処理を行うため、明示的なCoT指示は冗長
- **推奨**: CoTの一律適用を止め、タスクごとに効果を検証する

**有効な場面:**
- 複雑な多段推論が必要なタスク
- 非推論モデルを使う場合
- 柔軟なガイダンス形式（"Think through the design holistically" のように方向性のみ示す）

**逆効果な場面:**
- 剛性的ステップ指定（"Step 1:... Step 2:..."）→ ステップ完了バイアスで探索抑制
- 推論モデルへの適用 → 限界的改善に対して大幅な時間コスト

### 1.2 Few-Shot プロンプティング

Few-shotは依然として最も強力なテクニックの1つだが、重要な条件がある。

**有効な場面:**
- 出力フォーマットの明示が必要なタスク → 精度0%から90%への改善事例あり
- 医療コーディング等の専門分野 → 例示により「完全な失敗から近完璧な出力」へ
- 非推論モデルでの使用

**逆効果な場面:**
- 推論モデル（DeepSeek-R1, OpenAI o1等）→ 5-shot でベースラインより劣化
- 複雑なレビュー・評価タスク → テンプレートバイアスで注意偏向、6例で重大検出率100%→0%
- 例が多すぎる場合 → 2例が最適、それ以上は満足化バイアスのリスク

**ベストプラクティス:**
- ゼロショットで十分な場合はゼロショットを使う（特に推論モデル）
- 例の数は必要最小限（1-2例）
- 文脈的キャリブレーション：タスク難易度に合った例を選択する
- 動的Few-shot：前の出力に基づいて例を適応的に変更する

### 1.3 ロール/ペルソナプロンプティング

2025年の複数の研究で、ロールプロンプティングの効果について厳しい再評価がなされている。

**研究結果サマリ:**
- 4モデルファミリー × 2,410の事実質問テスト → 単純なペルソナは改善なし、時に劣化
- GPT-4-turbo × 2,000のMMLU問題 × 12ペルソナ → 「バカ」ペルソナが「天才」を上回る
- GPT-4レベルのモデルではベースラインとの差がほぼゼロ

**有効な場面:**
- 創作・オープンエンドタスク → トーン・スタイルの制御に有効
- 安全ガードレール設定 → システムプロンプト内での境界設定
- 一貫性検証タスク → パターン照合の視点を強制（+3.0pt）

**非推奨:**
- 正確性が重要なタスク（分類、事実質問）→ 効果なしまたは劣化
- 単純なペルソナ定義（"You are a lawyer"）→ 測定可能な改善なし
- 新しいモデル（GPT-4, Claude 3.5以降）→ 効果が消失

**使う場合の推奨:**
- 詳細かつドメイン固有の記述にする
- LLM生成のペルソナが人間作成のものを上回る
- ExpertPromptingフレームワーク（自動詳細ペルソナ生成）を検討

---

## 2. 高効果テクニック

### 2.1 分解 (Decomposition)

複雑な問題をサブ問題に分解するアプローチは一貫して有効。

- カテゴリ別分解（ドメイン別）→ 安定性最高（SD=0.0）
- 検出と報告の分離 → +2.0〜2.5pt、早期フィルタリング防止
- エージェント的設定での逐次的推論に特に有効

### 2.2 自己批判 (Self-Criticism)

モデルに自身の出力を評価させるメタ認知的アプローチ。

- 外部フィードバックループなしで精度向上
- Self-Consistencyの発展形：複数の推論パスを生成し最も一致する回答を選択
- 2025年のトレンド：推論時コンピュート拡張（複数解生成→多数決）

### 2.3 コンテキスト提供

関連する背景情報の提供は、過小評価されているが極めて効果的。

- 経歴、研究論文、インタラクション履歴の適切な形式・順序での提供
- プロンプトエンジニアリング改善の85%はコンテキスト改善で達成可能（RAGやファインチューニングの前に）

### 2.4 アンサンブル

複数プロンプトの結果を組み合わせることで信頼性を向上。

- ランダムフォレスト的アプローチ
- Self-Consistency: 複数の推論パスから最頻回答を選択 → 算術・常識推論で特に有効
- コスト増加とのトレードオフを考慮

### 2.5 感情的刺激 (EmotionPrompt)

心理学的な感情的手がかりをプロンプトに織り込む手法。

- BIG-Benchタスクで**115%の改善**
- Instruction Inductionで8%の相対的改善
- "Take a deep breath and work on this problem step-by-step" → 汎用ステップバイステップより効果的
- 大規模モデルほど恩恵が大きい

**注意点:**
- ポジティブな感情刺激は正確性・低毒性を向上させるが、追従的行動(sycophancy)も増加
- タスクに応じた使い分け：バグ修正には緊急性、ブレストには興奮、助言には共感
- 最新モデルでは脅迫的表現は無効化されている

---

## 3. 構造化とフォーマット

### 3.1 構造化の逆U字カーブ

構造化の量と性能は逆U字の関係にある。

```
性能
 ↑    カテゴリ分解
 |   /  ＼
 |  /    ＼チェックリスト3-4項目
 | / 軽量    ＼
 |/ ヒント     ＼統合チェックリスト
 +--制約なし--------→ 構造化の量
```

- **最適点**: カテゴリ分解 → 系統性と探索性を両立
- **過剰構造化は一貫して逆効果**: チェックリスト統合(-1.75pt)、厳格カテゴリ(-4.5pt)
- 軽量ヒント2件が最適閾値、3件以上で逆効果

### 3.2 XML vs JSON 構造化出力

| 形式 | 適用場面 | 注意点 |
|------|---------|--------|
| XML | Claude系モデルでのタグ区切り、命令的/ネスト構造 | Claudeモデルはタグ区切りコンテンツの解釈に特に強い |
| JSON | データ抽出、分類、自動化、プログラム連携 | Structured Outputs機能でスキーマ準拠を保証可能 |
| 自然言語 | 推論の質が重要なタスク | フォーマット制約は推論能力を低下させる研究結果あり |

**重要な研究結果**: フォーマット制約が厳しいほど推論能力の低下が大きい。推論精度が最優先なら、まず自然言語で回答させ、後からフォーマット変換する2ステップ（NL-to-Format）アプローチが有効。

### 3.3 明示的指示の重要性（Claude 4.x特有）

Claude 4.xモデルは前世代と異なり、指示を**文字通り**に解釈する。

- 以前のモデル: 曖昧な指示から意図を推測して拡張
- 現行モデル: 要求されたことだけを正確に実行
- **対策**: "above and beyond" な動作を望む場合は明示的に要求する

```
# 効果が低い
Create an analytics dashboard

# 効果が高い
Create an analytics dashboard. Include as many relevant features
and interactions as possible. Go beyond the basics to create
a fully-featured implementation.
```

---

## 4. 推論時コンピュート拡張 (Test-Time Compute Scaling)

2025年の最もホットなトピック。推論時により多くの計算リソースを使い、出力品質を向上させるアプローチ。

### 4.1 2つのスケーリング方式

| 方式 | 説明 | 用途 |
|------|------|------|
| 並列スケーリング | 複数出力を並列生成→集約 | Self-Consistency、Best-of-N |
| 逐次スケーリング | 中間ステップに基づいて後続計算を誘導 | CoT、思考トークン |

### 4.2 主要な手法

- **Budget Forcing**: "Wait"トークンでモデルの思考時間を制御。"think step by step"の現代版
- **Self-Consistency**: 複数回答の多数決 → 算術・常識推論で4倍以上の効率改善
- **Tree of Thought (ToT)**: 分岐する推論パスを探索、評価、バックトラッキング
- **Adaptive Thinking (Claude 4.6)**: モデルがクエリ複雑度に応じて動的に思考量を調整

### 4.3 実用的な知見

- 計算最適スケーリング戦略でBest-of-N比較4倍以上の効率改善
- 14倍大きいモデルをFLOPs一致評価で上回る場合あり
- 単一のTTS戦略が普遍的に優位ではない → タスク難易度と問題タイプに依存

---

## 5. コンテキストエンジニアリング

2025年半ばに台頭した、プロンプトエンジニアリングの進化形。

### 5.1 プロンプトエンジニアリングとの違い

| 観点 | プロンプトエンジニアリング | コンテキストエンジニアリング |
|------|------------------------|------------------------|
| 焦点 | 言葉遣い、構造、テクニック | モデルの作業記憶に何を入れるか |
| 範囲 | 単一インタラクション | 多様なソースからの動的組み立て |
| 構成要素 | プロンプトテキスト | プロンプト + メモリ + RAG + ツール出力 + 構造化出力 + ガードレール |

### 5.2 主要コンポーネント

1. **RAG (Retrieval-Augmented Generation)**: 外部ソースから関連文書を取得してコンテキスト強化
2. **メモリ**: 会話履歴、ユーザー設定、過去のインタラクションの保持
3. **ツール出力**: 外部ツール実行結果の動的注入
4. **構造化出力**: JSON/XMLスキーマ準拠の応答制約
5. **ガードレール**: 安全性・品質の境界設定

### 5.3 設計原則

- **Just-in-Time戦略**: 必要時に動的にロードする（全データを事前ロードしない）
- **ハイブリッドアプローチ**: 基本コンテキストは事前取得 + 追加探索は必要時に実行
- コンテキスト改善がプロンプト改善の85%を占める → まずコンテキストを最適化

---

## 6. 自動プロンプト最適化

人手によるプロンプト設計の限界を超えるための自動化フレームワーク。

### 6.1 主要フレームワーク

| フレームワーク | アプローチ | 特徴 |
|-------------|----------|------|
| DSPy | プログラミングベース | プロンプトでなくコードとしてLLM処理を定義。命令チューニング+例選択の同時最適化 |
| OPRO | LLMによる最適化 | プロンプト最適化をブラックボックス問題として扱い、LLMで候補生成・探索 |
| EvoPrompt | 進化的アルゴリズム | 遺伝的操作で世代を通じてプロンプトを進化させる |

### 6.2 実用上の判断基準

- 手動プロンプトでの改善 → 自動最適化の順序が効率的（"hill climb up quality first"）
- 良い評価メトリクスが定義できる場合に自動最適化が有効
- プロダクション用プロンプト（1日数十万回実行）では投資対効果が高い
- DSPyは5つのユースケース（ガードレール強化、ハルシネーション検出、コード生成、ルーティング、プロンプト評価）で検証済み

---

## 7. セキュリティ：プロンプトインジェクション防御

OWASP 2025 LLMアプリケーション Top 10 で第1位の脆弱性。

### 7.1 多層防御戦略

```
入力ガードレール → コンテンツフィルタリング → LLM処理 → 出力検証 → アクションガード
```

1. **入力ガードレール**: 悪意ある要素の事前検出
2. **コンテンツフィルタリング**: 埋め込みベースの異常検出
3. **階層的システムプロンプト**: 行動契約としての構造化プロンプト
4. **出力検証**: 本来含まれるべきでない情報のスキャン
5. **アクションガード**: 高リスクアクションの動的権限チェック

### 7.2 防御効果

- 多層防御フレームワーク → 攻撃成功率73.2%から8.7%に低減（タスク性能の94.3%を維持）
- ゼロトラスト原則: モデルが見るものは全て信頼しないと仮定

### 7.3 注意点

- 同じLLMを生成とセキュリティ評価の両方に使うと複合脆弱性になる
- 単純な手法（感情操作、タイポ、難読化）は依然として最新モデルを回避可能
- ガードレールだけに依存しない多層防御が必須

---

## 8. Claude 4.x モデル固有のベストプラクティス

Anthropic公式ドキュメントに基づくClaude 4.x（Opus 4.6, Sonnet 4.5, Haiku 4.5）向けの最新知見。

### 8.1 指示の設計

- **明示的に**: 曖昧な指示は避け、望む動作を具体的に記述する
- **コンテキストで理由を提供**: 「省略記号を使うな」ではなく「テキスト読み上げエンジンが処理できないため」と理由を述べる → モデルが汎化する
- **例の整合性に注意**: Claude 4.xは例を厳密に参照するため、促したい行動と例が一致している必要がある

### 8.2 長期推論とステート管理

- Claude 4.xは複数コンテキストウィンドウにわたる作業に優れる
- **構造化フォーマットで状態データを管理**: テスト結果はJSON、進捗メモはフリーテキスト
- **gitで状態追跡**: 作業ログとチェックポイントの自然な管理手段
- **最初のコンテキストウィンドウでフレームワーク構築**: テスト作成、セットアップスクリプト準備

### 8.3 ツール使用の最適化

- Claude 4.xは並列ツール実行に優れる → 独立した操作は並列化を明示
- `<use_parallel_tool_calls>` タグで並列実行を促進
- Opus 4.6はサブエージェント生成の傾向が強い → 単純タスクでの過剰委譲に注意

### 8.4 Adaptive Thinking (Claude 4.6)

- `thinking: {type: "adaptive"}` でクエリ複雑度に応じた動的思考
- `effort` パラメータで思考深度を制御（low, medium, high, max）
- Extended Thinkingより一貫して高性能

### 8.5 過剰エンジニアリング防止

Claude 4.xは追加ファイル作成、不要な抽象化、要求外の柔軟性追加の傾向がある。

```
Avoid over-engineering. Only make changes that are directly requested
or clearly necessary. Keep solutions simple and focused.
```

### 8.6 Prefill廃止への対応 (Claude 4.6)

Claude 4.6から最後のアシスタントターンのプリフィルが非サポートに。代替手法:
- 出力フォーマット制御 → Structured Outputs機能
- 前文排除 → "Respond directly without preamble" の直接指示
- 継続 → ユーザーメッセージに前回の末尾テキストを含める

---

## 9. 一貫して有効な原則

研究・実践を横断して確認された普遍的な原則。

1. **明確さ > 巧みさ**: プロンプト失敗の大半は曖昧さに起因し、モデルの限界ではない
2. **言語一貫性**: 完全英語 or 完全日本語。混合は検出パターンシフトと安定性悪化を引き起こす
3. **コンテキスト最適化が先**: プロンプトテクニックの前に、まず適切な情報をモデルに提供する
4. **科学的反復**: テスト→測定→改善のサイクルを回す。プロンプトをプロダクションコードのように扱う
5. **過剰構造化の回避**: 制約なしベースラインが構造化バリアントを上回る場合がある
6. **テクニックのモデル依存性**: CoT、Few-shot等の効果はモデル世代によって大きく変わる。常に検証する
7. **不確実性の明示許可**: モデルに「わからない」と言う許可を与えることでハルシネーションが減少
8. **「何をしないか」より「何をするか」**: 禁止指示より代替行動の指示が効果的

---

## 参考文献・情報源

### 学術論文・技術レポート
- [The Decreasing Value of Chain of Thought in Prompting - Wharton](https://gail.wharton.upenn.edu/research-and-insights/tech-report-chain-of-thought/)
- [A Comprehensive Taxonomy of Prompt Engineering Techniques - Springer](https://link.springer.com/article/10.1007/s11704-025-50058-z)
- [The Prompt Report: A Systematic Survey (58 techniques) - arXiv](https://arxiv.org/abs/2406.06608)
- [A Systematic Survey of Prompt Engineering in LLMs - arXiv](https://arxiv.org/abs/2402.07927)
- [EmotionPrompt: Leveraging Psychology for LLM Enhancement](https://www.researchgate.net/publication/372583723_EmotionPrompt_Leveraging_Psychology_for_Large_Language_Models_Enhancement_via_Emotional_Stimulus)
- [Scaling LLM Test-Time Compute - OpenReview](https://openreview.net/forum?id=4FWAwZtd2n)
- [The Art of Scaling Test-Time Compute - arXiv](https://arxiv.org/abs/2512.02008)
- [Format Restrictions on LLM Performance - arXiv](https://arxiv.org/html/2408.02442v1)

### 公式ドキュメント・ガイド
- [Claude 4.x Prompting Best Practices - Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices)
- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [IBM Prompt Engineering Guide 2026](https://www.ibm.com/think/prompt-engineering)

### 実践的記事
- [AI Prompt Engineering in 2025: What Works and What Doesn't](https://www.lennysnewsletter.com/p/ai-prompt-engineering-in-2025-sander-schulhoff)
- [Prompt Engineering in 2025: The Latest Best Practices](https://www.news.aakashg.com/p/prompt-engineering)
- [Role Prompting: Does Adding Personas Really Make a Difference?](https://www.prompthub.us/blog/role-prompting-does-adding-personas-to-your-prompts-really-make-a-difference)
- [Context Engineering vs Prompt Engineering - Elastic](https://www.elastic.co/search-labs/blog/context-engineering-vs-prompt-engineering)
- [DSPy: Systematic LLM Prompt Optimization](https://towardsdatascience.com/systematic-llm-prompt-engineering-using-dspy-optimization/)

### セキュリティ
- [OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
- [Securing AI Agents Against Prompt Injection - arXiv](https://arxiv.org/abs/2511.15759)

---

*最終更新: 2026-02-13*
