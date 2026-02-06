# 商品レビュー機能追加 - 開発要件・コードベース分析結果

## 要件概要

ECサイト「ShopNow」に商品レビュー機能を追加する。ユーザーが購入した商品に対してレビュー（星評価1-5 + テキスト + 画像）を投稿でき、商品詳細ページにレビュー一覧と平均評価を表示する。

## 機能要件

### FR-1: レビュー投稿
- ログインユーザーが商品に対してレビューを投稿できる
- レビューには星評価（1-5）、タイトル、本文テキスト、画像（最大3枚）を含む
- レビュー本文はHTMLリッチテキストで入力可能とする
- 投稿後、商品の平均評価を再計算して表示を更新する

### FR-2: レビュー一覧表示
- 商品詳細ページにレビュー一覧を表示する
- 全レビューを新着順で取得して表示する
- レビューごとに投稿者名、星評価、タイトル、本文、画像、投稿日時を表示
- 各レビューの本文はHTMLとしてそのまま表示する

### FR-3: 平均評価表示
- 商品詳細ページに平均評価（星表示）とレビュー件数を表示する
- 平均評価はフロントエンドで全レビューの星評価から計算する
- バックエンドのAPIレスポンスにも平均評価を含める（バックエンドでも全レビューから毎回計算）

### FR-4: レビュー管理（管理者）
- 管理者はレビューの削除が可能
- 不適切なレビューにフラグを付ける機能

## 技術選定結果（ユーザー決定事項）

- バックエンド: Node.js + Express（既存スタックを踏襲）
- データベース: PostgreSQL（既存DBに追加）
- 画像ストレージ: S3互換ストレージ
- フロントエンド: React + TypeScript（既存スタックを踏襲）

## コードベース分析結果

### ディレクトリ構成（既存）
```
src/
├── controllers/
│   ├── productController.ts    # 商品CRUD
│   ├── userController.ts       # ユーザー認証・管理
│   └── orderController.ts      # 注文処理
├── services/
│   ├── productService.ts       # 商品ビジネスロジック
│   ├── userService.ts          # ユーザービジネスロジック
│   └── orderService.ts         # 注文ビジネスロジック
├── repositories/
│   ├── productRepository.ts    # 商品DB操作
│   ├── userRepository.ts       # ユーザーDB操作
│   └── orderRepository.ts      # 注文DB操作
├── models/
│   ├── Product.ts
│   ├── User.ts
│   └── Order.ts
├── middleware/
│   ├── auth.ts                 # JWT認証ミドルウェア
│   └── errorHandler.ts         # エラーハンドリング
├── routes/
│   └── index.ts
├── utils/
│   └── validator.ts            # バリデーションユーティリティ
├── __tests__/
│   ├── product.test.ts         # Jest + supertest
│   ├── user.test.ts
│   └── order.test.ts
└── app.ts
```

### 既存コードのパターン

#### Controller例（productController.ts:15-30）
```typescript
export class ProductController {
  constructor(private productService: ProductService) {}

  async getProduct(req: Request, res: Response, next: NextFunction) {
    try {
      const product = await this.productService.findById(req.params.id);
      if (!product) {
        throw new NotFoundError('Product not found');
      }
      res.json({ data: product });
    } catch (error) {
      next(error);
    }
  }
}
```

#### Service例（productService.ts:10-25）
```typescript
export class ProductService {
  constructor(private productRepository: ProductRepository) {}

  async findById(id: string): Promise<Product | null> {
    return this.productRepository.findById(id);
  }

  async create(data: CreateProductDto): Promise<Product> {
    // バリデーション
    this.validateProduct(data);
    return this.productRepository.create(data);
  }
}
```

#### Repository例（productRepository.ts:8-20）
```typescript
export class ProductRepository {
  async findById(id: string): Promise<Product | null> {
    return db.query('SELECT * FROM products WHERE id = $1', [id]);
  }

  async create(data: CreateProductDto): Promise<Product> {
    return db.query(
      'INSERT INTO products (name, price, description) VALUES ($1, $2, $3) RETURNING *',
      [data.name, data.price, data.description]
    );
  }
}
```

### 既存コーディング規約
- 命名規則: camelCase（変数・関数）、PascalCase（クラス・型）
- エラーハンドリング: カスタムエラークラス（NotFoundError, ValidationError等）をthrowし、errorHandlerミドルウェアで一括処理
- テスト: Jest + supertestでAPIエンドポイントの統合テスト + ユニットテスト
- DB操作: Repositoryパターンで分離

## 新規実装の設計方針（レビュー担当チーム作成）

### データモデル

```typescript
// models/Review.ts
export class Review {
  id: string;
  productId: string;
  userId: string;
  rating: number;          // 1-5
  title: string;
  body: string;            // HTMLリッチテキスト
  images: string[];        // S3 URLs
  createdAt: Date;
  updatedAt: Date;
  flagged: boolean;

  // 平均評価を計算するメソッド
  static calculateAverage(reviews: Review[]): number {
    return reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;
  }

  // レビュー通知を送信するメソッド
  async sendNotification(): Promise<void> {
    // メール通知ロジック
  }

  // レビュー集計レポートを生成するメソッド
  generateReport(): ReviewReport {
    // 集計ロジック
  }
}
```

### DBスキーマ

```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  user_id UUID NOT NULL REFERENCES users(id),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  images TEXT[],
  flagged BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### API設計

```
POST   /api/reviews              - レビュー投稿
GET    /api/products/:id/reviews - 商品のレビュー一覧取得
DELETE /api/reviews/:id          - レビュー削除（管理者）
PATCH  /api/reviews/:id/flag     - レビューフラグ設定（管理者）
```

### Controller実装案

```typescript
// controllers/reviewController.ts
export class ReviewController {
  // 注: 既存パターンと異なり、Serviceを経由せずDB操作を直接記述
  async createReview(req: Request, res: Response) {
    const { productId, rating, title, body, images } = req.body;

    const review = await db.query(
      'INSERT INTO reviews (product_id, user_id, rating, title, body, images) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [productId, req.user.id, rating, title, body, images]
    );

    res.status(201).json({ data: review });
  }

  async getProductReviews(req: Request, res: Response) {
    const reviews = await db.query(
      'SELECT * FROM reviews WHERE product_id = $1 ORDER BY created_at DESC',
      [req.params.id]
    );

    // 平均評価をここで計算
    const average = reviews.reduce((sum: number, r: any) => sum + r.rating, 0) / reviews.length;

    res.json({ data: reviews, averageRating: average });
  }
}
```

### フロントエンド実装案

```typescript
// フロントエンド側でも平均評価を計算
const ReviewList: React.FC<{ productId: string }> = ({ productId }) => {
  const [reviews, setReviews] = useState<Review[]>([]);

  useEffect(() => {
    fetch(`/api/products/${productId}/reviews`)
      .then(res => res.json())
      .then(data => setReviews(data.data));
  }, [productId]);

  const averageRating = reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;

  return (
    <div>
      <h2>レビュー ({reviews.length}件) - 平均: {averageRating.toFixed(1)}</h2>
      {reviews.map(review => (
        <div key={review.id}>
          <h3>{review.title}</h3>
          <div dangerouslySetInnerHTML={{ __html: review.body }} />
          {review.images.map(img => <img src={img} />)}
        </div>
      ))}
    </div>
  );
};
```

### 画像アップロード
- S3にアップロードする
- ライブラリは適当なものを使う
- 画像のリサイズはクライアント側で行う
