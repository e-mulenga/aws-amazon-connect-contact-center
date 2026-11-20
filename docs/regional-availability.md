# Regional availability

Checked 2026-11-18. The primary Region is af-south-1. The Ireland alias (`eu-west-1`) is the only other approved Region and is used only where a service is missing in Cape Town.

| Service | af-south-1 | Used here | Notes |
|---|---|---|---|
| Amazon Connect | Yes | Yes | Instance, flows, queues, routing, security profiles |
| Contact Lens | Partial | Post-call analytics only | Real-time analytics is not relied on; check the language list before changing `analytics_language` |
| Amazon Lex V2 | Yes | Yes | `en_ZA` (South African English) supported; voice Ayanda |
| AWS Lambda, DynamoDB, Secrets Manager, CloudWatch, S3 | Yes | Yes | |
| Amazon Q in Connect | No | No | Not offered in Cape Town, so it is not in the stack |
| Voice ID | No | No | Not offered in Cape Town |
| Amazon Connect in eu-west-1 | n/a | No | Connect is not offered in Ireland, so there is no Ireland fallback for the contact centre (docs/dr-and-resilience.md) |

Because every service the stack uses is available in af-south-1, no resource is created through the `ireland` alias and the provider file declares none.

## Sources

- AWS Regional Services List: https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/
- Amazon Lex V2 languages and locales: https://docs.aws.amazon.com/lexv2/latest/dg/how-languages.html
- Amazon Lex launches support for South African English: https://aws.amazon.com/about-aws/whats-new/2021/11/amazon-lex-south-african-english
- Languages supported by Amazon Connect features: https://docs.aws.amazon.com/connect/latest/adminguide/supported-languages.html

Re-check this page when you change Region, locale or analytics language.
