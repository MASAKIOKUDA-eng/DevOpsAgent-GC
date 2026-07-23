# 障害カタログ - DevOps Agent 検知テスト (Google Cloud)

このドキュメントは、Terraformコードに注入されたすべての障害と、
DevOps Agentが検知すべき期待される結果をまとめたものです。

**重要**: このコードは `terraform apply` が成功する（デプロイ可能）レベルですが、
デプロイ後に運用上・セキュリティ上の問題が発生するように設計されています。

---

## 障害サマリ

| ID | カテゴリ | 重大度 | ファイル | 概要 |
|----|---------|--------|---------|------|
| FAULT-NET-01 | ネットワーク | Critical | vpc.tf | Cloud NATなし - プライベートサブネットからインターネット不通 |
| FAULT-NET-02 | 可用性 | High | vpc.tf | 単一ゾーンのみにサブネット配置 |
| FAULT-NET-03 | ネットワーク | High | vpc.tf | Private Google Access無効 |
| FAULT-SEC-01 | セキュリティ | High | firewall_rules.tf | LBファイアウォールが全ポート開放 |
| FAULT-SEC-02 | 設定 | Critical | firewall_rules.tf | アプリ用ファイアウォールのポート不一致 |
| FAULT-SEC-03 | セキュリティ | Critical | firewall_rules.tf | Cloud SQL用ファイアウォールが0.0.0.0/0許可 |
| FAULT-SEC-04 | ネットワーク | High | firewall_rules.tf | アプリ→Cloud SQL通信不許可 |
| FAULT-LB-01 | 可用性 | High | load_balancer.tf | Serverless NEGが単一リージョンのみ |
| FAULT-LB-02 | 設定 | High | load_balancer.tf | ヘルスチェックパス不正 |
| FAULT-LB-03 | 設定 | Critical | load_balancer.tf | ヘルスチェックポート不一致 |
| FAULT-LB-04 | 運用 | Medium | load_balancer.tf | ログが無効 |
| FAULT-RUN-01 | パフォーマンス | High | cloud_run.tf | CPU/メモリ不足 |
| FAULT-RUN-02 | 可用性 | High | cloud_run.tf | max_instance_count=1 |
| FAULT-RUN-03 | 設定 | Critical | cloud_run.tf | コンテナポート(3000)とFW/ヘルスチェックポート(8080)不一致 |
| FAULT-RUN-04 | 運用 | Medium | cloud_run.tf | ログ設定なし |
| FAULT-RUN-05 | セキュリティ | Critical | cloud_run.tf | Artifact Registry権限なし |
| FAULT-SQL-01 | 可用性 | High | cloud_sql.tf | 高可用性(HA)無効 |
| FAULT-SQL-02 | セキュリティ | Critical | cloud_sql.tf | パブリックIP有効 |
| FAULT-SQL-03 | セキュリティ | High | cloud_sql.tf | CMEK暗号化なし |
| FAULT-SQL-04 | 可用性 | Critical | cloud_sql.tf | 自動バックアップ無効 |
| FAULT-SQL-05 | セキュリティ | Critical | cloud_sql.tf | パスワードハードコード |
| FAULT-SQL-06 | 運用 | High | cloud_sql.tf | 削除保護なし |

---

## 詳細説明

### ネットワーク障害

#### FAULT-NET-01: Cloud NATなし
- **ファイル**: `vpc.tf`
- **重大度**: Critical
- **デプロイ**: 成功（Cloud NATがなくてもVPCは作成可能）
- **影響**: プライベートサブネットからインターネットアクセス不可。VPCコネクタ経由のCloud RunがArtifact Registryに到達できない。
- **期待される検知**: 「プライベートサブネットにCloud NATまたはPrivate Google Accessが設定されていません」
- **AWS対応**: FAULT-NET-01 (NAT Gateway なし)

#### FAULT-NET-02: 単一ゾーンのみにサブネット配置
- **ファイル**: `vpc.tf`
- **重大度**: High
- **デプロイ**: 成功（単一サブネットでもVPCは作成可能）
- **影響**: ゾーン障害時にサービスが停止。冗長性なし。
- **期待される検知**: 「単一ゾーンのみにリソースが配置されています」
- **AWS対応**: FAULT-NET-02 (単一AZ)

