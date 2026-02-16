# Agent Utilization Guide

Multi-agent task design and Task tool subagent vs TeamCreate selection guidelines.

## トークンオーバーヘッドを考慮したマルチエージェント採用判断

- **scope**: マルチエージェント構成を検討するとき
- **action**: マルチエージェントアーキテクチャは同等性能で1.6x〜6.2xのトークンオーバーヘッドを生じることを前提に、性能改善がコスト増を正当化できるか確認する。フロンティアLLMの能力向上に伴い、マルチエージェントの優位性は減少している点を考慮する。
- **rationale**: 実測で独立型58%、ハイブリッド型515%のオーバーヘッドが確認されている。入力トークンの大部分はエージェント間の対話から発生する。
- **source**: docs/knowledge/multi-agent-coordination.md

## Supervisor精製による中間結果のトークン削減

- **scope**: マルチエージェント構成で中間結果の受け渡しがある設計を行うとき
- **action**: Supervisorエージェントが各エージェントの出力を精製してから次に渡す設計を検討する。
- **rationale**: 適応的観察精製により約30%のトークン削減が実測されている。
- **source**: docs/knowledge/multi-agent-coordination.md

## 安定ワークフローのスキルライブラリへのコンパイル

- **scope**: 安定したマルチエージェントワークフローを運用しているとき
- **action**: マルチエージェントの能力を単一エージェント+スキルライブラリに統合する「TeamCreateからTask toolへの卒業」パターンを検討する。
- **rationale**: エージェント間通信を排除しつつ能力を保持することで、54%のトークン削減とレイテンシ50%削減が実測されている。
- **source**: docs/knowledge/multi-agent-coordination.md

## コンテキスト分離を主目的としたサブエージェント設計

- **scope**: サブエージェント利用を判断するとき
- **action**: サブエージェント使用を「役割分担が必要か」ではなく「コンテキスト分離が必要か」で判断する。各サブエージェントが独立したコンテキストウィンドウで作業し、メインのコンテキストを汚染しない設計を優先する。
- **rationale**: 早期の複雑なマルチエージェントスキャフォールディングは、よりシンプルな代替案より一貫してパフォーマンスが悪い。組織的な役割のシミュレーションではなくコンテキスト分離が主目的である。
- **source**: docs/knowledge/multi-agent-coordination.md

## Sycophancy対策としての匿名化と批判的応答生成

- **scope**: 複数エージェントによる議論・合意形成を設計するとき
- **action**: 回答からソース帰属を除去し匿名化する。批判的応答生成器として「先行回答を批判的に評価し、新しい解決策を提案せよ」という明示的フレーミングを与える。対話ラウンドは3-4回に制限する。
- **rationale**: Sycophancyは議論ラウンドの進行とともに強化され、エージェント間の不一致率が低下し性能劣化と相関する。理論的にも議論だけでは期待正確性は改善しない（分散のみ変化）。匿名化でidentity-driven sycophancyをほぼ排除できる。
- **source**: docs/knowledge/multi-agent-coordination.md

