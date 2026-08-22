---
name: system-design
description: Checklist and trade-offs for any architecture decision or problem — data stores, caching, queues, the edge, networking, multi-tenancy, LLM agents and operations. Use when choosing or changing an architecture, adding a component, reviewing a design, or when something is slow, breaking under load, or failing at scale.
---

# System design

This skill is not an encyclopedia. It is a **checklist against omission**.
The failure mode is not "I didn't know what a dead-letter queue is" — it's "I forgot to ask whether we needed one".

## Before choosing anything

Answer these out loud. If you cannot, you have not chosen — you have copied.

1. **What is the actual requirement?** "Store orders" designs nothing. "Cannot lose a single one, under 200 ms" designs a system.
2. **What are the numbers?** Requests/sec, concurrent sessions, rows, payload size, growth. Concurrency and throughput are not the same thing — confusing them is the classic error.
3. **What breaks first at 10x?** Name the component. It is often not the one you were about to scale.
4. **What is the blast radius if this dies?** Who notices, how fast, and what do they see.
5. **What is the simplest thing that works?** One service and one Postgres go a very long way.
6. **Name the trade-off you are accepting.** Every choice buys something and pays for something.

## The checklist

Walk it. For each line: needed, not needed, or deferred — and say which.

**Data**
- [ ] One database, or more than one? Why more?
- [ ] Multi-tenant: `tenant_id` in every table **and as the first column of every index**?
- [ ] Any external API call inside an open transaction? (Never do this.)
- [ ] Read replicas needed, and is replication lag acceptable after a write?
- [ ] Files in the database? Move them to object storage, keep the path.

**Caching**
- [ ] How stale is the business willing to accept? Answer before drawing Redis.
- [ ] Invalidation: TTL, or explicit on write?
- [ ] Cache stampede: what happens when a hot key expires and 500 requests hit at once?
- [ ] If the cache dies, does the system get slower or stop?

**Async**
- [ ] Anything over ~1 s or depending on a third party — is it out of the request path?
- [ ] Queue or stream? (Queue = one worker does it once. Stream = several want to know and replay.)
- [ ] Consumers idempotent? At-least-once delivery means duplicates *will* happen.
- [ ] Dead-letter queue, and does anyone actually watch it?
- [ ] Outbox, if a database write and an external call must both happen or neither.
- [ ] Backpressure: what happens when the consumer cannot keep up?

**Reliability**
- [ ] Idempotency key on every irreversible operation, backed by a unique index.
- [ ] Retries: exponential backoff **with jitter**. Retry 5xx/429/timeouts, never 4xx.
- [ ] Circuit breaker on third parties — and a named degraded mode, not just an error.

**Edge**
- [ ] Are the services stateless? If sticky sessions are needed, state is in the wrong place.
- [ ] Rate limiting — and note the limit that usually matters is **outbound**, not inbound.
- [ ] Health checks that actually check dependencies.

**If there is an LLM agent in this**
- [ ] Does the agent reach a third party without your API in between?
- [ ] Anything irreversible without an idempotency key?
- [ ] Max turns set?
- [ ] Any "never do X" living in the prompt that should be impossible in the tool?
- [ ] Evals, or are you guessing?

**Operations**
- [ ] Structured logs with `tenant_id` and `request_id`, PII redacted.
- [ ] Alerts on symptoms, not on machines. If nobody will act on it, it is a chart, not an alert.
- [ ] Can this be deployed per tenant, dry-run, or behind a flag?

## Reference material

Load only what the current decision needs.

| File | Covers |
|---|---|
| `references/data.md` | SQL internals, NoSQL, choosing, scaling, sharding, caching |
| `references/async.md` | Buffers, queues, streams, DLQ, outbox, backpressure, idempotency, retries |
| `references/edge.md` | Load balancers, reverse proxies, gateways, rate limiting, stateless, monolith vs services |
| `references/network.md` | Layers, TCP/UDP, public vs private, who-calls-whom, WebSocket/SSE, API types |
| `references/ops.md` | Multi-tenancy, isolation, noisy neighbour, logs/metrics/traces, environments, alerting |
| `references/architecture-doc.md` | Writing it down: the tabbed HTML template, its fixed visual language, and what does not belong in the file |
| `references/llm-agents.md` | Shipping an LLM agent in a product: the agent/tools/API layering, what belongs in code vs prompt, connecting several agents |

## Red flags

Say these out loud when you see them:

- Kafka and microservices for 500 users
- "NoSQL because it scales better", with no concrete access pattern
- Microservices sharing one database — every cost, none of the benefits
- A cache added by reflex: a new failure mode bought for nothing
- A database with a public IP
- Sharding before partitioning
- Retrying a POST without an idempotency key
- An agent whose prompt says "never charge twice" instead of a unique index that makes it impossible
- A second agent added where a second tool would have done