#### FAULT-NET-03: Private Google Access無効
- **ファイル**: `vpc.tf`
- **重大度**: High
- **デプロイ**: 成功（Private Google Access無効でもサブネットは作成可能）
- **影響**: パブリックIPがないVMやCloud Runインスタンスから Google API にアクセスできない
- **期待される検知**: 「Private Google Accessが無効です」
- **AWS対応**: FAULT-NET-03 (ルートテーブル未関連付け)

---

### セキュリティ障害（ファイアウォール）

#### FAULT-SEC-01: LBファイアウォールが全ポート開放
- **ファイル**: `firewall_rules.tf`
- **重大度**: High
- **デプロイ**: 成功（protocol=allでもファイアウォールは作成可能）
- **影響**: 全ポートで外部からのトラフィックを受け入れ。攻撃対象領域の拡大。
- **期待される検知**: 「ファイアウォールルールが0.0.0.0/0から全プロトコルへのアクセスを許可しています」
- **AWS対応**: FAULT-SEC-01 (ALBのSGが全ポート開放)

#### FAULT-SEC-02: アプリ用ファイアウォールのポート不一致
- **ファイル**: `firewall_rules.tf`
- **重大度**: Critical
- **デプロイ**: 成功（ファイアウォール自体は作成可能）
- **影響**: LBからのポート3000のトラフィックがファイアウォール(8080許可)でブロックされる
- **期待される検知**: 「ファイアウォールのIngressポート(8080)がコンテナポート(3000)と一致しません」
- **AWS対応**: FAULT-SEC-02 (ECSのSGポート不一致)

#### FAULT-SEC-03: Cloud SQL用ファイアウォールが0.0.0.0/0許可
- **ファイル**: `firewall_rules.tf`
- **重大度**: Critical
- **デプロイ**: 成功（ファイアウォール自体は作成可能）
- **影響**: データベースがインターネットから直接アクセス可能。データ漏洩リスク。
- **期待される検知**: 「Cloud SQLへのファイアウォールルールがパブリックアクセス(0.0.0.0/0)を許可しています」
- **AWS対応**: FAULT-SEC-03 (RDSのSGが0.0.0.0/0許可)

#### FAULT-SEC-04: アプリ→Cloud SQL通信不許可
- **ファイル**: `firewall_rules.tf`
- **重大度**: High
- **デプロイ**: 成功（ルールがなくてもデプロイは可能）
- **影響**: アプリケーションからDBへの接続がブロックされる
- **期待される検知**: 「アプリケーションからCloud SQLへの通信がファイアウォールで許可されていません」
- **AWS対応**: FAULT-SEC-04 (ECS→RDS通信不許可)

---

### ロードバランサー障害

#### FAULT-LB-01: 単一リージョンのみ
- **ファイル**: `load_balancer.tf`
- **重大度**: High
- **デプロイ**: 成功（単一NEGでもLBは作成可能）
- **影響**: リージョン障害時にサービス停止。
- **期待される検知**: 「ロードバランサーのバックエンドが単一リージョンのみです」
- **AWS対応**: FAULT-ALB-01 (単一サブネット - ただしAWSではこれでapply失敗)

#### FAULT-LB-02: ヘルスチェックパス不正
- **ファイル**: `load_balancer.tf`
- **重大度**: High
- **デプロイ**: 成功（パスが不正でもヘルスチェック自体は作成可能）
- **影響**: ヘルスチェックが常に失敗し、バックエンドがunhealthyになる
- **期待される検知**: 「ヘルスチェックパス(/api/healthcheck)がアプリケーションのエンドポイントと一致しません」
- **AWS対応**: FAULT-ALB-02 (ヘルスチェックパス不正)

#### FAULT-LB-03: ヘルスチェックポート不一致
- **ファイル**: `load_balancer.tf`
- **重大度**: Critical
- **デプロイ**: 成功（ポートが不正でもヘルスチェック自体は作成可能）
- **影響**: コンテナポート3000に対しポート8080でヘルスチェック → 常にunhealthy
- **期待される検知**: 「ヘルスチェックのポート(8080)がコンテナのリッスンポート(3000)と一致しません」
- **AWS対応**: FAULT-ALB-03 (ターゲットグループポート不一致)

