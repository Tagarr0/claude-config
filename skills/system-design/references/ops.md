# Multi-tenancy and operations

## Three ways to isolate customers

| | What it is | Trade-off |
|---|---|---|
| **Row with `tenant_id`** ← default | One table, one database | Cheap and scales well. Risk: a forgotten `WHERE`. Safety net: Row-Level Security |
| **Schema per tenant** | Same database, separate tables | Decent isolation without duplicating infrastructure. Cost: every migration runs N times |
| **Database per tenant** | Full separation | Maximum isolation. What enterprise customers ask for. **Sell it as a plan, don't suffer it as a problem** |

## The noisy neighbour

> A customer with 10× the volume must not degrade everyone else.

- **A queue (or partition) per tenant**, so whoever uploads 10,000 records doesn't block the rest
- **Quotas per tenant** — turn the requirement into design
- **Whatever varies between customers lives in data, not code**: mappings, prompts, schedules, price limits, credentials. Trigger: the *second* customer
- **Credentials per tenant** — each brings their own keys. Secrets manager, encrypted, rotatable. Getting those credentials is usually the real bottleneck

## The three pillars — each answers a different question

**Logs — "what exactly happened?"**
Structured (JSON), not loose sentences. Every line with `tenant_id` and `request_id`. **PII redacted** — no phone numbers, no full transcripts in logs.

**Metrics — "how is its health?"**
Aggregates over time: p95 latency, error rate, queue depth, concurrent sessions, cost per unit. **This is what you alert on.**

**Traces — "where did it go?"**
Follow one request end to end across services, queues and third parties. This is what tells you the 3 seconds were spent waiting on someone else, not in your code.

## Environments

- **dev** — your machine, fake data, everything can break
- **staging** — same as production, with fake data
- **production** — real customers, real money

> The recurring problem: the third party you integrate with has no staging.

So: **dry-run mode, feature flags, and per-customer rollout.**

## Alerting

**Alert on symptoms, not on machines.**

✓ "dropped calls above 3% over 10 minutes"
✓ "pending queue growing for 15 minutes"
✓ "one tenant hasn't synced in an hour"
✗ "CPU at 80%" — nobody knows what to do with that

> **If nobody is going to act on it, it is not an alert. It is a chart.**

## Personal data

If you store recordings, transcripts or anything identifying a person: encrypted at rest, stated retention policy, deletion on request. Say it before you're asked.
