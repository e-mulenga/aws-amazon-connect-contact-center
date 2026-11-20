# Architecture decisions

## ADR-1: Everything in af-south-1, no Ireland alias
Status: accepted. Connect, Lex V2, Lambda, DynamoDB and Secrets Manager are all offered in Cape Town, and customer data should stay in South Africa. The `ireland` alias is reserved for services that are missing in Cape Town and none are used.

## ADR-2: Landing Zone consumed, never recreated
Status: accepted. Alerts, key strategy and OIDC come from remote state with a contract-version check.

## ADR-3: Cloud Control (awscc) for the Lex bot, alias, policy and association
Status: accepted. The aws provider has no resource for the Lex V2 alias, the alias resource policy or the Connect association of a Lex V2 bot (`aws_connect_bot_association` is Lex V1 only). The bot is also created with awscc because that resource builds the locale automatically (`auto_build_bot_locales`); the aws provider bot resources never start a build, and a bot version needs a built locale.

## ADR-4: Contact flow built in Terraform with jsonencode
Status: accepted. Queue, Lambda and Lex ARNs are always the ones created by this stack; a static JSON file would need placeholder substitution.

## ADR-5: Phone numbers are hashed, not stored
Status: accepted. The customer key is HMAC-SHA256 of the E.164 number with a secret in Secrets Manager. Callback numbers must be stored to be called back, so that table has a short TTL.

## ADR-6: Fail open on the CRM lookup
Status: accepted. A lookup failure must not stop a call. The caller is treated as standard.

## ADR-7: No users in Terraform
Status: accepted. Connect-managed users need passwords. The first administrator is created in the console, then an identity provider is the roadmap item.

## ADR-8: No Amazon Q in the stack
Status: accepted. Q in Connect is not offered in af-south-1; Q Business needs Identity Center and was not confirmed for the Region. Both are on the roadmap.

## ADR-9: Contact Lens post-call only
Status: accepted. Real-time analytics support is partial in the Region.

## ADR-10: No claimed phone number by default
Status: accepted. A number is billed monthly and availability by country varies. `claim_phone_number` switches it on and attaches the inbound flow.

## ADR-11: Terraform only
Status: accepted. Commands, scripts and CI use `terraform`.