#### FAULT-LB-04: ログが無効
- **ファイル**: `load_balancer.tf`
- **重大度**: Medium
- **デプロイ**: 成功（ログ無効でもLBは作成可能）
- **影響**: 障害時のトラブルシューティングが困難
- **期待される検知**: 「バックエンドサービスのログが無効化されています」
- **AWS対応**: FAULT-ALB-04 (アクセスログ無効)

---

### Cloud Run障害 (ECS Fargate相当)

#### FAULT-RUN-01: CPU/メモリ不足
- **ファイル**: `cloud_run.tf`
- **重大度**: High
- **デプロイ**: 成功（リソース制限値は有効範囲内）
- **影響**: アプリケーションがリソース不足でOOMKillまたはスロットリング
- **期待される検知**: 「Cloud Runコンテナのリソース制限が不十分です」
- **AWS対応**: FAULT-ECS-01 (CPU/メモリ不足)

#### FAULT-RUN-02: max_instance_count=1
- **ファイル**: `cloud_run.tf`
- **重大度**: High
- **デプロイ**: 成功（max=1は有効な値）
- **影響**: 単一インスタンスの障害でサービス停止。スケールアウト不可。
- **期待される検知**: 「max_instance_countが1です。冗長性がありません」
- **AWS対応**: FAULT-ECS-02 (desired_count=1)

#### FAULT-RUN-03: コンテナポート不一致
- **ファイル**: `cloud_run.tf`
- **重大度**: Critical
- **デプロイ**: 成功（ポート値自体は有効）
- **影響**: ヘルスチェックとファイアウォールがポート8080を期待するが、コンテナは3000で起動
- **期待される検知**: 「コンテナポート(3000)とヘルスチェック/ファイアウォールのポート(8080)が不一致」
- **AWS対応**: FAULT-ECS-03 (コンテナポートとTGポートの不一致)

#### FAULT-RUN-04: ログ設定なし
- **ファイル**: `cloud_run.tf`
- **重大度**: Medium
- **デプロイ**: 成功（ログ設定なしでもデプロイ可能）
- **影響**: 障害時のデバッグが困難
- **期待される検知**: 「構造化ログの設定がありません」
- **AWS対応**: FAULT-ECS-04 (CloudWatch Logs設定なし)

#### FAULT-RUN-05: Artifact Registry権限なし
- **ファイル**: `cloud_run.tf`
- **重大度**: Critical
- **デプロイ**: サービスアカウントは作成されるが、IAM権限が付与されない
- **影響**: プライベートリポジトリからのイメージPullに失敗（※現在のコードはパブリックイメージを使用するため回避）
- **期待される検知**: 「サービスアカウントにartifactregistry.readerロールが付与されていません」
- **AWS対応**: FAULT-ECS-05 (ECR Pull権限なし)

---

### Cloud SQL障害 (RDS相当)

#### FAULT-SQL-01: 高可用性(HA)無効
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **デプロイ**: 成功（ZONALは有効な値）
- **影響**: 単一ゾーン障害でDB停止。フェイルオーバー不可。
- **期待される検知**: 「availability_typeがZONALです。高可用性が無効です」
- **AWS対応**: FAULT-RDS-01 (Multi-AZ無効)

#### FAULT-SQL-02: パブリックIP有効
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **デプロイ**: 成功（ipv4_enabled=trueは有効）
- **影響**: DBがインターネットから直接アクセス可能
- **期待される検知**: 「Cloud SQLのパブリックIPが有効です」
- **AWS対応**: FAULT-RDS-02 (publicly_accessible = true)

#### FAULT-SQL-03: CMEK暗号化なし
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **デプロイ**: 成功（デフォルト暗号化で動作）
- **影響**: Googleデフォルト暗号化のみ。コンプライアンス要件によっては不十分。
- **期待される検知**: 「CMEK暗号化が設定されていません」
- **AWS対応**: FAULT-RDS-03 (暗号化無効)

#### FAULT-SQL-04: 自動バックアップ無効
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **デプロイ**: 成功（backup enabled=falseは有効）
- **影響**: データ損失時に復旧不能
- **期待される検知**: 「自動バックアップが無効です」
- **AWS対応**: FAULT-RDS-04 (backup_retention_period = 0)

