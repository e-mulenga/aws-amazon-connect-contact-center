# Roadmap

| Item | Why it is not in the stack today |
|---|---|
| Amazon Q in Connect (agent assist) | Not offered in af-south-1 (docs/regional-availability.md). Revisit when Cape Town support is announced. |
| Amazon Q Business knowledge answers | Needs IAM Identity Center and was not confirmed for the Region; plan it as a separate repository that the flow can call |
| Bedrock-based answers in the bot | See the `aws-bedrock-agentic-ai-platform` repository |
| Real-time Contact Lens | Regional support is partial; add when confirmed |
| Chat channel flow | Routing profile already carries chat concurrency; a chat flow and widget are the next step |
| Keyed hash rotation | Add a rotation Lambda and a re-key job for the customers table |
| Scheduled table backups into the Landing Zone vault | Add when an RPO tighter than point-in-time recovery is set |
| Agent provisioning from the identity provider | Switch the instance to SAML when an IdP is chosen |
