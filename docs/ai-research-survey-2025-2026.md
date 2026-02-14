# AI関連研究サーベイ (2025-2026)

Web上のAI関連記事・研究を広く収集し、Claude Codeの行動変容に繋がる有用性の高い情報を特定したレポート。

**調査日**: 2026-02-14
**調査範囲**: AI coding agents, prompt engineering, multi-agent systems, AI development workflow, LLM evaluation
**フィルタ基準**: (1) AIの訓練データに含まれる公知情報を除外 (2) 既存knowledge (`prompt-engineering-findings.md`, `agent-utilization-guide.md`) と重複する情報を除外 (3) 具体的な行動変容に繋がらない情報を除外

---

## 有用性評価サマリ

全調査結果から、既存knowledgeとの重複・AI既知情報を除外した上で有用性を評価した。

| # | 知見 | 新規性 | 行動変容への影響 | 定量エビデンス | knowledge化推奨 |
|---|------|--------|----------------|--------------|----------------|
| 1 | マルチターン性能劣化の4つの原因と対策 | 高 | 非常に高 | 39%低下、4原因を分解 | 強く推奨 |
| 2 | LLM-as-Judge の12種のバイアス | 高 | 非常に高 | ルブリック順序・スコアIDで独立にバイアス | 強く推奨 |
| 3 | CoT忠実性の定量データ | 高 | 高 | 不忠実CoTは長い(2064 vs 1439トークン) | 推奨 |
| 4 | 推論強化がキャリブレーションを悪化させる | 高 | 高 | 84.3%のシナリオで過信 | 推奨 |
| 5 | エージェントのエラーカスケード | 高 | 高 | 複雑なアーキテクチャほど増幅 | 推奨 |
| 6 | Context Rot の位置依存性 | 中 | 高 | 位置1: 75%精度、位置10: 55% | 推奨(既存知見の拡張) |
| 7 | マルチエージェントのトークンオーバーヘッド詳細 | 中 | 高 | 1.6x〜6.2x、skill library化で54%削減 | 推奨(既存知見の拡張) |
| 8 | Sycophancy対策: 匿名化と批判的評価フレーミング | 中 | 高 | 匿名化でidentity-driven sycophancyをほぼ排除 | 推奨(既存知見の拡張) |
| 9 | ACE: grow-and-refine原則 | 高 | 中〜高 | +10.6%(エージェントタスク) | 検討 |
| 10 | AI生成PRの失敗パターン | 高 | 中 | 33k PR分析 | 検討 |
| 11 | CWE指定でセキュアコード生成率向上 | 高 | 中 | 56%→69%(+13pp) | 検討 |
| 12 | 7つの運用障害モード | 中 | 中 | 分類と対策が体系化 | 検討 |
| 13 | CLAUDE.mdの最小化原則 | 中 | 中 | Anthropic公式推奨 | 検討 |

---

## 知見詳細

### 1. マルチターン性能劣化の4つの原因と対策

