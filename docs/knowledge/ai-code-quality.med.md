# Instruction Extract: ai-code-quality

source: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/docs/knowledge/ai-code-quality.md
extracted: 2026-02-16
items: 10

---

## KE-001: 抽象化肥大の自己チェック

- **use-when**: Generating or editing code (self-check for dead code accumulation and adjacent code alteration)
- **scope**: コード生成時、特に関数・クラス・モジュール構造を決定する場面
- **action**: 生成するコードの行数・抽象化レベルが要件に対して過剰でないか自己チェックする。100行で済む処理に1,000行を生成していないか、関数で済むところにクラス階層を構築していないか確認する
- **rationale**: Google ChromeチームのAddy Osmani分析により、AIは「100行で十分なところに1,000行を生成する」「関数で済むところに精巧なクラス階層を構築する」という抽象化肥大を引き起こすことが判明している。80%問題（速く到達するが残り20%で品質を破壊する）の主要パターン

---

## KE-002: デッドコード除去の明示的確認

- **use-when**: Generating or editing code (self-check for dead code accumulation and adjacent code alteration)
- **scope**: 既存コードを修正・置換する場面、特に新しい実装を追加する際
- **action**: 新しい実装を追加する際、置き換え対象の古い実装を削除したか明示的に確認する。タスク近傍にあるという理由だけで理解していないコードを変更しない。コメントを副作用的に削除しない
- **rationale**: デッドコード蓄積は80%問題の主要パターン。エージェントは自分が生成した不要コードを片付けず、古い実装を残したまま新しい実装を追加する傾向がある。AI生成コードのコード重複が人間の4倍に増加するという定量データもこれを裏付ける

---

## KE-003: 曖昧な要件への仮定の明示化

- **use-when**: Generating or editing code (self-check for dead code accumulation and adjacent code alteration)
- **scope**: 要件の曖昧な部分について仮定を置いてタスクを進める場面
- **action**: 曖昧な要件に対して仮定を置く前にユーザーに確認する。仮定を置いた場合は明示的に文書化し後続タスクで検証可能にする
- **rationale**: 仮定伝播（Assumption Propagation）パターンでは、序盤の誤った仮定がテストを通過しつつ蓄積し、複数のPRにまたがって発覚する。仮定に基づいてコードを生成すると、仮定に整合的なテストも書かれるため問題が隠蔽される

---

## KE-004: PRの小規模化と焦点の絞り込み

- **use-when**: Generating or editing code (self-check for dead code accumulation and adjacent code alteration)
- **scope**: PR作成時、特にファイル数・変更行数を決定する場面
- **action**: PRは小さく、焦点を絞り、単一の一貫した変更に限定する。大きな変更は複数のローカライズされた変更に分解する
- **rationale**: 33,000+ PR分析により、AI生成PRの67.3%が却下される（手動コードは15.6%）ことが判明。失敗PRの特徴は「変更が大きい、ファイル数が多い」。メンテナーのフィードバックでも「PRは小さく、焦点を絞り、単一の一貫した変更に限定すべき」と指摘されている

---

## KE-005: セキュリティレビューでのCWE番号指定

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: セキュリティレビュー観点の生成、またはコード生成時のセキュリティ指示
- **action**: セキュリティレビューには「セキュリティを確認せよ」のようなgenericな指示ではなく、具体的なCWE番号を含めて回避を指示する
- **rationale**: Claude Opus 4.5 + Thinkingを用いた実験で、セキュリティプロンプティングなしで56%のセキュアコード生成率が、特定のCWE番号を指定すると69%に向上（+13pp）。AI生成コードの45%がセキュリティテストに不合格（86%がXSS防御に失敗、88%がログインジェクションに脆弱）という現状を踏まえると、具体的な脆弱性パターンを指定する効果は大きい

---

## KE-006: コードチャーンの繰り返しパターン検出

- **use-when**: Generating or editing code (self-check for dead code accumulation and adjacent code alteration)
- **scope**: 特定のコードパターンが繰り返し修正・書き直される場合
- **action**: 同じコード領域で繰り返し修正が発生しているパターンを検出したら、生成アプローチを変更する判断基準とする
- **rationale**: コードチャーン（書いた直後に修正・書き直しされるコードの割合）がAI時代の品質指標として注目されている。AI出力の増加＋チャーン上昇＝実質的な生産性は低下。チャーンは「素早く書かれたコード」と「安定したロジック」を区別できる

---

## KE-007: Eval駆動開発の評価カテゴリ

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: スキル/エージェント構築前に評価基準を定義する場面
- **action**: 評価基準を4カテゴリ（成果目標、プロセス目標、スタイル目標、効率目標）から3-5メトリクスで定義する。推論層とアクション層を別々に評価する
- **rationale**: TDDのエージェント版。スキル/エージェント構築前に評価基準を定義することで、開発の方向性が明確化し品質が向上する。コンポーネントレベルとエンドツーエンドの混合評価により、問題の局所化が可能になる

---

## KE-008: プロンプトインジェクション多層防御

- **use-when**:
- **proposed-use-when**: LLMアプリケーションのセキュリティ設計を行うとき、特に外部入力を受け付けるエージェント・アシスタントを実装するとき
- **scope**: プロンプトインジェクション攻撃への防御機構を設計する場面
- **action**: 入力ガードレール、コンテンツフィルタリング、階層的システムプロンプト、出力検証、アクションガードの5層防御を組み合わせる。単一の防御層に依存しない
- **rationale**: OWASP 2025 LLMアプリケーション Top 10 第1位の脆弱性。多層防御フレームワークで攻撃成功率73.2%から8.7%に低減（タスク性能の94.3%を維持）という実証データがある
- **conditions**: 同じLLMを生成とセキュリティ評価の両方に使うと複合脆弱性になる。単純な手法（感情操作、タイポ、難読化）は依然として最新モデルを回避可能

---

## KE-009: 出力のサニタイズ必須化

- **use-when**:
- **proposed-use-when**: LLM出力を下流システム（データベース、Webページ、外部API等）に渡すとき
- **scope**: LLM生成の出力を下流システムに渡す前の処理
- **action**: LLM出力は常に「未信頼入力」として扱い、下流システムへの受け渡し前にバリデーションとサニタイズを行う。構造化出力のフォーマット検証も実施する
- **rationale**: LLM生成の出力を下流システムにサニタイズなしで渡すことで発生する出力インジェクション（OWASP LLMリスク）により、XSS、SQLインジェクション、リモートコード実行のリスクがある。モデルを信頼済みソースとして扱い、出力を検証しないことが根本原因

---

## KE-010: スキーマドリフト防止の厳格化

- **use-when**: Designing or restructuring agent/reviewer prompt structure (decomposition, technique selection, bias avoidance)
- **scope**: LLMタスクで構造化出力を要求する場面、特に自動化パイプラインでの利用
- **action**: `strict: true`フラグまたは制約付きデコーディング（Structured Outputs）でスキーマ準拠を強制する。重要なプロンプトには自己チェックブロックを付加して出力フォーマット準拠を検証させる
- **rationale**: スキーマドリフト（LLMが期待されるJSON構造から逸脱する現象）は自動化パイプライン破損の最大原因。Structured Outputsによりスキーマ準拠を100%保証できる
