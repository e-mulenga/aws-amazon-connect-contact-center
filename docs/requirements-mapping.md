# Requirements mapping

Source brief: "AWS Amazon Connect Contact Center Platform".

| Brief item | Where |
|---|---|
| Amazon Connect | `modules/connect` |
| Contact Lens | `local.analytics` in `modules/contact-flows`; instance flag in `modules/connect` |
| Lex | `modules/lex-bot` |
| Lambda | `modules/lambda`, `lambda/` |
| DynamoDB | `modules/dynamodb` |
| Amazon Q Business | Not in the stack: see docs/roadmap.md and docs/regional-availability.md |
| `architecture/` | 8 diagrams in `architecture/diagrams` |
| `environments/` | `common.tfvars` plus `dev`, `test`, `prod` examples |
| `modules/connect`, `contact-flows`, `lex-bot`, `lambda`, `dynamodb`, `monitoring` | All present, plus `modules/iam` for the pipeline roles |
| README | `README.md` |
