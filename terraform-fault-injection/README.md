# GCP DevOps Agent 障害検知テスト用 Terraform コード

## 概要

このTerraformコードは、GCP DevOps Agentの障害検知能力を検証するために、
シンプルなWebサービス構成（Cloud Load Balancing + Cloud Run + Cloud SQL）に**意図的な障害**を注入したものです。

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

## 注入された障害カテゴリ

| カテゴリ | 障害数 | 説明 |
|---------|--------|------|
| ネットワーク | 3 | Cloud NAT/Router欠如、ルーティング不備 |
| セキュリティ（FW） | 4 | ファイアウォール設定ミス、ポート不一致 |
| ロードバランサー | 5 | ヘルスチェック不備、HTTPS/WAF未設定 |
| Cloud Run | 6 | リソース不足、権限不足、接続不備 |
| Cloud SQL | 7 | パブリック公開、暗号化なし、バックアップなし |

**合計: 25個の障害**

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

## AWS版との対応関係

| AWS リソース | GCP リソース |
|-------------|-------------|
| VPC / Subnet | VPC Network / Subnetwork |
| Security Group | Firewall Rules |
| NAT Gateway | Cloud NAT |
| ALB (Application Load Balancer) | Cloud Load Balancing (HTTP(S) LB) |
| ECS Fargate | Cloud Run |
| RDS PostgreSQL | Cloud SQL for PostgreSQL |
| IAM Role | Service Account |
| CloudWatch Logs | Cloud Logging |
| Secrets Manager | Secret Manager |
| AWS Shield / WAF | Cloud Armor |

## 使い方

このコードは**実際にデプロイするものではありません**。
DevOps Agentに静的解析させ、障害を検知できるかを確認するためのテストケースです。

```bash
# DevOps Agentに解析させる例
devops-agent analyze ./terraform-fault-injection/
```

## 注意事項

- ⚠️ このコードは意図的に問題を含んでいます
- ⚠️ 本番環境には絶対にデプロイしないでください
- ⚠️ 学習・テスト目的でのみ使用してください
