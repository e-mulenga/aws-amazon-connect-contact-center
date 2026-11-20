# Resilience, RTO and RPO

Amazon Connect is not offered in eu-west-1, and keeping contact data in South Africa is a goal, so there is no warm standby Region. The recovery model is honest about that.

| Failure | Effect | Recovery | RTO | RPO |
|---|---|---|---|---|
| Lambda or DynamoDB fault | Lookup fails open: calls continue as standard customers; callbacks fail with a spoken message | Automatic retry by AWS; alarms notify | Minutes | 0 for committed rows |
| Table corruption or deletion | Tier data lost | Point-in-time restore (enabled in test and prod); deletion protection in prod | 1 hour | 5 minutes |
| Bad flow change | Callers hit the error branch | Revert the commit and apply; flows are code | 30 minutes | 0 |
| Instance deleted or account issue | Contact centre down | `terraform apply` rebuilds instance, queues, flows and bot; users and claimed numbers are re-added | 4 hours | 0 for configuration; recordings are in a versioned bucket that is not deleted with the instance |
| Region loss (af-south-1) | Contact centre down | Not mitigated by a standby; rebuild in a new Region only by a conscious data-residency decision | Days | Last table backup |

The Landing Zone backup vault is available if scheduled backups of the tables are wanted; add a backup selection when the business sets an RPO tighter than point-in-time recovery gives.
