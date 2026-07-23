# GCP DevOps Agent 障害検知テスト用 Terraform コード

## 概要

このTerraformコードは、GCP DevOps Agentの障害検知能力を検証するために、
シンプルなWebサービス構成（Cloud Load Balancing + Cloud Run + Cloud SQL）に**意図的な障害**を注入したものです。

**重要**: コードは `terraform apply` が成功する（デプロイ可能な）レベルですが、
デプロイ後に運用上・セキュリティ上の問題が発生するように設計されています。

## アーキテクチャ

```
Internet
    |
[Cloud Load Balancing (HTTP LB)]
    |
[Cloud Run Service]
    |
[Cloud SQL for PostgreSQL]
```

## AWS版 (DevOpsAgent-AWS) との対応関係

| AWS リソース | GCP リソース | ファイル |
|-------------|-------------|---------|
| VPC / Subnet | VPC Network / Subnetwork | vpc.tf |
| Security Group | Firewall Rules | firewall_rules.tf |
| NAT Gateway | Cloud NAT | vpc.tf |
| ALB (Application Load Balancer) | Cloud Load Balancing (HTTP(S) LB) | load_balancer.tf |
| ECS Fargate | Cloud Run | cloud_run.tf |
| RDS PostgreSQL | Cloud SQL for PostgreSQL | cloud_sql.tf |
| IAM Role | Service Account | cloud_run.tf |
| CloudWatch Logs | Cloud Logging | (設定なし = 障害) |

## 注入された障害カテゴリ

| カテゴリ | 障害数 | 説明 |
|---------|--------|------|
| ネットワーク | 3 | Cloud NAT/Router欠如、Private Google Access無効 |
| セキュリティ（FW） | 4 | ファイアウォール設定ミス、ポート不一致 |
| ロードバランサー | 4 | ヘルスチェック不備、HTTPS未設定 |
| Cloud Run | 5 | リソース不足、権限不足、ポート不整合 |
| Cloud SQL | 6 | パブリック公開、暗号化なし、バックアップなし |

**合計: 22個の障害** (Critical: 9, High: 11, Medium: 2)

## ファイル構成

```
terraform-fault-injection/
├── README.md                 # このファイル
├── FAULT_CATALOG.md          # 障害一覧と期待される検知結果
├── main.tf                   # プロバイダー設定
├── variables.tf              # 変数定義
├── outputs.tf                # 出力定義
├── vpc.tf                    # VPC・ネットワーク構成
├── firewall_rules.tf         # ファイアウォールルール
├── load_balancer.tf          # Cloud Load Balancing
├── cloud_run.tf              # Cloud Run サービス
└── cloud_sql.tf              # Cloud SQL for PostgreSQL
```

## デプロイ方法

```bash
# 初期化
terraform init

# プラン確認（障害は含むがterraformとしては有効）
terraform plan -var="gcp_project_id=YOUR_PROJECT_ID"

# デプロイ（実際に問題のあるインフラが構築される）
terraform apply -var="gcp_project_id=YOUR_PROJECT_ID"

# 削除
terraform destroy -var="gcp_project_id=YOUR_PROJECT_ID"
```

## DevOps Agent テスト

```bash
# DevOps Agentに解析させる例
devops-agent analyze ./terraform-fault-injection/
```

## 注意事項

- ⚠️ このコードは意図的に問題を含んでいます
- ⚠️ 本番環境には絶対にデプロイしないでください
- ⚠️ テスト後は必ず `terraform destroy` でリソースを削除してください
- ⚠️ `terraform apply` は成功しますが、デプロイされたサービスは正常に動作しません
