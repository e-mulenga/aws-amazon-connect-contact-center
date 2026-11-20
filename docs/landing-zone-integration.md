# Landing Zone integration

`landing_zone.tf` reads the Landing Zone state with `terraform_remote_state` and checks the contract before anything is created.

| Landing Zone output | Used for |
|---|---|
| `contract_schema_version` | Precondition: must equal `expected_landing_zone_contract_version` ("2") |
| `key_strategy`, `shared_kms_keys.s3`, `shared_kms_keys.analytics` | CMK for recordings and tables only when the strategy is not aws-managed |
| `monitoring_topic_arn` | Alarm notifications (same Region as the alarms) |
| `github_oidc_provider_arn` | Trust for the optional plan and apply roles |
| `organization_id` | Available for org-scoped conditions |
| `terraform_state` | State bucket for this stack's own state key |

## Never created here

VPCs, subnets, NAT, endpoints, KMS keys, the Route 53 zone, ACM certificates, the platform SNS topic, logging buckets, GuardDuty, Security Hub, flow logs, backup vaults, ECR repositories, state buckets and the GitHub OIDC provider. Connect, Lex, Lambda and DynamoDB need no VPC, so the existing VPCs are simply unused.

## Setup

Copy `environments/<env>/terraform.tfvars.example` and point `landing_zone_state_bucket`, `landing_zone_state_key` and `landing_zone_state_region` at the Landing Zone `terraform_state` output. This stack's own state key is `aws-amazon-connect-contact-center/<env>.tfstate` in the same bucket.
