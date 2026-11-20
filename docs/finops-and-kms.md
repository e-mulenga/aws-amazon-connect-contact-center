# FinOps and encryption

## Encryption statement

Dev and Test use AWS-managed encryption keys (SSE-S3 on the recordings bucket, the AWS-managed key on DynamoDB and Secrets Manager). Prod uses customer-managed keys (CMK) where governance requires them, following the Landing Zone `key_strategy` output. The Landing Zone currently publishes `key_strategy = "aws-managed"`, so this repository creates no keys and no key cost. When the Landing Zone switches to CMK, the recordings bucket uses `shared_kms_keys.s3` and the tables use `shared_kms_keys.analytics`; the Landing Zone key policy must allow the Connect service principal to use the S3 key.

## Cost drivers

| Driver | Billed by | Guard |
|---|---|---|
| Connect voice and chat | Minutes of use | `queue_max_contacts`, `concurrent-calls-high` alarm |
| Claimed phone number | Monthly per number | `claim_phone_number = false` by default |
| Lex V2 | Requests | `lex_idle_session_ttl_seconds` keeps sessions short; conversation logs off |
| Contact Lens | Analysed minutes | Post-call only; switch off with `enable_contact_lens_analytics` |
| S3 recordings | GB-month | 90-day expiry, 7-day noncurrent expiry |
| DynamoDB | Per request | On-demand; TTL on callbacks and interactions |
| Secrets Manager | One secret per environment | Fixed small cost |
| CloudWatch | Alarms, logs, dashboard | 14-day log retention; first three dashboards free |

Everything is tagged `Project`, `Environment`, `Owner` and `CostCenter` through provider default tags, so the bill can be filtered per environment.

## Not created here

KMS keys, the SNS alert topic, log buckets and the backup vault belong to the Landing Zone and are only read.
