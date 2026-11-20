# Business case: cloud contact centre on Amazon Connect

## Problem

Customer service is expensive and uneven. The pain the repository addresses, in the order a service owner feels it:

| Pain | What it looks like |
|---|---|
| Cost | Fixed seat licences and on-premises telephony paid for whether or not calls arrive |
| Long waits | Every caller waits for an agent, including those who only want opening hours or a call back |
| Inconsistent quality | No recordings or analytics on every call, so coaching depends on a supervisor happening to listen |
| Fragmented customer data | The agent does not know who is calling until the caller explains |
| Poor experience after hours | A closed centre means a dead line and a lost customer |
| Governance | Recordings and customer numbers sit in places nobody can audit or expire |

## What this repository delivers

| Pain | Capability | Where |
|---|---|---|
| Cost | Connect bills per minute of use; no seat licence; queue capacity and concurrency alarms cap spend | `modules/connect`, `docs/finops-and-kms.md` |
| Long waits | Lex V2 answers opening hours and callback requests without an agent | `modules/lex-bot` |
| Inconsistent quality | Every call recorded; Contact Lens post-call analytics, sentiment and PII redaction | `modules/contact-flows` |
| Fragmented data | CRM lookup on the caller number returns tier and language before the agent answers; priority customers go to a priority queue | `modules/lambda`, `modules/dynamodb` |
| After hours | Callback request is stored and a message is played instead of a dead line | `lambda/callback` |
| Governance | Private versioned bucket with expiry, TTL on every table, phone numbers hashed, least-privilege roles, alarms to the platform topic | whole repo |

## How the value is measured

Replace the inputs with your own figures; the model is deliberately simple.

| Measure | Formula | Input to supply |
|---|---|---|
| Calls contained by self-service | calls per month x containment rate | monthly calls, containment rate from `CallbacksQueued` and Lex intent counts |
| Agent minutes saved | contained calls x average handle minutes | average handle time from Connect reports |
| Cost per contact | (Connect + Lex + Lambda + DynamoDB + storage bill) / contacts | the monthly bill tagged `Project = aws-amazon-connect-contact-center` |
| Missed-call rate | `MissedCalls` / `CallsPerInterval` | CloudWatch dashboard `<prefix>-operations` |
| Priority wait | queue time of priority tier vs standard | Connect queue metrics |

Worked example with assumptions to replace: 10,000 calls a month, 20 percent answered by the bot, 4 minutes average handle time. That is 2,000 contained calls and 8,000 agent minutes (about 133 agent hours) returned to the queue each month. Multiply by your loaded agent cost per hour for the saving, then subtract the platform bill to get the net.

## Costs

The stack is pay-per-use. The drivers are voice and chat minutes in Connect, Lex requests, Contact Lens analysed minutes, S3 storage of recordings, and a monthly fee per claimed phone number (off by default). Lambda, DynamoDB, Secrets Manager (one secret) and CloudWatch are small. Dev and test cost almost nothing when idle. See `docs/finops-and-kms.md` for the guards and the encryption statement.

## Risks and how they are handled

| Risk | Handling |
|---|---|
| Amazon Q in Connect and Voice ID are not offered in af-south-1 | Left out of the stack; recorded in `docs/regional-availability.md` and the roadmap |
| Connect is not offered in eu-west-1, so there is no warm standby Region | Honest recovery model in `docs/dr-and-resilience.md`: rebuild from Terraform, tables have point-in-time recovery |
| Customer numbers are personal information (POPIA) | Numbers are hashed for lookup, never logged, callback numbers expire after 7 days by default, recordings expire after 90 |
| Contact Lens real-time analytics is not in every Region | Only post-call analytics is configured |

## Decision

Build on Amazon Connect in Cape Town: it keeps customer data and recordings in-country, removes fixed licence cost, and is delivered as reviewable Terraform that reuses the Landing Zone instead of rebuilding it.
