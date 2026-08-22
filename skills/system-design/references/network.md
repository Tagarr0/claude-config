# Networking and APIs

## The layers

| Layer | What lives there |
|---|---|
| **Application** — HTTP, WebSocket, SIP, FTP, SMTP | What you write: "give me /v1/loads". The only layer you touch 99% of the time |
| **Transport** — TCP, UDP | Do we guarantee everything arrives, in order? Ports live here: `:443`, `:5432`, `:6379` |
| **Network** — IP | Which machine, and by which route |
| **Link / physical** | Never asked about |

**IP** is a machine's address. **DNS** translates names to IPs. **Port** is the extension inside that machine — IP + port = one specific service. Nginx listens on `:443` and distributes to `:3000`, `:3001`…

**TLS** encrypts what travels. It is *terminated* at the edge (LB or Nginx): the certificate lives there, not in your app. Inside your private network it can go unencrypted.

## TCP vs UDP

**TCP — "everything arrives, in order."** Handshake, ACKs, retransmission. If packet 2 is lost it's resent, and nobody sees 3 before 2. Used by HTTP, databases, SSH, almost everything. The guarantee costs time.

**UDP — "arrive now, and if something's lost, never mind."** No ACK, no resend, no waiting. A lost audio packet is a click and it moves on. Used by real-time audio and video (RTP), DNS, games.

> A voice call sends audio over UDP: better a 20 ms gap than half a second of delay. Retransmitting audio is pointless — by the time it arrives it's worthless.

**Connection cost.** Opening TCP+TLS takes several round trips. That is why connections are reused (keep-alive) and why connection pools exist.

## Public vs private

**Public IP** — only the load balancer needs one.
**Private network (VPC)** — not reachable from outside. Reserved ranges: `10.x.x.x`, `172.16–31.x.x`, `192.168.x.x`.

> **Your database must never have a public IP.** If it does, anyone in the world can try the door. It is the single most repeated security failure.

**Security groups / firewall** — rules like "only the app may talk to port 5432 of the database". Principle: open the minimum.

**NAT** — your app can call out, but nobody can call it. Note that many partners will ask you for a fixed IP to allow-list.

**Getting into a private machine**: SSH (port 22) with a key, never a password, through a bastion or tunnel. SFTP is SSH applied to moving files. Plain FTP is unencrypted and should not be used — though you will still meet it in the wild.

## Who calls whom

**The question that settles this whole topic: who notifies whom?**

| | How it works | Cost |
|---|---|---|
| **Pull (polling)** | You ask every N minutes, cursor per tenant | 99% of the time you ask for nothing, and data arrives late |
| **Push (webhook)** | They tell you when something happens | Instant and cheap. **Mandatory: verify the HMAC signature, respond in under 1 s (queue it), tolerate duplicates** |
| **Persistent connection** | Both talk whenever they want | The server keeps state per connection |

> **Design trick: make webhook and polling flow into the same normaliser.** Then the source of the event stops mattering.

## Connection styles

- **Request/response** — ask, they answer, it closes. 90% of everything you draw. The server can't initiate.
- **Webhook** — they call you when something happens.
- **gRPC** — binary calls between *your own* services, strict contract. Not for browsers or third parties.
- **WebSocket** — bidirectional and persistent. Chat, live audio, collaboration. Cost: the server holds state per connection.
- **SSE** — server talks only, one direction, over plain HTTP. What LLMs use to stream token by token. **If you only emit, use this — it's simpler than WebSocket.**
- **Long polling** — the old workaround: the request hangs until there's something.
- **SIP + RTP** — SIP sets up and tears down the call, RTP carries the audio over UDP.

## APIs

**3 to 5 endpoints, not more.** Cursor pagination, never offset. `Idempotency-Key` on anything that costs money. Anything irreversible: lock + idempotency.

**Outbound webhooks**: signed with HMAC.

**Retry on** 5xx, 429, timeout. **Never retry a 4xx** — it will fail identically forever.

**Data model: 5 to 7 entities.** And `tenant_id` in every table and every index.
