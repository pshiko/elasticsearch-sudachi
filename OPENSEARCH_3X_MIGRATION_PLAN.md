# OpenSearch 3.x Migration Plan

## 概要
OpenSearch 3.x対応のための段階的移行計画。後方互換性を保ちながら対応を実施。

## 主要変更点

### OpenSearch 3.0/3.1の重要な変更
- **JDK21必須**: 最小Java実行環境がJDK21
- **Apache Lucene 10**: Lucene 9.x → 10.x
- **Java Security Manager削除**: JSMが永続的に無効化
- **API変更**: 非包含的用語の削除、非推奨メソッドの削除
- **XContentの制限**: JSON処理に新しい制限
- **HttpClient 5.x**: クライアントトランスポートの移行

## 実装方針

### 1. engines.groovy の拡張
```groovy
enum OsSupport implements EngineSupport {
    Os20("os-2.00"),
    Os27("os-2.07"),
    Os210("os-2.10"),
    Os30("os-3.00"),    // NEW: OpenSearch 3.0対応
    Os31("os-3.01"),    // NEW: OpenSearch 3.1対応

    static OsSupport supportVersion(Version version) {
        if (version.ge(2, 0) && version.lt(2, 7)) {
            return Os20
        } else if (version.ge(2, 7) && version.lt(2, 10)) {
            return Os27
        } else if (version.ge(2, 10) && version.lt(3, 0)) {
            return Os210
        } else if (version.ge(3, 0) && version.lt(3, 1)) {
            return Os30    // NEW
        } else if (version.ge(3, 1)) {
            return Os31    // NEW
        }
        throw new Exception("unsupported version")
    }
}
```

### 2. ext/ディレクトリ構造
```
src/main/ext/
├── os-2.00-ge/    # 既存: OpenSearch 2.0+
├── os-2.07-ge/    # 既存: OpenSearch 2.7+
├── os-2.07-lt/    # 既存: OpenSearch 2.7未満
├── os-3.00-ge/    # NEW: OpenSearch 3.0+ (Lucene 10, JDK21)
└── os-3.01-ge/    # NEW: OpenSearch 3.1+ (追加の変更があれば)
```

### 3. 必要なファイル
OpenSearch 3.x用の互換性ファイル:
- `factory-adapters.kt`: 非推奨API対応
- `lucene-aliases.kt`: Lucene 10対応
- `xcontent-aliases.kt`: XContent制限対応
- `search-engine-aliases.kt`: API変更対応

### 4. build.gradle の条件分岐
```kotlin
// JDK version selection based on engine version
compileKotlin {
    val engineVersion = project.findProperty("engineVersion") as String? ?: "os:2.18.0"
    val jvmTarget = if (engineVersion.startsWith("os:3.")) {
        JvmTarget.JVM_21  // OpenSearch 3.x
    } else {
        JvmTarget.JVM_11  // OpenSearch 2.x以下
    }
    compilerOptions.jvmTarget.set(jvmTarget)
}
```

## 実装スケジュール

### Phase 1: 基盤構築 (高優先度)
1. engines.groovy拡張 - OpenSearch 3.0/3.1対応追加
2. JDK21対応Dockerfile作成
3. 基本的なext/ファイル作成

### Phase 2: 互換性レイヤー実装 (中優先度)
1. factory-adapters.kt - API変更対応
2. lucene-aliases.kt - Lucene 10対応
3. xcontent-aliases.kt - XContent制限対応

### Phase 3: テスト・検証 (中優先度)
1. OpenSearch 3.1環境でのIntegration Test
2. 後方互換性テスト
3. Performance testing

### Phase 4: CI/CD対応 (低優先度)
1. GitHub Actions更新
2. 複数バージョン対応ビルド

## 注意事項
- OpenSearch 2.x環境での動作は引き続き保証
- JDK21必須環境でのみOpenSearch 3.x対応
- 段階的移行により影響を最小化