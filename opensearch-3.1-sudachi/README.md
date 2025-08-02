# OpenSearch 3.1.0 with Sudachi Plugin

このディレクトリにはOpenSearch 3.1.0にSudachi日本語形態素解析プラグインを組み込んだDockerイメージの設定が含まれています。

## 前提条件

1. **Sudachiプラグインのビルド**が完了していること
   ```bash
   # 親ディレクトリで実行
   docker build -f Dockerfile.build-jdk21 --build-arg ENGINE_VERSION=os:3.1.0 -t sudachi-builder-jdk21 .
   docker run --rm -v $(pwd):/host_workspace sudachi-builder-jdk21 sh -c "mkdir -p /host_workspace/build-jdk21 && cp -r /output/* /host_workspace/build-jdk21/"
   ```

2. **Docker**と**Docker Compose**がインストール済みであること

## 構成ファイル

### メインファイル
- `Dockerfile`: OpenSearch 3.1.0 + Sudachiプラグインのカスタムイメージ
- `docker-compose.yml`: コンテナ管理設定
- `README.md`: このファイル

### 設定ファイル
- `config/opensearch.yml`: OpenSearch設定（Sudachi analyzer含む）
- `config/jvm.options`: JVM設定（JDK21対応）

## 使用方法

### 1. イメージのビルド
```bash
cd opensearch-3.1-sudachi
docker-compose build
```

### 2. コンテナの起動
```bash
docker-compose up -d
```

### 3. ヘルスチェック
```bash
curl http://localhost:9200/_cluster/health
```

### 4. Sudachi動作確認
```bash
# 基本的なSudachi解析テスト
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "analyzer": "sudachi",
    "text": "すもももももももものうち"
  }'
```

## Sudachi設定

### デフォルト設定
- **辞書**: system_core.dic（コア辞書）
- **分割モード**: C（最長一致）
- **フィルター**: baseform, part_of_speech, ja_stop

### カスタマイズ例

#### インデックス作成時のSudachi設定
```json
{
  "settings": {
    "analysis": {
      "tokenizer": {
        "sudachi_tokenizer": {
          "type": "sudachi_tokenizer",
          "split_mode": "C",
          "discard_punctuation": true
        }
      },
      "analyzer": {
        "my_sudachi_analyzer": {
          "type": "custom",
          "tokenizer": "sudachi_tokenizer",
          "filter": [
            "sudachi_baseform",
            "sudachi_part_of_speech",
            "sudachi_ja_stop"
          ]
        }
      }
    }
  }
}
```

## テストシナリオ

### 1. 基本解析テスト
```bash
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"analyzer": "sudachi", "text": "東京都渋谷区"}'
```

### 2. インデックスとサーチテスト
```bash
# インデックス作成
curl -X PUT "http://localhost:9200/test-sudachi" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "analysis": {
        "analyzer": {
          "default": {
            "type": "sudachi"
          }
        }
      }
    }
  }'

# ドキュメント追加
curl -X POST "http://localhost:9200/test-sudachi/_doc/1" \
  -H "Content-Type: application/json" \
  -d '{"content": "私は東京駅から新宿駅まで電車で移動しました。"}'

# 検索
curl -X GET "http://localhost:9200/test-sudachi/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match": {"content": "電車"}}}'
```

## トラブルシューティング

### よくある問題

1. **メモリ不足**
   - `docker-compose.yml`のメモリ設定を調整
   - `config/jvm.options`のヒープサイズを調整

2. **プラグインが見つからない**
   - 親ディレクトリでプラグインがビルド済みか確認
   - `build-jdk21/distributions/`にzipファイルがあるか確認

3. **辞書エラー**
   - インターネット接続を確認（辞書ダウンロード用）
   - 手動で辞書をダウンロードしてDockerfileを修正

### ログ確認
```bash
# コンテナログ確認
docker-compose logs -f opensearch-sudachi

# OpenSearchログ確認
docker exec opensearch-3.1-sudachi tail -f /usr/share/opensearch/logs/opensearch-sudachi-cluster.log
```

## 停止・クリーンアップ

```bash
# コンテナ停止
docker-compose down

# データも削除する場合
docker-compose down -v

# イメージも削除する場合
docker-compose down --rmi all -v
```

## バージョン情報

- **OpenSearch**: 3.1.0
- **JDK**: 21 (Temurin)
- **Lucene**: 10.2.1
- **Sudachi Plugin**: 3.3.1-SNAPSHOT
- **Sudachi Dictionary**: 20241021 (core)

## サポート

- [OpenSearch Documentation](https://docs.opensearch.org/)
- [Sudachi Plugin GitHub](https://github.com/WorksApplications/elasticsearch-sudachi)
- [SudachiDict GitHub](https://github.com/WorksApplications/SudachiDict)