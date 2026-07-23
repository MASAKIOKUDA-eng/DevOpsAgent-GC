# 障害カタログ - DevOps Agent 検知テスト (Google Cloud)

このドキュメントは、Terraformコードに注入されたすべての障害と、
DevOps Agentが検知すべき期待される結果をまとめたものです。

---

## 障害サマリ

| ID | カテゴリ | 重大度 | ファイル | 概要 |
|----|---------|--------|---------|------|
| FAULT-NET-01 | ネットワーク | Critical | vpc.tf | Cloud NATなし |
| FAULT-NET-02 | 可用性 | Critical | vpc.tf | 単一ゾーンのみにサブネット配置 |
| FAULT-NET-03 | ネットワーク | High | vpc.tf | Cloud Routerが存在しない |
| FAULT-SEC-01 | セキュリティ | High | firewall_rules.tf | LBファイアウォールが全ポート開放 |
| FAULT-SEC-02 | 設定 | Critical | firewall_rules.tf | アプリ用ファイアウォールのポート不一致 |
| FAULT-SEC-03 | セキュリティ | Critical | firewall_rules.tf | Cloud SQL用ファイアウォールが0.0.0.0/0許可 |
| FAULT-SEC-04 | ネットワーク | High | firewall_rules.tf | アプリ→Cloud SQL通信不許可 |
| FAULT-LB-01 | 設定 | High | load_balancer.tf | ヘルスチェックパス不正 |
| FAULT-LB-02 | 設定 | Critical | load_balancer.tf | ヘルスチェックポート不一致 |
| FAULT-LB-03 | セキュリティ | High | load_balancer.tf | SSL証明書なし・HTTPSなし |
| FAULT-LB-04 | セキュリティ | High | load_balancer.tf | Cloud Armor未設定 |
| FAULT-LB-05 | 運用 | Medium | load_balancer.tf | ログが無効 |
| FAULT-RUN-01 | パフォーマンス | High | cloud_run.tf | CPU/メモリ不足 |
| FAULT-RUN-02 | 可用性 | High | cloud_run.tf | max_instance_count=1 |
| FAULT-RUN-03 | 設定 | Critical | cloud_run.tf | コンテナポート不一致 |
| FAULT-RUN-04 | 運用 | Medium | cloud_run.tf | ログレベル不適切 |
| FAULT-RUN-05 | セキュリティ | Critical | cloud_run.tf | Artifact Registry権限なし |
| FAULT-RUN-06 | ネットワーク | Critical | cloud_run.tf | VPCコネクタ未設定 |
| FAULT-SQL-01 | 可用性 | High | cloud_sql.tf | 高可用性(HA)無効 |
| FAULT-SQL-02 | セキュリティ | Critical | cloud_sql.tf | パブリックIP有効 |
| FAULT-SQL-03 | セキュリティ | High | cloud_sql.tf | CMEK暗号化なし |
| FAULT-SQL-04 | 可用性 | Critical | cloud_sql.tf | 自動バックアップ無効 |
| FAULT-SQL-05 | セキュリティ | Critical | cloud_sql.tf | パスワードハードコード |
| FAULT-SQL-06 | 運用 | High | cloud_sql.tf | 削除保護なし |
| FAULT-SQL-07 | セキュリティ | Critical | cloud_sql.tf | Authorized Networks 0.0.0.0/0 |

---

## 詳細説明

### ネットワーク障害

#### FAULT-NET-01: Cloud NATなし
- **ファイル**: `vpc.tf`
- **重大度**: Critical
- **影響**: プライベートサブネットからインターネットアクセス不可。Cloud RunやGCEインスタンスがArtifact Registryからコンテナイメージを取得できない。
- **期待される検知**: 「プライベートサブネットにCloud NATまたはPrivate Google Accessが設定されていません」
- **修正方法**: Cloud Router + Cloud NATの追加、またはPrivate Google Accessの有効化