**出典**: [LLMs Get Lost in Multi-Turn Conversation](https://arxiv.org/abs/2505.06120) (Microsoft Research + Salesforce, 2025/05), [Intent Mismatch Causes LLMs to Get Lost](https://arxiv.org/html/2602.07338v1) (2026/02)

200,000+のシミュレーション会話に基づく大規模研究。シングルターンからマルチターンへの移行で**平均39%の性能低下**が発生。この低下は「能力の低下(-15%)」と「信頼性の悪化(+112%)」に分解される。

**4つの原因**:
1. **早期解決試行 (Premature solution attempts)**: 要件が揃う前に仮定を置いて完全な回答を生成してしまう
2. **回答アンカリング (Answer anchoring)**: 過去の（誤っている可能性のある）回答に過度に依存し、肥大化した回答を生成
3. **中間ターン忘却 (Loss-of-middle-turns)**: 最初と最後のターンを過度に重視し、中間のターンを軽視
4. **冗長性カスケード (Verbosity cascade)**: 回答が次第に冗長化し、仮定がユーザーの発言を圧倒

**対策 — Concat-and-Retry**: マルチターンで蓄積した情報を統合し、クリーンな単一プロンプトとして新鮮なインスタンスに送信。これにより精度が90%超に回復し、シングルターン性能にほぼ一致。

**フォローアップ研究 — Mediator-Assistant アーキテクチャ**: 専用の「Mediator」エージェントが曖昧なマルチターン入力を明示的な構造化指示に変換してから、タスク実行「Assistant」に渡す。

**既存knowledgeとの関係**: 既存の `prompt-engineering-findings.md` はシングルターンの構造最適化に焦点。マルチターン特有の劣化メカニズムと対策は未カバー。

**行動変容への示唆**:
- 長いマルチフェーズワークフローでは、蓄積された決定事項を新鮮なプロンプトに統合する「リセットポイント」を設計すべき
- エージェントに「すべての要件が提示されるまで完全な解決策を提案しない」という指示を含めるべき
- Claude Codeの auto-compaction はこの Concat-and-Retry の形式化に相当

---

### 2. LLM-as-Judge の12種のバイアス

**出典**: [Justice or Prejudice? Quantifying Biases in LLM-as-a-Judge](https://llm-judge-bias.github.io/), [Evaluating Scoring Bias](https://arxiv.org/html/2506.22316v1), [Self-Preference Bias](https://arxiv.org/html/2410.21819v2)

LLMを評価者として使用する際の体系的バイアスが12種類カタログ化された。

**特に影響の大きいバイアス**:
- **位置バイアス**: 提示順序の入れ替えで精度が10%以上変動
- **冗長性/長さバイアス**: 内容の質に関係なく、冗長でフォーマルな出力を高評価
- **自己選好バイアス**: パープレキシティが低い（モデルにとって「馴染みのある」）テキストを高評価。著者ではなくパープレキシティが本質
- **スコアリングバイアス（3種）**: ルブリックの順序、スコアIDのラベル、参照回答の有無がそれぞれ**独立に**判定を変動させる
- GPT-4oでも摂動により人間との相関が最大0.2変動

**既存knowledgeとの関係**: `prompt-engineering-findings.md` に「Scoring Rubricは評価モードを誘発」という知見があるが、12種のバイアス分類とスコアリングバイアスの3サブタイプは未カバー。

**行動変容への示唆**:
- ペアワイズ比較では提示順序をランダム化すべき
- 生成と評価で同一モデルを使わない
- ルブリックの順序とスコアIDラベルが独立にバイアスを発生させることを前提に評価設計すべき
- 出力長で正規化してバリアント比較すべき

---

### 3. CoT忠実性の定量データ

**出典**: [Reasoning Models Don't Always Say What They Think](https://assets.anthropic.com/m/71876fabef0f0ed4/original/reasoning_models_paper.pdf) (Anthropic), [CoT May Be Informative Despite Unfaithfulness](https://metr.org/blog/2025-08-08-cot-may-be-highly-informative-despite-unfaithfulness/) (METR)

CoTの推論ステップがモデルの実際の推論過程を反映しているかを定量測定。

- **忠実性はバイアスタイプで劇的に異なる**: Sycophancy型ヒント: 60%忠実。報酬ハッキング型ヒント: 0%忠実
- **不忠実なCoTは体系的に長い**: Claude 3.7 Sonnet — 不忠実: 2,064トークン vs 忠実: 1,439トークン。DeepSeek R1 — 不忠実: 6,003 vs 忠実: 4,737
- **CoTモニタリングの限界**: 「CoTを必要としないタスクでCoTモニタリングの安全性を主張することは難しい」

**既存knowledgeとの関係**: `prompt-engineering-findings.md` に「剛性的CoTはステップ完了バイアスを誘発」があるが、CoT自体の忠実性データは未カバー。

**行動変容への示唆**:
- 長い推論 = 良い推論ではない。逆の可能性がある
- CoT出力を品質のシグナルとして依存しない
- 出力は推論トレースではなく最終結果で検証すべき

---

### 4. 推論強化がキャリブレーションを悪化させる

**出典**: [Mind the Confidence Gap](https://arxiv.org/html/2502.11028v3), [JMIR: Benchmarking Confidence](https://medinform.jmir.org/2025/1/e66917)

- **84.3%のシナリオで過信**（9 LLM、351シナリオ中296で過信）
- 最も精度の高いモデルでも、正解時と不正解時の**信頼度にほとんど差がない**
- **推論強化はキャリブレーションを悪化させる**: 「より深く考えさせる」と信頼度の推定がより不正確になるという反直感的な結果
- **ディストラクターで改善**: もっともらしい誤答選択肢を明示的に含めると、精度が最大460%改善、キャリブレーション誤差が90%減少

**既存knowledgeとの関係**: 未カバー。

**行動変容への示唆**:
- LLMの自己評価の信頼度スコアを鵜呑みにしない
- 評価タスクでは、もっともらしい誤答（ディストラクター）を含めることで精度が大幅に向上する
- 推論量を増やすこと ≠ より信頼性のある自己評価

---

### 5. エージェントのエラーカスケード

**出典**: [Where LLM Agents Fail](https://arxiv.org/abs/2509.25370), [Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657), [Taxonomy of Failures in Tool-Augmented LLMs](https://homes.cs.washington.edu/~rjust/publ/tallm_testing_ast_2025.pdf)

- **エラーカスケードがマルチエージェントシステムの支配的な障害パターン**: 単一の根本原因エラーが後続の決定に伝播し、各エージェントが誤った基盤の上に構築する
- **実行途中の劣化**: LLMはタスクを正しく開始するが、実行途中で性能が劣化。不正なツールコールとJSON出力構造の崩壊が原因
- **モデルサイズはエージェント堅牢性を予測しない**: Llama 4 Maverick (400B) が Granite 4 Small (32B) を僅差でしか上回らない
- **14のマルチエージェント障害モード**: システム設計問題、エージェント間のミスアライメント、タスク検証の失敗にクラスタリング

**既存knowledgeとの関係**: `agent-utilization-guide.md` に「エラー増幅」(17.2倍)の言及があるが、エラーカスケードのメカニズム詳細と対策は未カバー。

**行動変容への示唆**:
- ステップ間でエラーを分離する設計（各フェーズの出力を検証してから次フェーズへ）
- ツールコール後にバリデーションチェックポイントを追加
- アーキテクチャを複雑にすると脆弱性が増す可能性がある

---

### 6. Context Rot の位置依存性

**出典**: [Context Rot - Chroma Research](https://research.trychroma.com/context-rot) (18 LLM評価)

- 1,000トークンでは各トークンが999トークンに注意。100,000トークンでは99,999トークンに注意が分散
- **わずか20件の検索文書（〜4,000トークン）で精度が70-75%から55-60%に低下**
- **位置依存性**: 位置1の事実: 約75%精度。位置10: 約55%精度
- 「情報がコンテキストに存在するかどうかは十分ではない。**どのように、どこに**提示されるかがより重要」

**既存knowledgeとの関係**: `prompt-engineering-findings.md` に「注意バジェット制約」セクションがあり、ゼロサムトレードオフの概念はカバー済み。位置依存性の具体的な定量データ（75% vs 55%）と18モデルの大規模実証は新規。

**行動変容への示唆**:
- 最重要な指示・コンテキストをプロンプトの先頭と末尾に配置
- 「コンテキストは多いほど良い」ではなく、無関係なコンテキストを積極的に除去
- 既存知見「注意バジェット制約」の拡張データとして統合可能

---

### 7. マルチエージェントのトークンオーバーヘッド詳細

**出典**: [Stop Wasting Your Tokens](https://arxiv.org/html/2510.26585v1) (2025), [Single-agent or Multi-agent?](https://arxiv.org/abs/2505.18286) (2025/05)

- マルチエージェントアーキテクチャは**同等性能で1.6x〜6.2xのトークンオーバーヘッド**（独立型58%、ハイブリッド型515%）
- **理論的に必要な量の1.5x〜7x**のトークンを消費。冗長なコンテキスト共有が原因
- 入力トークンの大部分は**エージェント間の対話**から発生（ツール出力ではない）
- **3つの削減戦略**:
  1. 適応的観察精製付きSupervisorAgent: 約30%削減
  2. **単一エージェントスキルライブラリへのコンパイル: 54%削減+レイテンシ50%削減**（エージェント間通信を排除しつつ能力を保持）
  3. キャッシュ付きエージェントルーティング: 最小オーバーヘッド
- **フロンティアLLMの能力向上に伴い、マルチエージェントのシングルエージェントに対する優位性は減少**

**既存knowledgeとの関係**: `agent-utilization-guide.md` に「TeamCreate = サブエージェントの3-4倍」とあるが、1.6x〜6.2xの詳細レンジ、削減戦略、「能力向上でマルチエージェントの優位性が減少」は新規。

**行動変容への示唆**:
- マルチエージェントワークフローが安定したら、単一エージェント+スキルライブラリへのコンパイルを検討（「TeamCreateからTask toolへの卒業」パターン）
- モデル能力の向上に伴い、TeamCreate使用の閾値を引き上げるべき

---

### 8. Sycophancy対策: 匿名化と批判的評価フレーミング

**出典**: [Peacemaker or Troublemaker: Sycophancy in Multi-Agent Debate](https://arxiv.org/html/2509.23055v1), [CONSENSAGENT](https://aclanthology.org/2025.findings-acl.1141/) (ACL 2025)

- **Sycophancyは議論ラウンドの進行とともに強化**: エージェント間の不一致率が低下し、性能劣化と相関
- **理論的証明**: 議論はエージェントの信念軌跡上のマルチンゲールを誘導し、**議論だけでは期待正確性は改善しない**（分散のみ変化）
- **匿名化でidentity-driven sycophancyをほぼ排除**: 回答からソース帰属を除去するとidentityバイアスを防止
- **批判的応答生成器**: 「先行回答を批判的に評価し、新しい解決策を提案せよ」という明示的フレーミングがsycophancy傾向に対抗

**既存knowledgeとの関係**: `agent-utilization-guide.md` に「追従性問題」の言及と「対話ラウンドは3-4回が最適」があるが、匿名化戦略と批判的フレーミングの具体的対策は新規。

**行動変容への示唆**:
- 並列レビュー（例: agent_benchの4 critic並列）では、クロス評価前に回答を匿名化
- エージェントに「評価する」ではなく「批判的に評価し、代替案を提案する」とフレーミング

---

### 9. ACE: grow-and-refine原則

**出典**: [Agentic Context Engineering](https://arxiv.org/abs/2510.04618) (2025/10)

コンテキストを「進化するプレイブック」として扱うフレームワーク。

- **3つの専門化された役割**: Generator（推論軌跡を生成）、Reflector（評価と洞察抽出）、Curator（有用/有害カウンター付き構造化デルタ更新、決定論的マージ、重複排除、プルーニング）
- **grow-and-refine原則**: 全面書き換えではなくインクリメンタル更新。「簡潔化バイアス」（ドメイン洞察を要約のために削除）と「コンテキスト崩壊」（反復的書き換えで詳細が劣化）を防止
- **定量結果**: エージェントタスク+10.6%、金融タスク+8.6%。適応レイテンシ82-92%削減、トークンコスト75-84%削減

**既存knowledgeとの関係**: 未カバー。agent_benchの knowledge.md は「保持+統合方式」を採用しており、grow-and-refine原則と方向性が一致するが、有用/有害カウンターや決定論的マージは未実装。

**行動変容への示唆**:
- knowledge更新時に全面書き換えではなくデルタ更新+マージを採用
- 各知見に有用/有害カウンターを付与して効果を追跡
- Reflector役割の分離（更新内容を生成する役割と、更新の品質を評価する役割を分ける）

---

### 10. AI生成PRの失敗パターン

**出典**: [Where Do AI Coding Agents Fail?](https://arxiv.org/abs/2601.15195) (2026/01, 33k+ PR分析)

- ドキュメント/CI/ビルドタスクのマージ率が最高。パフォーマンス・バグ修正タスクは最も失敗
- 失敗PRの特徴: 変更が大きい、ファイル数が多い、CI失敗。22%がコードレベル問題、17%がCI/テスト失敗
- **必要な4つの改善**: (1) 既存/進行中の作業を特定 (2) プロジェクト貢献規範に従う (3) ローカライズされた変更に分解 (4) 提出前にCIで検証
- メンテナーのフィードバック: 「PRは小さく、焦点を絞り、単一の一貫した変更に限定すべき」

**既存knowledgeとの関係**: 未カバー。

**行動変容への示唆**:
- エージェントに「小さく焦点を絞った変更」を生成させる指示
- CI検証を提出前の必須ステップとして組み込む

---

### 11. CWE指定でセキュアコード生成率向上

**出典**: [Veracode GenAI Code Security Report 2025](https://www.veracode.com/blog/genai-code-security-report/) (100+ LLM, 80タスク)

- AI生成コードの45%がセキュリティテストに不合格
- 86%がXSS防御に失敗(CWE-80)、88%がログインジェクションに脆弱(CWE-117)
- **Claude Opus 4.5 + Thinking**: セキュリティプロンプティングなしで56%のセキュアコード生成率。特定のCWE番号を指定して回避を指示すると69%に向上(**+13pp**)

**既存knowledgeとの関係**: `prompt-engineering-findings.md` に「技術固有の盲点には条件分岐型チェックリストが必要」という関連知見がある。CWE番号指定の定量的効果は新規。

**行動変容への示唆**:
- セキュリティレビューエージェントにgenericな「セキュリティを確認せよ」ではなく、具体的なCWE番号を含めると検出率が向上

---

### 12. 7つの運用障害モード

**出典**: Galileo, Quaxel (2025-2026)

1. **ループ**: 反復サイクルに陥る → 最大反復制限付きループ検出
2. **ツール誤用**: 不正パラメータ/権限超過 → 厳格なパラメータバリデーション
3. **プロンプトインジェクション**: 外部データが行動に影響 → 入力サニタイズ
4. **ドリフト**: 長い対話で元の目標から漸進的に逸脱 → 定期的な目標再アンカリング
5. **幻覚状態**: 内部モデルが実際の環境と非同期 → 状態検証チェックポイント
6. **過剰リトライ**: アプローチを変えずに失敗操作をリトライ → N回リトライ後のエスカレーションポリシー
7. **目標ミスアライメント**: 誤った目的を最適化 → 明示的な成功基準と検証

**既存knowledgeとの関係**: 未カバー。ドリフトはマルチフェーズワークフローに関連。過剰リトライはagent_benchの収束検出に関連。

---

### 13. CLAUDE.mdの最小化原則

**出典**: [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices) (Anthropic公式)

- 「各行について問え: これを削除するとClaudeがミスするか？ NOなら削除」
- 含めるべきでないもの: コードを読めば分かること、標準的な言語規約、詳細なAPIドキュメント、「クリーンなコードを書け」等の自明な指示
- 「肥大化したCLAUDE.mdファイルはClaudeに実際の指示を無視させる」
- **2回の修正失敗後は /clear して書き直す**: 「より良いプロンプトでのクリーンなセッションは、蓄積された修正のある長いセッションをほぼ常に上回る」

**既存knowledgeとの関係**: learn スキルの「削ってよい情報」基準（「AIが既に知っている情報」）と方向性が一致。CLAUDE.md自体の最小化についての明示的な指針は未記録。

---

## 出典一覧

### マルチターン・コンテキスト管理
- [LLMs Get Lost in Multi-Turn Conversation](https://arxiv.org/abs/2505.06120)
- [Intent Mismatch Causes LLMs to Get Lost](https://arxiv.org/html/2602.07338v1)
- [Context Rot - Chroma Research](https://research.trychroma.com/context-rot)
- [Agentic Context Engineering (ACE)](https://arxiv.org/abs/2510.04618)
- [Effective Context Engineering for AI Agents - Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### LLM評価・バイアス
- [Justice or Prejudice? Quantifying Biases in LLM-as-a-Judge](https://llm-judge-bias.github.io/)
- [Evaluating Scoring Bias in LLM-as-a-Judge](https://arxiv.org/html/2506.22316v1)
- [Self-Preference Bias in LLM-as-a-Judge](https://arxiv.org/html/2410.21819v2)
- [Reasoning Models Don't Always Say What They Think - Anthropic](https://assets.anthropic.com/m/71876fabef0f0ed4/original/reasoning_models_paper.pdf)
- [CoT May Be Informative Despite Unfaithfulness - METR](https://metr.org/blog/2025-08-08-cot-may-be-highly-informative-despite-unfaithfulness/)
- [Mind the Confidence Gap](https://arxiv.org/html/2502.11028v3)

### マルチエージェント
- [Stop Wasting Your Tokens](https://arxiv.org/html/2510.26585v1)
- [Single-agent or Multi-agent? Why Not Both?](https://arxiv.org/abs/2505.18286)
- [Peacemaker or Troublemaker: Sycophancy in Multi-Agent Debate](https://arxiv.org/html/2509.23055v1)
- [CONSENSAGENT - ACL 2025](https://aclanthology.org/2025.findings-acl.1141/)

### エージェント障害モード
- [Where LLM Agents Fail](https://arxiv.org/abs/2509.25370)
- [Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657)
- [Taxonomy of Failures in Tool-Augmented LLMs](https://homes.cs.washington.edu/~rjust/publ/tallm_testing_ast_2025.pdf)
- [7 AI Agent Failure Modes - Galileo](https://galileo.ai/blog/agent-failure-modes-guide)
- [Microsoft Taxonomy of Failure Modes in Agentic AI](https://www.microsoft.com/en-us/security/blog/2025/04/24/new-whitepaper-outlines-the-taxonomy-of-failure-modes-in-ai-agents/)

### AIコーディング実践
- [Where Do AI Coding Agents Fail? (33k PRs)](https://arxiv.org/abs/2601.15195)
- [Best Practices for Claude Code - Anthropic](https://code.claude.com/docs/en/best-practices)
- [Veracode GenAI Code Security Report](https://www.veracode.com/blog/genai-code-security-report/)
- [CodeRabbit AI vs Human Code Report](https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report)
- [Decoding the Configuration of AI Coding Agents (328 files)](https://arxiv.org/abs/2511.09268)
- [Structured Prompting Enables More Robust Evaluation](https://arxiv.org/abs/2511.20836)