#### FAULT-SQL-05: パスワードハードコード
- **ファイル**: `cloud_sql.tf`
- **重大度**: Critical
- **デプロイ**: 成功（パスワード値自体は有効）
- **影響**: パスワードがソースコードに平文保存。漏洩リスク。
- **期待される検知**: 「パスワードがTerraformコードにハードコードされています」
- **AWS対応**: FAULT-RDS-05 (パスワードハードコード)

#### FAULT-SQL-06: 削除保護なし
- **ファイル**: `cloud_sql.tf`
- **重大度**: High
- **デプロイ**: 成功（deletion_protection=falseは有効）
- **影響**: 誤操作でDBが削除される可能性
- **期待される検知**: 「削除保護が無効です」
- **AWS対応**: FAULT-RDS-06 (deletion_protection = false)

---

## AWS版との障害対応表

| AWS 障害ID | GCP 障害ID | 説明 |
|-----------|-----------|------|
| FAULT-NET-01 | FAULT-NET-01 | NAT Gateway / Cloud NAT なし |
| FAULT-NET-02 | FAULT-NET-02 | 単一AZ / 単一ゾーン |
| FAULT-NET-03 | FAULT-NET-03 | ルートテーブル未関連付け / Private Google Access無効 |
| FAULT-SEC-01 | FAULT-SEC-01 | ALB SG / LB FW 全ポート開放 |
| FAULT-SEC-02 | FAULT-SEC-02 | ECS SG / App FW ポート不一致 |
| FAULT-SEC-03 | FAULT-SEC-03 | RDS SG / SQL FW 0.0.0.0/0 |
| FAULT-SEC-04 | FAULT-SEC-04 | ECS→RDS / App→SQL 通信不許可 |
| FAULT-ALB-01 | FAULT-LB-01 | 単一サブネット / 単一NEG |
| FAULT-ALB-02 | FAULT-LB-02 | ヘルスチェックパス不正 |
| FAULT-ALB-03 | FAULT-LB-03 | TGポート / ヘルスチェックポート不一致 |
| FAULT-ALB-04 | FAULT-LB-04 | アクセスログ無効 |
| FAULT-ECS-01 | FAULT-RUN-01 | CPU/メモリ不足 |
| FAULT-ECS-02 | FAULT-RUN-02 | desired_count=1 / max_instance=1 |
| FAULT-ECS-03 | FAULT-RUN-03 | コンテナポート不一致 |
| FAULT-ECS-04 | FAULT-RUN-04 | ログ設定なし |
| FAULT-ECS-05 | FAULT-RUN-05 | ECR Pull / Artifact Registry権限なし |
| FAULT-RDS-01 | FAULT-SQL-01 | Multi-AZ / HA無効 |
| FAULT-RDS-02 | FAULT-SQL-02 | パブリックアクセス有効 |
| FAULT-RDS-03 | FAULT-SQL-03 | 暗号化無効 / CMEK未設定 |
| FAULT-RDS-04 | FAULT-SQL-04 | バックアップ無効 |
| FAULT-RDS-05 | FAULT-SQL-05 | パスワードハードコード |
| FAULT-RDS-06 | FAULT-SQL-06 | 削除保護なし |

---

## 検知レベルの期待値

### 必須検知（Critical）
DevOps Agentが**必ず検知すべき**障害：
- FAULT-NET-01
- FAULT-SEC-02, FAULT-SEC-03
- FAULT-LB-03
- FAULT-RUN-03, FAULT-RUN-05
- FAULT-SQL-02, FAULT-SQL-04, FAULT-SQL-05

### 推奨検知（High）
検知が**強く期待される**障害：
- FAULT-NET-02, FAULT-NET-03
- FAULT-SEC-01, FAULT-SEC-04
- FAULT-LB-01, FAULT-LB-02
- FAULT-RUN-01, FAULT-RUN-02
- FAULT-SQL-01, FAULT-SQL-03, FAULT-SQL-06

### オプション検知（Medium）
検知できると**なお良い**障害：
- FAULT-LB-04
- FAULT-RUN-04

---

## スコアリング

| 検知数 | 評価 |
|--------|------|
| 19-22 | Excellent - 全障害を網羅的に検知 |
| 14-18 | Good - 主要な障害を検知 |
| 9-13 | Fair - 基本的な障害を検知 |
| 4-8 | Poor - 一部のみ検知 |
| 0-3 | Insufficient - 検知能力が不十分 |