#### FAULT-NET-02: 単一ゾーンのみにサブネット配置
- **ファイル**: `vpc.tf`
- **重大度**: Critical
- **影響**: ゾーン障害時にサービス全体が停止。GCPのマネージドサービスの冗長性を活用できない。
- **期待される検知**: 「単一ゾーンのみにリソースが配置されており、ゾーン障害に対する耐性がありません」
- **修正方法**: 複数ゾーンにまたがるサブネット設計、またはリージョナルリソースの使用

#### FAULT-NET-03: Cloud Routerが存在しない
- **ファイル**: `vpc.tf`
- **重大度**: High
- **影響**: Cloud NATやCloud VPN、Cloud Interconnectの前提条件が欠落。動的ルーティングが不可能。
- **期待される検知**: 「Cloud Routerが存在しないため、Cloud NATやBGPベースの接続が構成できません」
- **修正方法**: google_compute_routerリソースの追加

---

### セキュリティ障害（ファイアウォール）

#### FAULT-SEC-01: LBファイアウォールが全ポート開放
- **ファイル**: `firewall_rules.tf`
- **重大度**: High
- **影響**: ロードバランサーが全ポートで外部からのトラフィックを受け入れる。攻撃対象領域の拡大。
- **期待される検知**: 「ファイアウォールルールが0.0.0.0/0から全プロトコルへのアクセスを許可しています」
- **修正方法**: TCP 80/443のみに制限

#### FAULT-SEC-02: アプリ用ファイアウォールのポート不一致
- **ファイル**: `firewall_rules.tf`
- **重大度**: Critical
- **影響**: LBからCloud Runサービスへの通信が到達不能。ヘルスチェックが失敗し、サービスが応答しない。
- **期待される検知**: 「ファイアウォールのIngressポート(8080)がコンテナポート(3000)と一致しません」
- **修正方法**: ファイアウォールのポートをコンテナポート3000に修正

#### FAULT-SEC-03: Cloud SQL用ファイアウォールが0.0.0.0/0許可
- **ファイル**: `firewall_rules.tf`
- **重大度**: Critical
- **影響**: データベースがインターネットから直接アクセス可能。データ漏洩リスク。
- **期待される検知**: 「Cloud SQLへのファイアウォールルールがパブリックアクセス(0.0.0.0/0)を許可しています」
- **修正方法**: アプリケーションタグからのアクセスのみに制限

#### FAULT-SEC-04: アプリ→Cloud SQL通信不許可
- **ファイル**: `firewall_rules.tf`
- **重大度**: High
- **影響**: Cloud RunからCloud SQLへの接続が確立できない。アプリケーションがDB接続エラーを返す。
- **期待される検知**: 「アプリケーションからCloud SQLへのPostgreSQL(5432)通信がファイアウォールで許可されていません」
- **修正方法**: source_tags=["app"], target_tags=["database"]のファイアウォールルール追加

---

### ロードバランサー障害

#### FAULT-LB-01: ヘルスチェックパス不正
- **ファイル**: `load_balancer.tf`
- **重大度**: High
- **影響**: ヘルスチェックが常に失敗し、バックエンドがunhealthyになる。トラフィックが転送されない。
- **期待される検知**: 「ヘルスチェックパス(/api/healthcheck)がアプリケーションの実際のエンドポイントと一致しない可能性があります」
- **修正方法**: アプリケーションの実際のヘルスチェックエンドポイント(/health)に修正

#### FAULT-LB-02: ヘルスチェックポート不一致
- **ファイル**: `load_balancer.tf`
- **重大度**: Critical
- **影響**: ヘルスチェックがポート8080に送信されるが、コンテナはポート3000でリッスン。バックエンドが常にunhealthy。
- **期待される検知**: 「ヘルスチェックのポート(8080)がコンテナのリッスンポート(3000)と一致しません」
- **修正方法**: ヘルスチェックのポートを3000に修正

