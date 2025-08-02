# OpenSearch 3.1 + Sudachi Plugin クイックスタートガイド

## 🚀 5分で始めるSudachi Plugin

### 前提条件
- Docker & Docker Compose インストール済み
- 親ディレクトリでSudachiプラグインがビルド済み

### ステップ1: プラグインビルド（未実施の場合）
```bash
cd ..
docker build -f Dockerfile.build-jdk21 --build-arg ENGINE_VERSION=os:3.1.0 -t sudachi-builder-jdk21 .
docker run --rm -v $(pwd):/host_workspace sudachi-builder-jdk21 sh -c "mkdir -p /host_workspace/build-jdk21 && cp -r /output/* /host_workspace/build-jdk21/"
cd opensearch-3.1-sudachi
```

### ステップ2: 自動ビルド・テスト実行
```bash
./build-and-test.sh
```

### ステップ3: 手動テスト
```bash
# 起動確認
curl http://localhost:9200

# Sudachi解析テスト
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"analyzer": "sudachi", "text": "私は日本語を勉強しています"}'
```

## 📊 テスト例

### 1. 基本的な形態素解析
```bash
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "analyzer": "sudachi",
    "text": "すもももももももものうち"
  }'
```

**期待される結果**: "すもも", "も", "もも", "も", "もも", "の", "うち"

### 2. 固有名詞の解析
```bash
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "tokenizer": "sudachi_tokenizer",
    "text": "東京都渋谷区恵比寿"
  }'
```

### 3. インデックス作成とサーチ
```bash
# インデックス作成
curl -X PUT "http://localhost:9200/my-index" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "analysis": {
        "analyzer": {
          "default": {"type": "sudachi"}
        }
      }
    }
  }'

# ドキュメント追加
curl -X POST "http://localhost:9200/my-index/_doc/1" \
  -H "Content-Type: application/json" \
  -d '{"title": "日本語検索テスト", "content": "これは日本語の全文検索のテストです。"}'

# 検索実行
curl -X GET "http://localhost:9200/my-index/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match": {"content": "検索"}}}'
```

## 🛠️ カスタマイズ

### Sudachi設定変更
```json
{
  "settings": {
    "analysis": {
      "tokenizer": {
        "my_sudachi": {
          "type": "sudachi_tokenizer",
          "split_mode": "A",
          "discard_punctuation": false
        }
      },
      "analyzer": {
        "my_analyzer": {
          "tokenizer": "my_sudachi",
          "filter": ["sudachi_baseform"]
        }
      }
    }
  }
}
```

### 分割モード
- **A**: 最短単位（UniDic短単位相当）
- **B**: 中間単位
- **C**: 最長単位（デフォルト、固有名詞抽出）

## 🔧 トラブルシューティング

### メモリ不足の場合
```bash
# docker-compose.ymlで調整
environment:
  - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"
```

### ログ確認
```bash
docker-compose logs -f opensearch-sudachi
```

### 停止・再起動
```bash
# 停止
docker-compose down

# 再起動
docker-compose up -d
```

## 📈 パフォーマンス

### OpenSearch 3.1の改善点
- **Lucene 10**: 検索性能の向上
- **JDK 21**: JVM性能の最適化
- **G1GC**: より効率的なガベージコレクション

### ベンチマーク例
```bash
# 大量データでのテスト
for i in {1..1000}; do
  curl -X POST "http://localhost:9200/benchmark/_doc/$i" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"テストドキュメント番号 $i です。日本語検索のパフォーマンステストを実行中。\"}"
done
```

## 🎯 次のステップ

1. **プロダクション設定**: セキュリティ有効化
2. **クラスター構成**: 複数ノード設定
3. **モニタリング**: メトリクス収集設定
4. **バックアップ**: スナップショット設定

Happy Searching! 🔍