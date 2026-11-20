# Threat model

| # | Threat | Control |
|---|---|---|
| 1 | Customer phone numbers exposed from the customers table | Key is HMAC-SHA256 with a secret held in Secrets Manager; table holds tier, language and segment only |
| 2 | Phone numbers leak through logs | Handlers never log the number; tests assert interaction rows contain none; Lex conversation logs are off by default |
| 3 | Callback numbers kept longer than needed | TTL 7 days by default; rejected numbers never stored |
| 4 | Recordings read by the wrong party | Private bucket, public access blocked, TLS-only, bucket policy limits Connect to this account and instance; CMK when the Landing Zone requires |
| 5 | Another account or instance invokes the Lambdas or the bot | Lambda permission and Lex policy carry `SourceAccount` and `SourceArn` |
| 6 | Over-privileged agents | Two security profiles with minimum permissions |
| 7 | Toll fraud or call flooding | Concurrent-call and throttled-call alarms, queue capacity, no claimed number by default |
| 8 | CRM lookup abused as an oracle | Only Connect can invoke it; it returns tier and language, never identity |
| 9 | Pipeline credential theft | OIDC only, no stored keys; apply role is environment-gated |
| 10 | Secrets in the repository | gitleaks in CI; `terraform.tfvars` and `backend.hcl` are git-ignored |
| 11 | Pseudonymisation key in state | State is in the encrypted Landing Zone bucket with a lock file; rotate the key by changing the secret and reloading customer rows |
| 12 | Supply chain | Providers pinned to ranges; tfsec, checkov, trivy and bandit on every pull request |