#### FAULT-LB-03: SSL証明書なし・HTTPSなし
- **ファイル**: `load_balancer.tf`
- **重大度**: High
- **影響**: 通信が暗号化されない。中間者攻撃のリスク。コンプライアンス違反。
- **期待される検知**: 「ロードバランサーにSSL証明書が設定されておらず、HTTPのみで通信しています」
- **修正方法**: Google Managed SSL証明書の追加とHTTPS Target Proxyの作成

#### FAULT-LB-04: Cloud Armor未設定
- **ファイル**: `load_balancer.tf`
- **重大度**: High
- **影響**: DDoS攻撃やWebアプリケーション攻撃に対する保護がない。
- **期待される検知**: 「バックエンドサービスにCloud Armorセキュリティポリシーが設定されていません」
- **修正方法**: google_compute_security_policyリソースの作成とbackend_serviceへの関連付け

#### FAULT-LB-05: ログが無効
- **ファイル**: `load_balancer.tf`
- **重大度**: Medium
- **影響**: リクエストの監査証跡がなく、障害時のトラブルシューティングが困難。
- **期待される検知**: 「バックエンドサービスのログが無効化されています」
- **修正方法**: log_config { enable = true, sample_rate = 1.0 } に設定

---

### Cloud Run障害

#### FAULT-RUN-01: CPU/メモリ不足
- **ファイル**: `cloud_run.tf`
- **重大度**: High
- **影響**: アプリケーションがリソース不足でOOMKillまたはCPUスロットリング。レスポンスタイムの著しい悪化。
- **期待される検知**: 「Cloud Runコンテナのリソース制限(CPU: 0.25, Memory: 128Mi)が推奨値を大幅に下回っています」
- **修正方法**: CPU=1.0, Memory=512Mi以上に設定

#### FAULT-RUN-02: max_instance_count=1
- **ファイル**: `cloud_run.tf`
- **重大度**: High
- **影響**: 単一インスタンスの障害でサービス全体が停止。トラフィック増加時にスケールアウト不可。
- **期待される検知**: 「Cloud Runのmax_instance_countが1です。スケーラビリティと冗長性がありません」
- **修正方法**: max_instance_count=10以上に設定し、適切なスケーリング設計

#### FAULT-RUN-03: コンテナポート不一致
- **ファイル**: `cloud_run.tf`
- **重大度**: Critical
- **影響**: コンテナポート(3000)とヘルスチェックポート(8080)が整合していない。ヘルスチェック失敗。
- **期待される検知**: 「コンテナポート(3000)とヘルスチェック/ファイアウォールのポート(8080)が整合していません」
- **修正方法**: 全てをコンテナポート3000に統一

#### FAULT-RUN-04: ログレベル不適切
- **ファイル**: `cloud_run.tf`
- **重大度**: Medium
- **影響**: DEBUGレベルのログが大量に出力され、Cloud Loggingのコスト増大とノイズ増加。
- **期待される検知**: 「本番環境でログレベルがDEBUGに設定されています。INFO以上を推奨します」
- **修正方法**: LOG_LEVEL=INFO または WARNING に設定

#### FAULT-RUN-05: Artifact Registry権限なし
- **ファイル**: `cloud_run.tf`
- **重大度**: Critical
- **影響**: サービスアカウントにArtifact Registryの読み取り権限がなく、コンテナイメージのPullに失敗する。
- **期待される検知**: 「Cloud Runサービスアカウントにartifactregistry.readerロールが付与されていません」
- **修正方法**: google_project_iam_memberでroles/artifactregistry.readerを付与

#### FAULT-RUN-06: VPCコネクタ未設定
- **ファイル**: `cloud_run.tf`
- **重大度**: Critical
- **影響**: Cloud RunからVPC内のリソース（Cloud SQLプライベートIP等）にアクセスできない。
- **期待される検知**: 「Cloud RunにVPCアクセスコネクタが設定されておらず、プライベートネットワークへの通信ができません」
- **修正方法**: google_vpc_access_connectorの作成とCloud Runサービスへの設定

