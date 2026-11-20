# Issues resolved

Each row is a problem a contact centre team normally lives with, and what this repository does about it. "Evidence" says where to check it.

| # | Issue | Resolution | Evidence |
|---|---|---|---|
| 1 | Callers wait for an agent to hear opening hours | Lex intent `OpeningHours` answers in the flow and loops back to the menu | `local.intents`, flow action `hours_message` |
| 2 | After-hours callers reach a dead line | Flow checks the hours of operation and offers a stored callback | `check_hours`, `closed_message`, `lambda/callback` |
| 3 | Callers disappear when the queue is full | `QueueAtCapacity` leads to a callback instead of a drop | `to_queue` error path |
| 4 | Agent does not know the customer | CRM lookup returns tier, language and segment before queueing | `lambda/crm_lookup` |
| 5 | High-value customers wait like everyone else | `priority` tier is routed to a queue with higher routing priority | `tier_check`, `local.queues` |
| 6 | Phone numbers sit in clear text in a customer table | Key is HMAC-SHA256 of the number; interaction rows hold no number; logs never print it | `tests/test_crm_lookup.py` |
| 7 | CRM outage stops calls | The lookup fails open to a standard customer and the call continues; flow error branch also continues | `test_lookup_failure_fails_open` |
| 8 | Callback list grows forever with personal numbers | `callbacks` table has a TTL (7 days default) | `modules/dynamodb` |
| 9 | Hidden or malformed numbers create junk callbacks | E.164 check; rejected requests are not stored and the caller is told | `tests/test_callback.py` |
| 10 | Recordings kept forever, in a bucket nobody governs | Private, TLS-only, versioned bucket; 90-day expiry; Landing Zone key when governance requires | `modules/connect` |
| 11 | No quality analytics on calls | Contact Lens post-call analytics, sentiment and redaction set in the flow | `local.analytics` |
| 12 | Nobody notices missed calls or quota exhaustion | Alarms on missed calls, throttled calls and concurrent-call percentage notify the Landing Zone topic | `main.tf` monitoring block |
| 13 | Flow errors are invisible | Flow logs go to a log group with retention; a metric filter counts errors | `modules/connect` |
| 14 | Agents have too much access | Separate agent and supervisor security profiles with the minimum permissions | `aws_connect_security_profile` |
| 15 | Contact-centre infrastructure is clicked together and cannot be reviewed | Everything is Terraform with a pull-request plan, security scans and OIDC roles, no stored keys | `.github/workflows` |
| 16 | Landing Zone resources get recreated per workload | Alerts, keys and OIDC are read from LZ remote state with a contract check; no LZ resource is created here | `landing_zone.tf` |
| 17 | Provider gaps block automation (Lex V2 alias, Connect association, Lex policy) | Cloud Control (`awscc`) resources fill exactly those gaps | `modules/lex-bot` |
| 18 | Lex bot never built, so the version step fails | The bot is created with automatic locale build | `auto_build_bot_locales` |
