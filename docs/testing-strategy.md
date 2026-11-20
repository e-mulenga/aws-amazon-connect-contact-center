# Testing strategy

| Layer | What | How |
|---|---|---|
| Unit | Both Lambda handlers: tier lookup, fail-open, hidden numbers, E.164 validation, TTL, no number in audit rows | `python3 -I -m unittest discover -s tests` |
| Flow graph | Every transition target exists, nothing is unreachable, the flow ends in a disconnect | `tests/test_flow_json.py` reads the Terraform source |
| Static | Format and validate | `terraform fmt -check -recursive`, `terraform init -backend=false && terraform validate` in CI |
| Security | IaC, filesystem, secrets, Python | tfsec, checkov, trivy, gitleaks, bandit in `security.yml` |
| Plan | Review of what will change | `deploy.yml` comments the dev plan on every pull request |
| Acceptance (dev) | Call the claimed number or use the Connect test chat; walk each path | Checklist in `runbooks/operations.md` |

Acceptance paths: open hours and ask for an agent; open hours and ask for opening hours; open hours and ask for a callback; closed hours; known priority customer; hidden number; queue full.