---

### Cloud SQL障害

#### FAULT-SQL-01: 高可用性(HA)無効
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **影響**: 単一ゾーンの障害でデータベースが停止。自動フェイルオーバー不可。
- **期待される検知**: 「Cloud SQLインスタンスのavailability_typeがZONALです。高可用性が無効です」
- **修正方法**: availability_type = "REGIONAL" に設定

#### FAULT-SQL-02: パブリックIP有効
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **影響**: データベースがインターネットから直接アクセス可能。Authorized Networksと組み合わさると深刻な脆弱性。
- **期待される検知**: 「Cloud SQLのipv4_enabledがtrueに設定されています。パブリックIPが有効です」
- **修正方法**: ipv4_enabled = false, private_network を設定しプライベート接続に変更

#### FAULT-SQL-03: CMEK暗号化なし
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **影響**: Googleデフォルト暗号化のみ。コンプライアンス要件によってはCMEK(顧客管理暗号化キー)が必要。
- **期待される検知**: 「Cloud SQLにCMEK(顧客管理暗号化キー)が設定されていません」
- **修正方法**: Cloud KMSキーの作成とencryption_key_nameの指定

#### FAULT-SQL-04: 自動バックアップ無効
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **影響**: データ損失時に復旧不能。ポイントインタイムリカバリが使用できない。
- **期待される検知**: 「Cloud SQLのバックアップが無効です。自動バックアップとPITRを有効にしてください」
- **修正方法**: backup_configuration { enabled = true, point_in_time_recovery_enabled = true }

#### FAULT-SQL-05: パスワードハードコード
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **影響**: パスワードがソースコードに平文で保存。バージョン管理システムを通じて漏洩リスク。
- **期待される検知**: 「Cloud SQLユーザーのパスワードがTerraformコードにハードコードされています」
- **修正方法**: Google Secret Managerを使用してパスワードを管理

#### FAULT-SQL-06: 削除保護なし
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **影響**: terraform destroyや誤操作で本番DBが削除される可能性。
- **期待される検知**: 「Cloud SQLの削除保護(deletion_protection)が無効です」
- **修正方法**: deletion_protection = true に設定

#### FAULT-SQL-07: Authorized Networks 0.0.0.0/0
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **影響**: 全IPアドレスからCloud SQLへの接続が許可される。ブルートフォース攻撃やデータ漏洩のリスク。
- **期待される検知**: 「Cloud SQLのauthorized_networksに0.0.0.0/0が設定されており、全世界からアクセス可能です」
- **修正方法**: 特定のIPレンジのみに制限、またはCloud SQL Auth Proxyの使用

---

## 検知レベルの期待値

### 必須検知（Critical）
DevOps Agentが**必ず検知すべき**障害：
- FAULT-NET-01, FAULT-NET-02
- FAULT-SEC-02, FAULT-SEC-03
- FAULT-LB-02
- FAULT-RUN-03, FAULT-RUN-05, FAULT-RUN-06
- FAULT-SQL-02, FAULT-SQL-04, FAULT-SQL-05, FAULT-SQL-07

### 推奨検知（High）
検知が**強く期待される**障害：
- FAULT-NET-03
- FAULT-SEC-01, FAULT-SEC-04
- FAULT-LB-01, FAULT-LB-03, FAULT-LB-04
- FAULT-RUN-01, FAULT-RUN-02
- FAULT-SQL-01, FAULT-SQL-03, FAULT-SQL-06

### オプション検知（Medium）
検知できると**なお良い**障害：
- FAULT-LB-05
- FAULT-RUN-04

---

## スコアリング

| 検知数 | 評価 |
|--------|------|
| 21-25 | Excellent - 全障害を網羅的に検知 |
| 16-20 | Good - 主要な障害を検知 |
| 11-15 | Fair - 基本的な障害を検知 |
| 6-10 | Poor - 一部のみ検知 |
| 0-5 | Insufficient - 検知能力が不十分 |
