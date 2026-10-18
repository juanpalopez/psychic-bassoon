# RFC: An online leaderboard with verified scores

Status: **parked** (owner, 2026-10-18): no backend until there is a player base and stable balance; Game Center on iOS is the preferred later route, and a local best plus a shared daily seed come first (see the ticket "Local best per seed and a shared daily seed"). The design below stays as the reference if a web leaderboard is wanted later. Draft for the owner, staged on 2026-10-18 (the owner chose to start with stage B) · 2026-10-17 · Phase 8 (Meta, polish, launch, native) · Author: Claude (Sonnet). Free-tier limits and product behaviour named below come from the author's knowledge of Cloudflare, Apple and Google at the time of writing and must be checked against their current pages before a ticket relies on them.

## 1. Summary

Players should be able to compare runs. This RFC proposes a leaderboard whose scores can be **trusted without trusting the client**:

- The backend runs on Cloudflare's free tier (Workers, D1, Turnstile), provisioned with Terraform. **Stage B uses no R2**, so no product on the account can bill.
- Identity is an **anonymous, server-issued player token** first, with Sign in with Apple, Game Center and Google linked later for recovery across devices.
- The server hands out the seed of every ranked run. In **stage B** it checks the claimed result against bounds the sim publishes. In **stages C and D** the client also sends back the **command log**; the sim is deterministic (same seed plus same commands gives the same game), so a **verifier re-plays the run with the real sim** and only then marks the score verified.
- Abuse is limited in layers: Turnstile, per-IP and per-player rate limits, size caps, plausibility checks before verification, and moderation tools after.

**Delivery is staged (owner, 2026-10-18).** Replay verification is the strongest defence but also the most to build, and most casual games do not have it. So:

| Stage | What ships | Anti-cheat | Sections |
| --- | --- | --- | --- |
| **B (first)** | Worker, D1, anonymous tokens, server-issued daily and weekly seeds, plausibility checks, rate limits, reports and bans | Obvious fakes are blocked; a score is **claimed, not proven** | 6.1, 6.2, 7 (no R2), 8, 9.3 (the checks that need no log), 10 to 15 |
| C | The client also uploads its command log when its score would enter the top N; only those logs are stored and replayed | Scores that are visible are verified | 9.1, 9.2, 9.4, with logs in D1 and deleted after verification except the top N |
| D | Every run is verified; account linking; App Attest | Full | the rest |

Everything in this RFC that mentions R2, the command log, the verifier or the replay belongs to stage C or D. Stage B is built so C can be added without changing the API or the data model (the `finish` call already allows an optional log).

The sim stays pure. A new adapter, `godot/net/`, does the HTTP, exactly as `render` and `ui` are adapters over the sim.

## 2. Goals and non-goals

**Goals**

- A daily and a weekly global leaderboard that a casual player cannot fake.
- No account to create: install, play, appear on the board.
- Everything fits the free tiers for the first few thousand players, and costs are bounded if the game does better than that.
- No change to `godot/sim` rules. Anything the sim must expose (a score, a version) is added by a sim ticket with tests and deep review, as the working rules require.
- Security and privacy are designed in: a threat model, a data inventory and a deletion path are part of the first release, not follow-ups.

**Non-goals (for now)**

- Real-time multiplayer, head-to-head matches, chat or friend lists.
- Defeating a perfect human or a perfect bot. A verified score proves the run was **played by the rules**, not that a person played it (section 9.6).
- Payments, ads and analytics.
- Android attestation. The design leaves a slot for it (section 6.4).

## 3. Decisions the owner must make

| # | Question | Default used in this RFC |
| --- | --- | --- |
| 1 | Daily seed, weekly seed, free-choice seed, or several? | A **weekly seed** and a **daily seed** are the ranked boards. Free-choice seeds stay local (no ranking). |
| 2 | Does the Phase 8 meta-progression (Golden Staples tech tree) count in ranked runs? | **No.** Ranked runs use a fixed standard loadout, so a score never depends on grinding and the verifier needs no per-player state (section 9.5). |
| 3 | Is a verification delay of up to an hour acceptable? | **Yes.** Scores show as "pending" and move to "verified" or "rejected". |
| 4 | Is the repository public (free Actions minutes and a free verifier) or private? | **Public** is assumed for the verifier on GitHub Actions. If private, see section 9.4 for the alternatives. |
| 5 | Must the display name be unique? | **No.** A name plus a short player code (for example `Mira#4F2K`). |
| 6 | Ship before the Phase 8 meta tree? | **Yes.** A leaderboard needs only the seed, the commands and a score. |

