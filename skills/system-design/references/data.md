# Data

## Relational (the default)

Tables pointing at each other with keys. A primary key identifies the row uniquely — often a natural key (an MC number, a VAT id) rather than a surrogate. A foreign key is what stops a booking existing for a load that doesn't. An index is the book's index: put one on what you filter and sort by. A JOIN is what NoSQL does not give you cheaply, and the main reason you keep choosing SQL.

**Transactions.** `BEGIN → create booking → mark load reserved → COMMIT`. If anything fails, `ROLLBACK` and it's as if nothing happened.

> **Never call an external API inside an open transaction.** You hold locks while waiting on someone else's network.

**Multi-tenant.** `tenant_id` in every table, and as the **first column of every index**. Safety net: Postgres Row-Level Security, so a forgotten `WHERE` cannot leak another customer's data.

## The other shapes, and when they earn their place

| Shape | Examples | Use when |
|---|---|---|
| Document | MongoDB | Highly variable schema, always accessed by id |
| Key-value | DynamoDB, Redis | Huge scale with a fixed access pattern. Instant if you know the key, useless if you don't. A new query means a redesign |
| Columnar | ClickHouse, BigQuery | Reports and analytics. Summing one field over a billion rows is instant. Never transactions |
| Search | Elastic | Free text with relevance. A separate index you must keep in sync — and filter by tenant *in the query* |
| Time series | — | Metrics and events with a timestamp. Retention and archiving are mandatory |
| Graph | — | You almost certainly do not need this |

**Postgres already does most of this**: JSONB (document), full-text (search), pgvector (vector), date partitioning (time series), replicas (light analytics). Starting with one and adding systems when volume demands it shows judgement, not ignorance.

> Saying "NoSQL because it scales better" with no concrete access pattern is a red flag.
> Saying "Postgres, and I'd stop when I had massive writes with no relations, or free-schema documents" shows you understand the decision.

## How a database scales — in order, no skipping

1. **Indexes and query tuning.** Most "we need to scale" is a missing index.
2. **Vertical.** A bigger machine. Simple, and gets you much further than people expect.
3. **Read replicas.** Write to primary, read from replica — but the replica may not have it yet. Read from primary right after a write when it matters. Note: a replica copies the `DELETE` too, so replication is not a backup.
4. **Partitioning.** Same database, split tables by date or tenant.
5. **Sharding.** Last resort.

**Backups** only count if you have restored one at least once.

## Sharding, and the key that decides everything

The shard key must spread load **and** avoid queries that cross shards — a JOIN across two shards stops being cheap.

Sharding by customer is the natural partition and almost no query crosses customers. But if one customer is 60% of volume, you have built a bottleneck with extra steps.

**Consistent hashing.** With `hash(k) % N` across 3 nodes, adding a fourth changes almost every key's home — the cache empties at once and the database takes the full hit. The ring fixes this: each key goes to the next node clockwise, so adding a node only moves its own arc. Each machine sits at 100–200 points on the ring, not one, or the spread is lopsided and one node eats triple.

You will almost never implement this yourself — it is inside distributed caches, Dynamo and Cassandra.

## Caching

Redis is a database that lives in RAM. It is not a load balancer. ~100× faster than disk, at the cost of stale data and expensive memory, so only what is asked for most fits.

**Never treat it as the source of truth.** There is optional persistence, but on restart you can lose what was there.

### The six uses

1. **Cache-aside query results** — the star use. Check cache → miss → Postgres → store with TTL.
2. **Shared session** — what lets your services be stateless and multipliable.
3. **Distributed lock** — "only one process reserves load L-1001", "this cron runs on one instance only".
4. **Rate limiting counters** — must be shared, or the real limit is ×N instances.
5. **Light queues and pub/sub** — lists for simple jobs. For real volume or replay, use a proper broker.
6. **Ephemeral state** — in-flight call state, partial results, verification codes.

### The three problems

**Stale data.** Someone changed the price upstream and your cache still serves the old one. Before drawing Redis, answer: *how much staleness does the business accept?*

> "I quote from cache because the upstream takes 2 s and that doesn't fit in a conversation. I accept up to 60 s of stale data, but I revalidate against the source right before booking, which is the part that can't be undone."

**Invalidation.** TTL (expires on its own, simple) or explicit on write (precise, more work, more places to forget).

**Stampede.** The key expires at 09:00 sharp and 500 requests hit Postgres together. Fix: a lock so only one recomputes, or refresh ahead of expiry.

And a fourth: **if Redis dies, does your system slow down or stop?** Have the answer ready.

### What caches well and what doesn't

✓ Lists asked for often that change rarely · expensive computations · third-party responses behind a rate limit
✗ Balances, prices at the moment of closing, stock · anything where stale data costs money · data that changes on every read (you save nothing)

### Eviction and write strategies

`maxmemory` + `maxmemory-policy`. **If you don't set it, Redis eats the machine.**

- **LRU** — evict least recently used. Good default.
- **LFU** — evict least frequently used. Better with a hot core.
- **volatile-*** — only evict keys that already have a TTL. Protects what must not die.
- **noeviction** — fills up and errors on write. Only valid if Redis is a store.

| Strategy | Trade-off |
|---|---|
| **Cache-aside** | Simplest, survives cache failure, repeated code. **90% of real cases** |
| Read-through | App only talks to the cache. If the cache dies, you read nothing |
| Write-through | Cache never stale, every write slower, you cache things nobody reads |
| Write-behind | Fast, but **if the cache dies you lose data**. Never with money or bookings |

## Object storage and analytics

**Bucket = giant folder in the cloud. Blob = the file inside.**

Files in the database means huge slow backups, replicas that crawl, and expensive storage. Put the file in a bucket, the path in the row.

**Pre-signed URL** is the key pattern: your server generates a temporary link and the client uploads or downloads straight to the bucket. Your server never touches the file — no memory, no bandwidth.

Tiers: hot (immediate, pricier) vs cold/archive (cents, slow to retrieve). Lifecycle rules move things over automatically.

Three places data lives, with different jobs:

| | For | Shape |
|---|---|---|
| **Operational DB** | "Give me load L-1001." Data as of now | Thousands of small ops/sec |
| **Data lake** | Everything exactly as it arrived, untransformed. Cheap and infinite — basically a bucket | Raw |
| **Warehouse** | "Average margin per lane per month." Millions of rows | Clean, structured, aggregable |

> **Never run reporting queries against the database serving live traffic.**

ETL transforms before loading; ELT loads raw then transforms. ELT is the norm today: store first, decide later. A lake with no catalogue or governance becomes a swamp — terabytes nobody knows how to read. So: declared schema, partitioned by date and tenant, retention policy. Keeping everything "just in case" costs money too.
