# Prompt Design Guidelines

Agent/reviewer prompt design guidelines.

## 内容・パターンの Few-shot 例示によるバイアスの回避

- **scope**: レビュー・評価・探索タスクで、検出すべき問題や分析の方向性を Few-shot で例示するとき
- **actions**:
  - ゼロショットをデフォルトとし、指示の曖昧性が解消できない場合のみ1例を追加する
- **rationale**: few-shot例の追加が性能を改善せず劣化を引き起こすことがある。ただし例示なしでは検出スコープの解釈が曖昧になるリスクがあるため、指示文で一意に定まらない場合は最小限の例示で曖昧性を解消する。出力フォーマットの例示（JSON構造等）には該当しない。
- **sources**: [Revisiting Chain-of-Thought Prompting: Zero-shot Can Be Stronger than Few-shot (Cheng et al., 2025)](https://arxiv.org/abs/2506.14641)

## 視点強制が必要なタスクでのペルソナ指示

- **scope**: 特定観点からのレビューなど、視点の強制が必要なタスクを設計するとき
- **actions**:
  - 単純なロールラベル（"You are a lawyer"）ではなく、以下を含む詳細なペルソナ指示を作成する:
    - 専門領域と経験の文脈（例: 「金融システムの認証基盤を10年運用してきた」）
    - 着目する観点と優先順位（例: 「認可バイパスを最優先で確認する」）
    - 判断の基準や思考プロセス（例: 「攻撃者視点でデータフローを追跡する」）
  - ペルソナの記述は LLM に生成させることを検討する
- **rationale**: 単純なペルソナはベースラインから改善せず、時に劣化する（GPT-4-turbo × MMLU実験で「バカ」ペルソナが「天才」を上回った）。詳細なドメイン固有の記述（専門領域・経験・思考プロセス）を含むペルソナは、ペルソナなしの通常プロンプトを有意に上回る（GPT-4評価で48.5% vs 23%の選好率）。LLM生成ペルソナはペルソナなしの通常プロンプトを上回る。
- **sources**:
  - [The Prompt Report: A Systematic Survey of Prompting Techniques (Schulhoff et al., 2024)](https://arxiv.org/abs/2406.06608)
  - [ExpertPrompting: Instructing Large Language Models to be Distinguished Experts (Xu et al., 2023)](https://arxiv.org/abs/2305.14688)

## レビュー・評価タスクでの sycophancy 対策

- **scope**: LLM にレビュー・評価を指示するとき
- **actions**:
  - レビュー指示に「問題があれば否定的な評価を下してよい」という明示的な拒否許可を含める
- **rationale**: sycophancy（迎合傾向）は最新モデルでも約58%の発生率で残存している。明示的な拒否許可の付与により、非論理的要求の拒否率が最大94%向上することが確認されている。
- **sources**:
  - [SycEval: Evaluating LLM Sycophancy (2025)](https://arxiv.org/abs/2502.08177)
  - [When helpfulness backfires: LLMs and the risk of false medical information due to sycophantic behavior (Chen et al., 2025)](https://www.nature.com/articles/s41746-025-02008-z)