## 4. Threat model

The client (web build or iOS app) is in the player's hands. The web export can be unpacked, its scripts read and its calls replayed. **Nothing shipped in the client is a secret**, so no design here depends on one.

| Threat | Example | Where it is handled |
| --- | --- | --- |
| Forged score | `POST` a made-up 9,999 | Server-issued run, command log, replay verification (section 9) |
| Pre-planned run | Play the seed offline for hours, then submit the best | Server hands out the seed at run start; wall-clock check (section 9.3) |
| Replay of someone's run | Re-submit another player's log under a new name | One submission per run id, run bound to the player, duplicate-log detection (section 9.3) |
| Modified client or sim | Cheat engine, patched rules, edited content | The verifier re-plays with the real sim at a pinned version (section 9.2) |
| Speed-up | A headless client submits a 30-minute run in 2 s | Minimum wall-clock time per run (section 9.3) |
| Token theft | Copy a token from another device | Short-lived access tokens, rotating refresh tokens, binding where available (section 6) |
| Mass registration | A script makes 100,000 players to flood the board | Turnstile, rate limits, quotas per IP and per network (section 8) |
| Denial of service and cost attack | Fill D1, burn the request quota | Size caps, rate limits, a kill switch, billing alert (section 8.4) |
| Injection and abuse of text | SQL injection, offensive names, HTML in names | Parameterised queries, strict validation, filtering and reporting (section 10) |
| Enumeration and scraping | Download all players | Opaque ids, paging limits, public boards expose only name and code (section 10) |
| Secret leak | Signing key in git or in Terraform state | Secrets in Workers secrets, state in a private bucket, rotation (section 7) |
| Insider or supply chain | A bad dependency in the Worker | Few dependencies, pinned versions, review, `pnpm audit` in CI (section 11) |

## 5. Architecture

```
Godot client (web or iOS)                 Cloudflare (free tier)                    Verifier
  godot/net/  ───────── HTTPS ─────────►  Worker  "leaderboard-api"
   - register / refresh                    ├─ Turnstile siteverify
   - start run   (seed, run id)            ├─ JWT sign / verify  (Web Crypto)
   - finish run  (command log)             ├─ rate limiting
   - read boards                           ├─ D1  (players, runs, scores, bans)
                                                     ▲
                                                     │  admin API (service token)
                           GitHub Actions  ──────────┘  fetch pending runs, post results
                           headless Godot, pinned sim version
```

- **API Worker.** One Cloudflare Worker, TypeScript, routes described in section 6.5 and 9.
- **D1.** Relational data: players, runs, verified scores, bans, audit log.
- **Command logs (stage C).** Stored in D1 for runs that reach the top N, deleted after verification otherwise. R2 is deliberately not used: it is the one Cloudflare product here that bills when the free allowance is exceeded.
- **Verifier.** A scheduled GitHub Actions job runs the real GDScript sim headless (`godot --headless`) over pending runs. It talks to the Worker through a private admin API.
- **Client adapter.** `godot/net/` uses `HTTPRequest`, which works in the web export and on iOS. It never touches `godot/sim` internals: it reads the finished game through read-only accessors and a **run recorder** that is a new sim-side value (section 9.1).

## 6. Identity and authentication

### 6.1 Anonymous player first

1. First launch: the client calls `POST /v1/register` with a Turnstile token (section 8.1) and a chosen display name.
2. The Worker creates a player row with a random 128-bit id, a short player code and a random refresh secret. It returns an **access token** and a **refresh token**.
3. The client stores the refresh token in the platform's secure storage: the Keychain on iOS through a small plugin; on the web, `localStorage` (the best available, so the web build is the weakest and its tokens are treated accordingly).
4. Every other call sends `Authorization: Bearer <access token>`.

