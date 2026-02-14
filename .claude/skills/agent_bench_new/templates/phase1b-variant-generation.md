以下の手順でベースラインコピーとバリアントを生成してください:

1. Read で以下のファイルを読み込む:
   - {knowledge_path} （過去の知見 — バリエーションステータステーブルを含む）
   - {agent_path} （デプロイ済みベースライン = 比較基準）
   - {proven_techniques_path} （エージェント横断の実証済みテクニック — アンチパターン回避に使用）
   - {perspective_path} （観点定義 — バリアント生成時の参考）
   - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
   - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
2. knowledge.md の「バリエーションステータス」テーブルを使い、バリアントを選定する:
   - 累計ラウンド < 3 → Broad: UNTESTED カテゴリの基本バリエーション(a接尾辞)を選択
   - 累計ラウンド >= 3 かつ、4カテゴリ(S/C/N/M)のいずれかで基本バリエーション(a接尾辞)が全て UNTESTED → Broad（当該カテゴリの基本バリエーションを優先選択）
   - 累計ラウンド >= 3 かつ、全カテゴリに1つ以上の TESTED あり → Deep: 最も効果が高かった EFFECTIVE カテゴリ内の UNTESTED バリエーションを選択
   - Deep モードでバリエーションの詳細が必要な場合のみ {approach_catalog_path} を Read で読み込む
   - proven-techniques.md の「回避すべきアンチパターン」に該当するテクニックは選択しない
3. ベースライン（比較用コピー）を {prompts_dir}/v{NNN}-baseline.md として保存する（NNN = 累計ラウンド数 + 1）。既存ファイルが存在する場合は上書きする
4. 2個のバリアントを生成し {prompts_dir}/v{NNN}-variant-{name}.md として保存する
   - 各ファイルに Benchmark Metadata コメントを記載する（Variation ID を必ず含める）
5. 以下のフォーマットで結果サマリのみ返答する:

## 選定プロセス
- モード: {Broad/Deep}
- 判定理由: {どの条件に該当したか}

## 生成したバリアント
1. v{NNN}-variant-{name1}.md
   - Variation ID: {カタログID}
   - モード: {Broad/Deep}
   - 独立変数: {変更内容}
   - 仮説: {期待される効果}
   - 根拠: {knowledge.md の該当知見}
2. （あれば2つ目）
