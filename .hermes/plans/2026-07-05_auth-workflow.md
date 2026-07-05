# Authorization Workflow — such.gallery

**Goal:** Wire SIWE auth identity into every layer of the gallery experience so authenticated users appear as their wallet identity everywhere, and unauthenticated visitors remain as guests. Then add ENS resolution so wallet addresses resolve to human-readable names.

**Status:** Uncommitted changes already cover ~60% of this. This plan completes the remaining work.

---

## What's Already Done (uncommitted, in working tree)

These diffs are functional but not committed/deployed:

1. **`endpoint.ex`** — WebSocket `connect_info` passes session to `UserSocket`
2. **`user_socket.ex`** — `connect/3` reads `user_id` from session, assigns `current_user`
3. **`room_channel.ex`** — `presence_meta` uses `current_user.display_name` and `.avatar_color` instead of guest params
4. **`show.ex`** (magazine LiveView) — `mount/3` reads `current_user` from socket assigns, uses display_name/color or falls back to Guest-XXXX
5. **`page_controller.ex`** (walk page) — reads `current_user` from conn assigns, passes to template
6. **`accounts.ex`** — `truncate_address` updated to 6+4 chars (from 4+4)
7. **`runtime.exs`** — changed listener IP from `0.0.0.0` to `127.0.0.1` (this is **wrong for production** — Caddy needs to proxy)

## What's Missing

### A. Fix the runtime.exs regression
`127.0.0.1` binding breaks external access. Should stay `::` (IPv6 any, which also listens on IPv4) since Caddy reverse-proxies to it. Revert this change.

### B. ENS Resolution
Currently `display_name` is always a truncated address (`0x123456...7890`). Users with ENS names should see those instead.

**Approach:** Resolve ENS on user creation (not on every page load). Store the result in `display_name`. Refresh on subsequent logins if currently truncated.

**Changes:**
- **New module:** `SuchGalleryElixir.Accounts.EnsResolver`
  - `resolve_address/1` — calls Alchemy `names/resolveName` API (already have Alchemy client infra)
  - Returns `{:ok, ens_name}` or `{:error, :not_found}`
- **Update `Accounts.get_or_create_user/1`:**
  - After user creation, attempt ENS resolution
  - If ENS found → set `display_name` to ENS name
  - If not → keep truncated address (current behavior)
- **Update `SiweController.verify/2`:**
  - After successful login, check if user's `display_name` still looks like a truncated address (starts with `0x`, contains `...`)
  - If so, re-attempt ENS resolution and update if found
  - This handles users who register before their ENS is set, or ENS changes
- **No schema changes needed** — `display_name` field already exists and can hold ENS names

**Alchemy API:** `POST https://eth-mainnet.g.alchemy.com/v2/{key}` with method `eth_call` to ENS resolver contract, or use Alchemy's NFT API `getEnsName` if available. Simpler: Alchemy has `getEnsName({address})` in their enhanced API. Check Alchemy docs for the exact endpoint.

### C. Commit + Deploy the auth wiring
Once the runtime.exs regression is fixed and ENS is wired, commit the whole batch as one coherent change:
- "feat: wire SIWE identity into gallery presence, chat, and walk"

**Deploy:** `pm2 restart such-gallery`

### D. Slash Commands in Chat (post-auth)
Now that channels have `current_user`, slash commands can distinguish between authenticated and guest users.

**Changes to `room_channel.ex`:**
1. New private function `handle_command/3` — parses `/command` prefix from chat text
2. If text starts with `/` → route to command handler instead of persisting to DB/broadcast
3. If not → current chat behavior (persist + broadcast)
4. Commands to implement:
   - `/help` — returns available commands (works for everyone)
   - `/bid` — place bid on artwork (requires auth, future — stub with "coming soon" for now)
5. Command responses sent back as `{:reply, {:chat:command_response, payload}, socket}` or broadcast

**No new routes or schema changes needed.** Pure channel logic.

---

## Files to Change

| File | Change |
|------|--------|
| `config/runtime.exs` | Revert `127.0.0.1` back to `::` |
| `lib/such_gallery_elixir/accounts.ex` | Call ENS resolver in `get_or_create_user` |
| `lib/such_gallery_elixir/accounts/ens_resolver.ex` | **New** — Alchemy ENS resolution |
| `lib/such_gallery_elixir_web/controllers/api/siwe_controller.ex` | Refresh ENS on login |
| `lib/such_gallery_elixir_web/channels/room_channel.ex` | Add command routing in `handle_in("chat:new", ...)` |

## Verification

1. `source ~/.asdf/asdf.sh && MIX_ENV=prod mix compile` — no warnings
2. Visit `https://such.gallery` — anonymous user sees `Guest-XXXX` in chat/presence
3. Connect wallet — name updates to truncated address or ENS name in both magazine view and 3D walk
4. Open two browsers — one logged in, one guest — both see correct names in Presence list
5. Type `/help` in chat — get command list back
6. Type `/bid` as guest — get "requires wallet" error
7. Type `/bid` as logged-in user — get "coming soon" stub
8. `pm2 logs such-gallery --lines 20` — no errors

## Risks / Open Questions

- **Alchemy ENS endpoint:** Need to confirm the exact API call format. Alchemy's `getEnsName` is part of the NFT API v3 (under `getNftsForOwner` metadata) or available as a standalone. If not available, fallback to direct `eth_call` to ENS resolver contract at `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`.
- **ENS cache staleness:** We only refresh on login. If someone changes their ENS name, it won't update until they re-authenticate. Acceptable for v1.
- **Session cookie + WebSocket:** The uncommitted `endpoint.ex` change passes session to WebSocket connect. This is standard Phoenix but needs testing — if the session cookie isn't sent on WebSocket upgrade, auth breaks. The uncommitted code appears correct based on Phoenix docs.
