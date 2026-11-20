# Operations runbook

## Deploy

```bash
cp environments/dev/backend.hcl.example environments/dev/backend.hcl
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
scripts/tf.sh dev init
scripts/tf.sh dev plan
scripts/tf.sh dev apply
```

## First use

1. Run `scripts/tf.sh dev output connect_access_url` and open the URL.
2. Create the first administrator in the Connect console when prompted.
3. Add agents and assign the security profile `<prefix>-agent` and routing profile `<prefix>-standard`.
4. Load customer rows: `customer_key` = HMAC-SHA256(secret, E.164 number) hex, plus `tier` (`standard` or `priority`), `language` and `segment`. The secret ARN is the `pseudonymisation_secret_arn` output.
5. To take real calls set `claim_phone_number = true` and apply.

## Acceptance checklist (dev)

- [ ] Open hours: say "agent" and reach the general queue
- [ ] Open hours: say "opening hours" and hear the hours, then the menu again
- [ ] Open hours: say "call me back" and see a row in the callbacks table
- [ ] Closed hours (change `business_hours` temporarily): hear the closed message and see a callback row
- [ ] Priority customer row: call is queued in the priority queue
- [ ] Hidden number: caller hears the could-not-note message and no row is stored
- [ ] Alarms and dashboard `<prefix>-operations` show data

## Alarms

| Alarm | First action |
|---|---|
| missed-calls | Check agent availability and routing profile membership |
| concurrent-calls-high / throttled-calls | Request a concurrent call quota increase; check for call flooding |
| crm-lookup-slow | Check DynamoDB metrics; the flow times out at 4 seconds and continues |
| *-lambda-errors | Run the saved query `lambda-errors` in CloudWatch Logs Insights |
| *-throttles | Table is on-demand; check for a burst or a hot key |

## Rotate the pseudonymisation key

Changing the secret changes every customer key. Re-key the customers table in the same window, or lookups return "not found" and callers are treated as standard.

## Destroy

`force_destroy = false` protects the recordings bucket. Empty it deliberately before destroying a non-production environment.

## Troubleshooting: InvalidContactFlowException when creating the flow

Terraform prints the exception without its problem list. To see which action Connect rejected, take the flow JSON from the plan and send it with the CLI in debug mode:

```bash
terraform show -json tfplan | python3 -c "import json,sys; p=json.load(sys.stdin); print([c['change']['after']['content'] for c in p['resource_changes'] if c['type']=='aws_connect_contact_flow'][0])" > /tmp/flow.json
aws connect create-contact-flow --region af-south-1 --instance-id <instance-id> --name probe --type CONTACT_FLOW --content file:///tmp/flow.json --debug 2>&1 | grep -i -A8 problems
```

The `Problems` entries name the action identifier and the reason. Delete the `probe` flow afterwards. After any change to the flow, run `terraform plan` again: a saved plan file is no longer valid.
