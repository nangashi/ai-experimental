# Instruction Extract: multi-agent-coordination

source: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/docs/knowledge/multi-agent-coordination.md
extracted: 2026-02-16
items: 10

---

## KE-001: トークンオーバーヘッドを考慮したマルチエージェント採用判断

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: マルチエージェント構成を検討するとき
- **action**: マルチエージェントアーキテクチャは同等性能で1.6x〜6.2xのトークンオーバーヘッドを生じることを前提に、性能改善がコスト増を正当化できるか確認する。フロンティアLLMの能力向上に伴い、マルチエージェントの優位性は減少している点を考慮する。
- **rationale**: 実測で独立型58%、ハイブリッド型515%のオーバーヘッドが確認されている。入力トークンの大部分はエージェント間の対話から発生する。

---

## KE-002: Supervisor精製による30%トークン削減

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: マルチエージェント構成で中間結果の受け渡しがある設計を行うとき
- **action**: Supervisorエージェントが各エージェントの出力を精製してから次に渡す設計を検討する。
- **rationale**: 適応的観察精製により約30%のトークン削減が実測されている。

---

## KE-003: スキルライブラリへのコンパイル

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: 安定したマルチエージェントワークフローを運用しているとき
- **action**: マルチエージェントの能力を単一エージェント+スキルライブラリに統合する「TeamCreateからTask toolへの卒業」パターンを検討する。
- **rationale**: エージェント間通信を排除しつつ能力を保持することで、54%のトークン削減とレイテンシ50%削減が実測されている。

---

## KE-004: コンテキスト分離を主目的としたサブエージェント設計

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: サブエージェント利用を判断するとき
- **action**: サブエージェント使用を「役割分担が必要か」ではなく「コンテキスト分離が必要か」で判断する。各サブエージェントが独立したコンテキストウィンドウで作業し、メインのコンテキストを汚染しない設計を優先する。
- **rationale**: 早期の複雑なマルチエージェントスキャフォールディングは、よりシンプルな代替案より一貫してパフォーマンスが悪い。組織的な役割のシミュレーションではなくコンテキスト分離が主目的である。

---

## KE-005: エラーカスケード防止のための検証チェックポイント

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: マルチステップのワークフローを設計するとき
- **action**: 各フェーズの出力を検証してから次フェーズへ進む設計にする。特にツールコール後にバリデーションチェックポイントを追加する。
- **rationale**: エラーカスケードがマルチエージェントシステムの支配的な障害パターン。単一の根本原因エラーが後続の決定に伝播し、各エージェントが誤った基盤の上に構築する。14のマルチエージェント障害モードが確認されている。

---

## KE-006: Sycophancy対策としての匿名化と批判的応答生成

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: 複数エージェントによる議論・合意形成を設計するとき
- **action**: 回答からソース帰属を除去し匿名化する。批判的応答生成器として「先行回答を批判的に評価し、新しい解決策を提案せよ」という明示的フレーミングを与える。対話ラウンドは3-4回に制限する。
- **rationale**: Sycophancyは議論ラウンドの進行とともに強化され、エージェント間の不一致率が低下し性能劣化と相関する。理論的にも議論だけでは期待正確性は改善しない（分散のみ変化）。匿名化でidentity-driven sycophancyをほぼ排除できる。

---

## KE-007: ループ検出と最大反復制限

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: 反復処理を含むマルチエージェントワークフローを設計するとき
- **action**: 最大反復制限付きループ検出を実装する。
- **rationale**: ループ（反復サイクルに陥る）はマルチエージェントの7つの運用障害モードの1つとして確認されている。

---

## KE-008: リトライ回数制限とエスカレーションポリシー

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: エラーハンドリング戦略を設計するとき
- **action**: N回リトライ後のエスカレーションポリシーを設定する。アプローチを変えずに失敗操作をリトライし続けない。
- **rationale**: 過剰リトライ（アプローチを変えずに失敗操作をリトライ）はマルチエージェントの7つの運用障害モードの1つとして確認されている。

---

## KE-009: 定期的な目標再アンカリング

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: 長い対話や複数ステップを持つエージェントワークフローを設計するとき
- **action**: 定期的に元の目標を再アンカリングする仕組みを組み込む。
- **rationale**: ドリフト（長い対話で元の目標から漸進的に逸脱）はマルチエージェントの7つの運用障害モードの1つとして確認されている。

---

## KE-010: ステップバイステップ観察によるエージェント動作改善

- **use-when**: Designing multi-agent tasks or choosing between Task tool subagents and TeamCreate
- **scope**: エージェントの開発・改善フェーズ
- **action**: 本番と同一のプロンプト・ツールでエージェントの動作をステップバイステップで観察する。過剰継続・冗長クエリ・ツール選択ミス・停止失敗の4つの失敗モードを確認する。プロンプトエンジニアリングをマルチエージェント行動改善の主要レバーとする。
- **rationale**: Anthropicがマルチエージェントリサーチシステム構築でConsoleを使い観察したところ、4つの失敗モードが即座に判明した。プロンプトエンジニアリングでOpus 4（リーダー）+ Sonnet 4（サブエージェント）構成が単一エージェントOpus 4比90.2%性能向上を達成した。
