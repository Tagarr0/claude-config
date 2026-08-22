# The edge

Everything that happens before your logic runs, from outside in. **All of these are software** — usually containers or managed cloud services.

| Piece | Job | Trigger to add it |
|---|---|---|
| **Load balancer** | Spreads traffic across identical copies | You have more than one instance |
| **Reverse proxy** | Terminates TLS, headers, routes | Almost always present, even if you don't draw it |
| **API gateway** | Auth, rate limit and routing in one place | Several services behind it, or external clients with API keys |
| **Rate limiter** | Cuts off excess requests | Public API, an abusive client, or a third party limiting *you* |

## The hidden requirement behind all of it: stateless

If your service keeps something in its own memory (the session, a counter, a temp file), copy 2 doesn't have it and the user sees strange things.

Shared state lives outside: **session → Redis · files → S3/R2 · data → Postgres**.

| State | Where it goes | Why |
|---|---|---|
| Session | Redis | Never in process memory |
| Uploaded files | S3 / R2 | Local disk vanishes on redeploy |
| Counters, limits | Redis | Must be shared across copies |
| Long-running job state | Postgres | If the process dies, it resumes |

> Horizontal scaling, zero-downtime deploys, autoscaling and surviving a dead machine all depend on this one thing.

## Load balancing algorithms

- **Round robin** — one each, in turn. Fine when requests cost roughly the same.
- **Least connections** — to whoever has fewest open. Better when some requests last much longer.
- **IP hash** — the same user always lands on the same server. Skews easily.
- **Weighted** — each server with a weight. For uneven machines, or canary deploys (5% to the new one).

**L4 vs L7.** L4 only sees IP and port; very fast and dumb, can't route by path or read headers, works for any protocol. L7 understands routes, headers and cookies — can send `/api` one way and `/admin` another, terminate TLS and retry. **L7 is what you'll use 95% of the time.**

**Health checks** ask each copy every few seconds "are you alive?" and pull the dead one out of rotation. This is what stops a dead server taking users down with it.

**Sticky sessions** pin a user to one server. It is an alarm signal: if you need them, you put state where you shouldn't have. The correct fix is moving state to Redis.

> Servers multiply. The database does not. Usually one primary writes and replicas read. Multiplying writes = sharding = last resort.

## Proxy vs reverse proxy

- **Proxy (forward)** protects the **client**. The server doesn't know who you are. The office VPN.
- **Reverse proxy** protects the **server**. The client doesn't know how many apps are behind or on which port. This is the one you have.

**Do you need to draw it?** With a managed cloud (ALB, Cloud Run, Vercel, Railway), the reverse proxy and balancer are already inside — one box marked "edge" is enough. Draw them separately when it matters: your own TLS, odd routing, per-customer domains.

## API gateway

One door: auth, rate limiting, routing, logging, versioning — all in one place.

Costs: it is a single point of failure, and **with one or two services you don't need it yet**. Saying that scores better than drawing it by reflex.

## Rate limiter — how it's actually built

- **Token bucket** — the standard. A bucket of N tokens refilling at a fixed rate; each request spends one. Allows short bursts, which is what real traffic looks like.
- **Sliding window** — counts requests in the last 60 seconds. Fairer, slightly more expensive.

**In Redis if you have several copies** — the limit must be shared. In local memory it only works with a single instance.

> **The limit that matters most is not inbound, it's outbound.** In integrations the real bottleneck is how many requests the third party allows you. So the throttler goes on your outbound queue, per tenant. And when they return a 429, respect `Retry-After`.

## Sync vs async

> **If it takes more than a second, or depends on a third party, it does not belong in the request.**

Sync: if the third party goes down, your request goes down. If it's slow, the user waits. And if you retry, the user already left.

Async: the user gets a response in 20 ms. Heavy work happens behind, with retries, blocking nobody. You absorb spikes, retry for free, and if the worker dies the message is still queued. You can scale workers without touching the API.

The price: the user no longer knows if it finished, so you need queryable state, a notification, and tolerance for duplicates. Plus one more moving piece to monitor.

## Monolith vs services

| | When |
|---|---|
| **Modular monolith** | Real transactions. Easy to debug. **The right answer 90% of the time** |
| **A few services (2–5)** | Split by *scale profile*, not by taste. Still manageable |
| **Microservices** | An **organisational** solution — many teams getting in each other's way. Not a technical one |

> **The classic mistake: microservices sharing one database. Every cost, none of the benefits.**

Communication: sync (HTTP/gRPC — simple, but if one falls the others follow and latencies stack) or async (events over a queue — resilient, at the price of eventual consistency).

The mature answer, word for word:

> "I start with a modular monolith with clear boundaries, and split out the piece with a different scale profile."
