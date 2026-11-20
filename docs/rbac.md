# Access control

| Principal | Access | How |
|---|---|---|
| Agent | Control panel and outbound calls | Security profile `<prefix>-agent`: `BasicAgentAccess`, `OutboundCallAccess` |
| Supervisor | Agent access plus metrics | Security profile `<prefix>-supervisor`: adds `AccessMetrics` |
| Contact flow | Invoke the two Lambdas and the Lex alias | Lambda permission and Lex resource policy limited to this account and this instance |
| Lambda crm-lookup | Read customers, write interactions, read the hash key | Own role, resource-scoped |
| Lambda callback | Write callbacks | Own role, one table |
| Pipeline | Plan (read-only) and apply | OIDC roles; apply may manage IAM only for names starting with the workload prefix |

Agents and supervisors are not created by Terraform: a user needs a password or an identity provider, and neither belongs in state. Create the first administrator in the Connect console (`connect_access_url` output), then add users and assign these profiles and the routing profile `<prefix>-standard`.
