# Instructor guide

## Pre-checks (1 week before)

- [ ] Confirm every attendee can **assign roles on the subscription** (Owner or UAA) — the most common cause of failure
- [ ] Pre-register resource providers: `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.ManagedIdentity`
- [ ] Check Container Apps quota per region (default `koreacentral`). Tell attendees to change `LOCATION=` if needed
- [ ] Confirm Actions works on attendees' forks
- [ ] If several people share one subscription, require `RG=rg-secretless-<name>` (Key Vault/ACR names are made unique from the RG ID)
- [ ] Do one dry run before the day (deploy ~5 min, pipeline ~4 min)

## Timetable (about 100 min)

| Time | Content | Tips |
|---|---|---|
| 0:00 | Opening + Module 0 | Resolve all sign-in issues in this slot |
| 0:10 | Module 1 concepts (live explanation) | Draw the sequence diagram live. Ask attendees the 3 checkpoint questions |
| 0:20 | Module 2 deploy infrastructure | **During the 3–5 min deployment**, read main.bicep together |
| 0:35 | Module 3 OIDC | Emphasize the `subject`. Have attendees say their own subject string aloud |
| 0:50 | Module 4 pipeline | Watch the `Azure login` log together during deployment |
| 1:05 | Module 5 break it | Prioritize B, C, D. If short on time: A, B, D |
| 1:25 | Module 6 cleanup + retrospective | Make sure everyone **actually runs the cleanup** |

## Talking points

- "Secretless" is different from **storing secrets well** (e.g. keeping a client secret in Key Vault). Point out the bootstrap problem: accessing that secret needs yet another secret.
- Many attendees question keeping `client-id` in `vars`. The analogy **"the ID is your ID-card number; the token is a signed certificate"** works well.
- `Contributor` is for demo convenience. In production, tell attendees to split roles further (Challenge 3).
- OIDC and Managed Identity **solve different problems**: the former is "external (GitHub) → Azure", the latter is "between Azure services".

## Top 5 places attendees get stuck

1. Insufficient permission to assign roles → pre-check
2. Subject mismatch from a repository name typo (mind the `<owner>/<repo>` case)
3. `gh variable set` failing because of the Codespaces `GITHUB_TOKEN`
4. First deployment failing due to role propagation delay → **Re-run jobs**
5. Actions disabled on the fork

## After the event

- Confirm everyone has run `03-cleanup.sh`
- On a shared subscription, check for leftover `rg-secretless-*` resource groups:
  `az group list --query "[?starts_with(name,'rg-secretless')].name" -o tsv`
