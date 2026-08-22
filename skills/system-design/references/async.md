# Async

## Buffer, queue, stream — three things people constantly confuse

| | What it is | Example | Survives a restart? |
|---|---|---|---|
| **Buffer** | Temporary waiting area absorbing rate differences. Usually in memory | Audio chunks arriving from the phone before going to speech-to-text | No |
| **Queue** | Persistent inbox of work. **One** worker takes a message, does it, it disappears | "Write this call into the customer's system" | Yes |
| **Stream** | Ordered log several consumers read at their own pace, and can replay | Kafka. "Call finished" matters to three places at once | Yes |

> **Queue = a task someone does once. Stream = a fact several want to know and replay.**

The queue is what you will draw 90% of the time. A stream is powerful and expensive to operate — justify it.

## Why a queue

- **Decouple** — the caller doesn't wait for the doer
- **Absorb spikes** — 10× arrives and you don't fall over
- **Retry** — if it fails, it goes again
- **Pace towards a rate-limited third party**
- **Survive worker death** — the message is still there

Which one in practice: SQS (managed, simple, cheap) · RabbitMQ (richer routing) · Redis lists/streams (light, you already have it) · Kafka (real stream, high volume). **Pick the simplest that solves the case.**

## What a queue costs you

- The user no longer knows whether it finished → you need queryable state and a notification
- A new state appears: "in progress"
- **Messages can arrive twice**
- **They can arrive out of order**

That is why a queue always ships with idempotency.

## Message lifecycle — what actually happens

1. Worker takes the message. It becomes invisible to others for a **visibility timeout**.
2. Worker does the work.
3. Worker sends **ACK**.
4. No ACK → the message goes back on the queue.

**Direct consequence: a message can be processed twice.** If the worker dies after doing the work but before the ACK, it runs again. The consumer must tolerate it.

**Ordering.** With one consumer, order holds. With five in parallel, it doesn't. If order matters, partition by key (e.g. by `load_id`).

## Scaling consumers — the easy part, and the catch

Adding workers is free: each takes different messages, no coordination.

**But the limit moves, it doesn't vanish.** If 10 workers write at once to a customer system that allows 60 requests/minute, you have relocated the problem. The throttler goes **on the outbound side and per tenant**, so the queue lets you consume at the rate the third party tolerates instead of blowing it up and eating cascading 429s.

## DLQ — where repeated failures land

After N attempts, the message goes to a dead-letter queue. Alert the team, and keep the ability to reprocess once it's fixed.

Without a DLQ the message is either lost or blocks the queue. **And a DLQ nobody looks at is a black hole.**

## Outbox — not ending up half-done

Bad: write the booking to your DB, then call the customer's system, and that call fails. The booking exists on your side and not on theirs. Nobody finds out until someone complains.

Good: in **one transaction**, save the booking *and* save the event. A separate process reads the event and calls out, retrying until it works.

> Either both are saved or neither. And delivery retries without losing anything.

## Backpressure — when the consumer can't keep up

- **Add workers.** First move, usually enough.
- **Reject early.** Return 429 + `Retry-After`. Better to say "not now" quickly.
- **Separate queues by priority.** An inbound call outranks a bulk campaign.
- **Degrade deliberately.** Doing less, well, beats doing everything badly.

## Idempotency

**Idempotent = doing it twice leaves the same result as doing it once.**

The scenario: the request times out, the client gets no response, it retries — and books twice.

**The key must be deterministic.**
- ✓ `load_id + mc_number + date`
- ✗ a random UUID generated at retry time — if it changes every attempt it deduplicates nothing

**Enforce it in the database**, with a unique index on that key. If you try to insert twice, the database itself stops you.

GET, PUT and DELETE are idempotent by definition. **POST is not** — which is why it needs the header, and why automatic retries on POST are dangerous.

> With idempotency you can use queues, retry without fear and accept at-least-once delivery. Without it, every retry is Russian roulette. If you remember one reliability concept, make it this one.

## Retries

**Exponential backoff with jitter.** 1 s → 2 s → 4 s → 8 s, plus a few random milliseconds. Without jitter, a thousand clients retry simultaneously and finish off the service that was recovering.

| Retry | Never retry |
|---|---|
| 5xx (server failed) · 429 (throttled) · timeouts · network errors | 4xx: 400 malformed · 401 no credential · 403 no permission · 404 |
| Transient — in 2 seconds it may work | Will fail the same way forever. Retrying a 400 is an infinite loop |

## Circuit breaker

Closed → N failures → **open**: stop calling for 30 s, respond in degraded mode → half-open: let one through → good, close; bad, open again.

If the third party is down, continuing to call only burns your workers and stretches your timeouts.

> **A breaker with no plan B just turns one error into another error.**

Define out loud what "degraded" means here: serve from the older cache · queue it and promise confirmation by email · tell the caller "we'll call back in 10 minutes" · hand off to a human. **That is design, not an error handler.**