No email, no password, no personal data. Losing the install loses the player unless it was linked (section 6.3).

### 6.2 Tokens

- **Access token:** a JWT signed with **EdDSA (Ed25519)** through the Workers Web Crypto API, or ES256 if Ed25519 is unavailable on the target runtime. Lifetime **15 minutes**. Claims: `iss`, `aud` (`pck-leaderboard`), `sub` (player id), `iat`, `exp`, `jti`, `ver` (token schema version). The Worker pins the algorithm and rejects `alg: none` or any other.
- **Refresh token:** an opaque random 256-bit string. Only its **SHA-256 hash** is stored in D1. Lifetime **90 days**, **rotated on every use** (a used token is revoked and a new one issued). Reuse of a revoked token revokes the whole family and forces a new registration or a sign-in: that is how a stolen token is detected.
- **Key rotation:** the Worker holds the current and the previous signing key (`kid` in the JWT header) so tokens survive a rotation. Rotate every 90 days or immediately on a suspected leak.
- **Clock skew:** accept at most 60 s.
- **No sensitive data in tokens.** They carry only the player id.

### 6.3 Linking an account (later ticket)

A player who wants to keep their rank across devices links one or more of:

- **Sign in with Apple.** App Store rule 4.8 asks for it whenever another third-party sign-in is offered on iOS, so it ships first. The client gets an identity token and the Worker verifies the signature against Apple's published keys (JWKS), the `aud`, `iss`, `exp` and a nonce.
- **Game Center** on iOS (a signature the Worker verifies against Apple's public key) and **Google Sign-In** on the web.

The Worker stores a one-way link `(provider, provider subject hash) → player id`. It never stores the provider's token. Signing in on a new device finds the player, issues fresh tokens and revokes the old family. Linking two providers to one player and unlinking are supported; deleting the player removes the links.

### 6.4 Device integrity (optional hardening)

- **iOS:** Apple **App Attest** proves the request comes from an unmodified copy of the real app on a real device. It is the strongest cheap defence against scripted registration on iOS. Phase it in after launch: attest at registration, and require an assertion on `finish`.
- **Web:** no equivalent exists. The web build gets Turnstile and stricter limits, and the web board can be a separate board from the iOS board if cheating there becomes a problem.
- **Android:** Play Integrity if an Android build ever ships.

### 6.5 Authorisation

- Players act only on their own rows. The player id comes **only** from the verified token, never from a request body.
- The admin API (verifier, moderation) accepts a separate **service token** (a long random secret in Workers secrets, compared in constant time) plus, optionally, Cloudflare Access with a service token in front of `/admin/*`. It is never reachable with a player token.

## 7. Infrastructure as code (Terraform)

All Cloudflare infrastructure is created by the `cloudflare/cloudflare` Terraform provider in `infra/cloudflare/`:

| Resource | Purpose |
| --- | --- |
| D1 database | Players, runs, scores, bans |
| Worker script and its bindings | The API, with D1 and secrets bound |
| Route or custom domain, DNS record | `api.<domain>` (or `workers.dev` for the first release) |
| Turnstile widget | The registration challenge |
| Rate limiting and WAF rules | Edge-level limits (section 8.2) |
| API token for CI | Scoped to this account's Workers, D1 and Turnstile only |

Notes:

- The provider's v5 line renamed several resources; the ticket pins an exact provider version and follows its docs.
- **State** lives in **Terraform Cloud's free tier** (the `cloud {}` block): it gives locking and a history of state versions, needs no R2 and no card, and cannot bill. State holds secrets, so the workspace is private, nothing prints it, and it is never uploaded as a CI artifact. An R2 bucket through the S3 backend is the alternative (no versioning, no locking guarantee, a card is needed to enable R2); it is not used in stage B.
- **Secrets** (signing keys, service token, Turnstile secret) are created outside git (`openssl rand`, `wrangler secret put` or the provider's secret resource) and never committed. CI deploys read them from GitHub Actions secrets. A leaked secret is rotated, not patched.
- **Schema** is not Terraform's job. D1 migrations live in `infra/cloudflare/migrations/` and are applied by `wrangler d1 migrations apply` in CI.
- **Deploy.** A workflow on `main` runs `terraform plan` on PRs and `terraform apply` on merge for `infra/**`, and `wrangler deploy` for the Worker. The Worker and the infrastructure have separate environments: `staging` (own D1 and bucket) and `production`.
- **Least privilege.** The CI token cannot touch DNS for unrelated zones, and the Worker has no more bindings than it uses.

## 8. Abuse protection

### 8.1 At registration

- **Cloudflare Turnstile** token required on `/v1/register` (and on `/v1/recover`), verified server-side by the Worker with the secret and the client IP.
- One registration per IP per hour by default, with a higher allowance for shared networks detected through ASN, and a global cap per hour that, when hit, turns on a stricter challenge instead of failing.
- Display names: 3 to 16 characters, a restricted character set (letters, digits, space, a few marks), normalised (Unicode NFKC), trimmed, a blocklist for slurs and impersonation (`admin`, `moderator`, the studio name), and a short random code so duplicates are harmless.

### 8.2 Rate limits

Layered, cheapest first:

1. **Cloudflare edge rate-limiting rule** in front of the Worker (per IP, e.g. 60 requests a minute on `/v1/*`). Free plans allow a small number of such rules; verify the current limits.
2. **Worker-level limit** per player id, using the Workers rate-limiting binding or a Durable Object counter. Starting values: `start` 10 per hour, `finish` 10 per hour, reads 120 per minute.
3. **Quota per day:** a player has a maximum number of ranked runs per board per day, so a bot cannot grind retries.

Over-limit requests get `429` with `Retry-After`. Repeated violations escalate to a temporary block of the player and a flag on the account.

### 8.3 Input limits

- `Content-Length` and a hard cap on the body (command log at most 64 KB; a normal run is a few KB).
- Strict JSON schema validation: unknown fields are rejected, numbers are range-checked, strings have a maximum length, and the command list has a maximum count.
- Parameterised D1 statements only; no string-built SQL.
- Reject non-`application/json` content types. Respond with a fixed error shape and no stack traces.
- CORS: an allowlist of the game's origins (the GitHub Pages site and the native app, which does not use CORS). No wildcard.

### 8.4 Cost and availability controls

- A **kill switch** (a Worker variable): `ranked_enabled = false` stops new runs and submissions while boards stay readable.
- **Billing and usage alerts** on the Cloudflare account; Workers free-tier overage simply returns errors rather than billing, and the paid plan, if ever enabled, has a hard budget alarm.
- Boards are **cached** at the edge (`Cache-Control: public, max-age=30`) and the top 100 are stored in a single cached object, so reads cost almost no D1 queries.
- D1 writes are batched where possible, and old, unverified runs are pruned.

### 8.5 Moderation

- Players and scores can be **reported**; reports go to a moderation queue (an admin-only list).
- Admin actions (hide a name, remove a score, ban a player, revoke tokens) are logged in an append-only audit table with who, when and why.
- A **shadow ban** hides a cheater's scores from everyone else while they still see their own, so they do not simply make a new account at once.
- Bans are per player and, for repeat offenders, per device attestation id when available.

## 9. Anti-cheat

The design goal is simple: **the server must never believe a number the client types.** Every accepted score is recomputed from a seed the server chose and a command log, by the same deterministic sim the game uses.

### 9.1 What the sim must provide (sim tickets, deep review)

These belong to `godot/sim` and need tests first:

- **`Score`:** a pure function of the finished game state to a score tuple. Proposal: *waves cleared* (highest first), then *Heartstone health left*, then *fewer ticks to the last wave*, then *Buttons unspent* as a final tie-break. It lives in `godot/content` (numbers) and a small sim function. It does not depend on wall-clock time.
- **`RunRecorder`:** records each submitted command with its tick (`tick`, `kind`, `tower`, `col`, `row`, `tower_id`, `spec`) as plain data, so a finished game yields a **command log**. The goldens already store this shape (`godot/tests/goldens/replays.json`), so the format and the player exist; this adds a stable, versioned serialisation.
- **`SIM_VERSION`:** a constant bumped whenever any rule, number or stream changes (every balance change to `godot/content` or `godot/sim`). It is part of every run.
- **Ranked configuration:** the settings the game is created with (map size, footprint, second source, and in the future the frozen meta-loadout) are a single value, `RankedRules`, hashed into the run so the verifier replays under the same rules.

### 9.1b Stage B: claimed scores with bounds

Stage B has no command log. The client sends a **claimed result** (waves cleared, Heartstone health left, ticks, whether it won) for a run the server issued, and the Worker accepts it only when it passes these checks, all computed from numbers the sim publishes:

- **Wall-clock floor:** `ticks / 90` seconds (30 Hz at 3x) must have passed since `start`.
- **Shape:** waves cleared at most the number of waves in the game, Heartstone health between 0 and `START_HEARTSTONE_HEALTH`, a win only when every wave is cleared, and a loss only with 0 health.
- **Minimum ticks per wave:** a sim-derived floor (the fastest a wave can spawn and be cleared, measured from the content tables and the scripted bot), so `ticks` cannot be smaller than the waves claimed allow.
- **Maximum score:** the highest score reachable with those bounds; anything above is rejected.
- **Seed, version and expiry:** the run id, seed and `sim_version` must equal what `start` recorded, and one finish per run.
- **Quotas and rate limits** from section 8.

A forger can still claim a plausible best score (for example a perfect win in a believable time). Stage B stops the crude cheats, not a careful one. Mitigations in stage B: top scores are shown with an "unverified" mark, any player can be reported, an admin can remove a score or ban a player, and stage C is added when the first suspicious top score appears.

The sim provides `Score` and a `Bounds` table (waves, maximum health, minimum ticks per wave) with tests, and `SIM_VERSION`; `RunRecorder` and `RankedRules` wait for stage C.

### 9.2 Verification pipeline (stage C and D)

1. The client plays the run and records the command log.
2. `POST /v1/runs/{run_id}/finish` stores the log in D1 and the claimed score and tick count in D1 with status `pending`.
3. A scheduled **GitHub Actions** job (every 15 to 30 minutes, within free minutes if the repository is public) runs on the pinned sim version: `godot --headless` loads the seed, replays the commands tick by tick through `Game.submit` and `Game.tick`, stops at the end, and computes the real `Score`.
4. The job posts the result through the admin API: `verified` (the recomputed score equals the claim), `corrected` (the run is valid but the claim was wrong; the true score is used) or `rejected` (a command is illegal at its tick, the log does not end the game, the version is unknown, or it throws).
5. Only `verified` and `corrected` scores appear on the public board. Pending scores are shown to their owner and, if the owner chooses, greyed out in the public list.

Because the sim is deterministic and never uses `randf`, `Time` or `OS`, the result does not depend on the machine. The replay goldens already pass on both a Mac and the Linux CI runner, which is evidence for cross-platform float equality, but a **cross-platform replay check** (web export, iOS and Linux give the same hash on a fixed set of runs) is a ticket of its own before the iOS board opens.

**Version handling.** Each run records `sim_version`. The verifier checks out that exact tag (or uses a cached export of it). A balance release bumps `SIM_VERSION` and starts new weekly boards; old runs are not re-judged against new rules. Command logs stay in D1 (stage C) until they are verified, and only the top N are kept, so a bug found in the verifier can be re-run on the runs that matter. No R2 is needed.

If a board is public with an unlimited number of submitted runs, the verifier needs capacity. Cost control: verify only runs that would enter the **top N** (for example the top 200) of a board, plus a random sample of the rest for cheat detection. A run below the cut-off stays `unranked` and costs nothing.

### 9.3 Checks before and during verification

Cheap checks in the Worker reject obvious forgeries without running the sim:

- **Server-issued run.** `POST /v1/runs/start` (authenticated) creates a run id bound to the player, the board (daily or weekly), the seed and `sim_version`, and records the server time. The seed is chosen by the server (the board's seed), never by the client. A player cannot play a seed in advance on an offline copy and then claim a run, because the daily and weekly seeds are published only when the board opens. (The seed is a plain integer, so a determined player who learns it early can practise it. That is acceptable for a casual game and listed under limits.)
- **One finish per run.** A run id can be finished once, by its owner, before it expires (for example 3 hours after `start`).
- **Plausible wall-clock time.** A ranked run cannot be faster than the sim allows at the maximum speed (3x): `ticks / (30 * 3)` seconds. The server rejects a finish that arrives sooner than that, with a small tolerance for latency. A 40-wave game that needs many minutes of simulated time cannot be submitted two seconds after `start`.
- **Bounds.** Maximum ticks, maximum command count, ticks strictly non-decreasing, `kind` and ids in range, no command after the game ended.
- **Duplicates.** The SHA-256 of the canonical command log is stored; a log identical to another player's is rejected and flagged (it is a copied run).
- **Version and seed.** `sim_version` and `seed` must equal what `start` recorded.

During verification the sim itself enforces legality: an impossible command (not enough Buttons, an occupied socket, a sold tower) is rejected by the sim as it is in normal play, and a log that relies on that is flagged as `rejected` because the claimed result would not follow from it.

### 9.4 Where the verifier runs

| Option | Cost | Notes |
| --- | --- | --- |
| GitHub Actions, scheduled | Free minutes on a public repository | Simple; latency of the schedule; repository must be public or use paid minutes |
| Self-hosted runner on a small free-tier VM | Free to low | Needs maintenance and hardening |
| Cloudflare Containers or a paid worker | Paid | Instant verification becomes possible |

The default is a scheduled Actions workflow that pulls pending runs with a **service token** over the admin API, runs them, and posts back. The workflow runs from `main` only, never from a fork, and the token lives in Actions secrets.

### 9.5 The meta-progression problem

The GDD says a run's input is the seed, the commands and a **frozen meta-loadout** (the tech tree at the start). A ranked board that includes meta-progression would need the loadout in every submission, validated against the player's real unlocks, which the client can lie about. This RFC therefore keeps **ranked runs on a fixed standard loadout**. If the owner later wants a "veteran" board, the loadout becomes part of the signed `start` response (the server knows what the player earned) and part of the replay input.

### 9.6 Detection after the fact

- **Statistical flags:** an impossibly high win rate, a score far above the board median, command timings that are perfectly regular (a bot driving the real UI), or the same command log shape across accounts.
- **Re-verification** of the top ranks on a schedule, and again after any verifier or sim fix.
- **Appeals:** a rejected or banned player can write to a contact address; an admin can re-run the stored log.

### 9.7 What this does not stop

Say it plainly, so nobody is surprised:

- **A person who plays very well.** Not a cheat.
- **A bot that plays through the real client.** The repository's scripted bot is a legitimate way to produce a valid command log. The verified score is real, but a human did not earn it. The mitigation is social (a board label, "Assisted"), the timing heuristics above, and Apple App Attest on iOS. It is not a technical guarantee.
- **Seed practice.** A player who learns the weekly seed early practises it. The board is a skill contest on a known map, like most daily-seed games.
- **A compromised verifier.** It is trusted. Its token is scoped to the admin API and its runs come from the pinned sim.

## 10. Privacy, safety and compliance

- **Data collected:** a random player id, a display name, a player code, hashed refresh tokens, hashed provider subjects (if linked), runs (seed, version, command log, score, timestamps), and coarse abuse data (IP-derived counters, kept for days, not stored with the player). No email, location, advertising id or device name.
- **IP addresses:** used in memory for rate limiting and Turnstile. Cloudflare logs follow its own retention; the Worker does not write IPs to D1 except a salted hash in the abuse table for at most 7 days.
- **Retention and deletion:** `DELETE /v1/me` removes the player, links, tokens and scores, and any stored logs; a deleted player's run entries disappear from the boards. The in-game settings screen exposes it, as App Store and privacy rules require a way to delete an account created in the app.
- **Children and age rating:** names are free text, which is user-generated content. Apple expects a reporting and blocking path and a content filter for it; section 8.5 provides them. The ticket checks the age-rating questionnaire and COPPA/GDPR-K obligations for the target regions before launch.
- **Privacy policy:** a short page linked from the app and the web build, describing the table above.
- **Public board data:** display name, code, score, date, wave reached. Nothing else.
- **Transport:** HTTPS only, HSTS on the API domain, TLS 1.2 or above.

## 11. Security of the Worker and the supply chain

- Few dependencies (a JWT helper such as `jose`, a schema validator); pinned exact versions; `pnpm audit` and Dependabot on `infra/` and the Worker; the Worker bundle is built in CI and its size is checked.
- The API has an **OpenAPI** description in the repo, and a test suite (Vitest with the Workers test pool, or Miniflare) covering auth failures, token rotation and reuse, rate limits, validation and each rejection reason in section 9.3.
- Secrets scanning in CI (a pattern check on the diff).
- No wildcard CORS, no verbose errors, no reflection of input in responses, `X-Content-Type-Options: nosniff`, `Cache-Control: no-store` on authenticated responses.
- Logging: structured logs without tokens or command logs; an audit trail for admin actions. Retain a short, bounded history.
- A written **incident runbook** in `docs/`: how to rotate keys, flip the kill switch, revoke all tokens, delete a board and re-verify.

## 12. API sketch

All paths are under `/v1`, JSON in and out, errors as `{ "error": "<code>", "message": "<text>" }`.

| Method and path | Auth | Purpose |
| --- | --- | --- |
| `POST /register` | Turnstile | Create a player; returns access and refresh tokens |
| `POST /token/refresh` | Refresh token | Rotate tokens |
| `POST /link/apple` and others | Access token | Link a provider (later) |
| `POST /recover` | Provider token + Turnstile | Sign in to an existing player on a new device (later) |
| `GET /boards` | None | The current daily and weekly boards: id, seed, `sim_version`, opens, closes |
| `GET /boards/{id}?limit=&cursor=` | None | A page of verified scores (limit at most 100); optional `?around=me` with a token |
| `POST /runs/start` | Access token | Body: `board_id`. Returns `run_id`, `seed`, `sim_version`, `expires_at` |
| `POST /runs/{run_id}/finish` | Access token | Body: command log (versioned), claimed score and ticks. Returns `pending` |
| `GET /runs/{run_id}` | Access token (owner) | Status: `pending`, `verified`, `corrected`, `rejected` with the reason |
| `PATCH /me` | Access token | Rename (rate limited) |
| `DELETE /me` | Access token | Delete the player and their data |
| `POST /reports` | Access token | Report a name or score |
| `GET /admin/pending`, `POST /admin/results`, `POST /admin/ban` | Service token | Verifier and moderation |

Run ids and player ids are random and unguessable; boards expose only names and codes.

## 13. Data model (D1)

- `players(id, code, display_name, created_at, status, shadow_banned, deleted_at)`
- `refresh_tokens(hash, player_id, family_id, expires_at, revoked_at)`
- `provider_links(provider, subject_hash, player_id)`
- `boards(id, kind, seed, sim_version, opens_at, closes_at)`
- `runs(id, player_id, board_id, seed, sim_version, started_at, finished_at, ticks, claimed_score, true_score, log_hash, log_key, status, reason)`
- `reports(id, reporter_id, target_kind, target_id, reason, created_at, state)`
- `audit(id, actor, action, target, detail, at)`

Indexes: `runs(board_id, status, true_score desc)` for the boards, `runs(player_id, board_id)` for quotas, and a unique index on `runs(log_hash)`.

## 14. Free-tier and cost estimate

Order of magnitude, to be checked against the current Cloudflare pages: the Workers free plan allows on the order of 100,000 requests a day, D1 a few million row reads and 100,000 row writes a day with a few GB of storage, Turnstile is free. Stage B uses no R2, and Terraform Cloud's free tier holds the state, so nothing on the account can bill; the Workers and D1 free plans return errors past their limits instead of charging, as long as the account is never upgraded. Each ranked run is about 3 requests (start, finish, a board read) and a few D1 writes, so the free tier supports thousands of runs a day. The edge cache on boards keeps reads low. If a limit is hit the API degrades to errors (not charges), and the kill switch and caching are the first levers before moving to the paid plan, which is a few dollars a month.

## 15. Testing

- **Worker:** unit and integration tests for every route, every rejection reason in section 9.3, token rotation and family revocation, validation and rate limits.
- **Sim:** GUT tests for `Score`, `RunRecorder` (a recorded run replays to the same state) and `SIM_VERSION`, with a golden for the score of the five replay goldens.
- **End to end:** a staging stack, a scripted client that plays a real bot run, submits it, runs the verifier on it and sees `verified`; and negative runs that must be `rejected` (tampered command, wrong seed, edited score, replayed log, too-fast finish).
- **Cross-platform:** the same command logs give the same score on the web export, the Linux verifier and (before launch) an iOS build.
- **Security review:** a deep adversarial review of the Worker and the verifier flow before the first public board.

## 16. Tickets, in order

**Stage B (start here):**

- **B1. [Phase 8] Sim: `Score`, `Bounds` and `SIM_VERSION`** (sim, deep review, goldens unchanged, tests first).
- **B2. [Phase 8] Infra: Terraform for Cloudflare (D1, Worker, Turnstile), Terraform Cloud state, staging and production, CI plan and apply.**
- **B3. [Phase 8] API: register, tokens, Turnstile, rate limits, boards, run start and finish with the plausibility checks, reports and bans, `DELETE /me`, tests and OpenAPI.**
- **B4. [Phase 8] Client: `godot/net/` adapter, name entry, board screen, run submission, privacy link and delete-me.**

**Later:**

- **C1. Optional command-log upload for top-N scores, and the headless replay verifier** (adds `RunRecorder`, `RankedRules`, the admin API).
- **C2. Cross-platform replay check (web, Linux, iOS).**
- **D1. Account linking: Sign in with Apple, Game Center and Google; App Attest on iOS.**
- **D2. Incident runbook and moderation tools beyond reports and bans.**

B1 to B4 give a safe, free, web leaderboard that blocks the crude cheats; C and D gate stronger claims and the iOS board.

## 17. Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Float results differ between platforms | Honest runs rejected | The cross-platform check (ticket 7); the sim uses only `+ - * /`, `sqrt`, `floor`, `min`, `max`, `abs` |
| Balance changes invalidate old runs | Boards reset often | Versioned boards; a weekly cadence matches release rhythm |
| Verifier backlog | Long "pending" times | Verify the top N first; sample the rest |
| Free-tier limits change | Surprise cost or outage | Kill switch, caching, an exit plan to another host, no vendor-only data formats |
| Web build is easy to script | Fake registration, bots | Turnstile, limits, separate web board if needed |
| A leaked signing key | Forged tokens | Key rotation with `kid`, short access lifetime, revocation list |
| Offensive names | Store review and reputation | Filter, report, shadow ban, quick admin tools |

## 18. Alternatives considered

- **Platform leaderboards only** (Game Center, Google Play Games): no backend, free, but no web support and the score is trusted. Possible later on iOS next to this board.

- **Trust the client's score** (SilentWolf, a plain Supabase table): simplest, and cheaters reach the top within a day. Rejected for a game with a deterministic sim that makes verification cheap.
- **Supabase or Firebase instead of Cloudflare:** both have good auth, but Supabase free projects pause when idle and Firebase needs the paid plan for server-side logic. The Worker gives one small, testable codebase.
- **Server runs the sim live (authoritative server):** the strongest anti-cheat, and it needs a stateful, always-on server and a port of the sim loop. Overkill for a single-player game; replay verification gets the same guarantee for scores.
- **Hashing or signing the score on the client:** the key ships in the client and is extracted. Rejected.

## Sources and confidence

- Repository facts: the command kinds and `Game.create`, `Game.submit`, `Game.tick` in `godot/sim/game/`, the replay goldens and the verification they already do (`godot/tests/goldens/README.md`), the Phase 8 meta-progression constraint (`docs/PLAN.md`, `docs/GDD.md`). High confidence.
- Cloudflare, Apple and Google behaviour (free limits, Turnstile, App Attest, Sign in with Apple rule 4.8, Terraform provider resource names): the author's knowledge, not checked live. Medium confidence; every ticket rechecks the vendor page it depends on.
