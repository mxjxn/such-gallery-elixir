# such.gallery — Agent Coding Guide

## Project Overview

Real-time multiplayer 3D art galleries on Elixir/Phoenix. Users walk around rooms with WASD movement, see other avatars via Presence, and chat. Mobile users get a 2D grid view with the same real-time data.

This is a portfolio piece for a Director of Software Engineering role. Ship by end of June 2026. Code quality, architecture rationale, and clean commit history matter.

## Stack

- **Elixir 1.17.3 / OTP 25** (via asdf — `.tool-versions` in project root)
- **Phoenix 1.7.23** with Bandit HTTP server (NOT Cowboy)
- **Phoenix LiveView 1.0.18** (rc.1 override in mix.exs — this is intentional)
- **Phoenix Channels + Presence** for real-time multiplayer
- **Tailwind CSS** (Phoenix Tailwind integration)
- **PostgreSQL** (not yet set up — Ecto needs to be added)
- **Three.js** (client-side, not yet added — will be separate from Phoenix assets)
- **Jason** for JSON encoding

## Current State

Phoenix app with PostgreSQL, slot-based galleries, Presence, RoomChannel, and magazine LiveView. Three.js client not started.

### What exists:
- `lib/such_gallery_elixir/application.ex` — Repo, PubSub, Presence, Endpoint
- `lib/such_gallery_elixir_web/router.ex` — `/`, `/gallery/:slug`, `/socket` via Endpoint
- `lib/such_gallery_elixir_web/endpoint.ex` — Bandit, code reloader, Tailwind watcher
- `mix.exs` — Phoenix deps, **no Ecto** (scaffolded with `--no-ecto`)
- `config/dev.exs` — PostgreSQL config commented out, not yet wired

### What's missing (Phase 1 priority):
1. Ecto + Postgrex in mix.exs
2. `SuchGalleryElixir.Repo` module
3. Database migrations (galleries, rooms, artwork, users)
4. Ecto schemas
5. `SuchGalleryElixirWeb.Presence` module
6. `SuchGalleryElixirWeb.RoomChannel` — join, move (position broadcast), chat
7. Socket mount in router
8. LiveView page at `/gallery/:id`
9. Three.js client (Vite) — basic room, WASD, position sync

## Architecture

```
Three.js client (3D) / LiveView client (2D magazine)
        ↕ WebSocket
Phoenix Channels — one topic per gallery room
  ├── Presence (avatars: position, name, color)
  ├── handle_in("move", %{x, z}) → broadcast position
  └── handle_in("chat:new", %{text}) → broadcast message
        ↕ Ecto / PostgreSQL
Galleries (with template) → has_many ArtworkPlacements → Artworks
GalleryTemplates → has_many LayoutSlots (predefined frame positions)
Users (wallet-based, SIWE later)
```

Each gallery is one walkable space and one Phoenix Channel topic (`room:{gallery_id}` — "room" is naming only, not a DB table). Presence tracks all connected avatars. Positions broadcast at ~10-30Hz from the Three.js client.

### Two viewing modes (NOT mobile fallback):
- **Gallery mode**: Full 3D walkable room via Three.js
- **Magazine mode**: 2D grid LiveView — same Presence data, same chat, different rendering

Both are legitimate first-class experiences. Magazine is for quick browsing, gallery is for events and沉浸.

## Artwork Resolver

Three source types for artwork inputs:
- `:url` — plain image URL. Resolve via OG meta tags (title, description, image).
- `:nft_ref` — `"chain:contract:tokenId"`. Resolve via on-chain `tokenURI` (eth_call on public RPC), then fetch metadata JSON. IPFS URIs resolved to `https://ipfs.io/ipfs/{cid}`. Fallback: Alchemy API.
- `:auction_listing` — `"chain:contract:tokenId"` but with auction house listing context baked into `listing_meta` JSONB. When loaded in browser, listing info (current bid, end time, seller, status) is already known — no separate lookup or comparison against auction contract needed.

**No marketplace URL parsing** (OpenSea, Zora, etc.) — only direct NFT refs and auction listing refs.

**Key design rule:** NFT refs are NOT just chain:contract:tokenId. The source_type determines behavior. An auction listing frame must immediately have listing data ready without additional lookups.

**RPC:** Via `NFT_RPC_URL` env var (keys not yet configured). Read-only eth_call for tokenURI only.

**Dedup:** `external_id` field stores the source_ref string. Artwork records are shared across galleries — if the same token is already in the DB, reuse it.

**Metadata status:** `:pending` → `:resolved` → `:failed`. Resolve async via `Task.start_link` after placement. On-chain tokenURI first, Alchemy API fallback.

**JSONB `listing_meta` field:** Different shapes per source_type:
- Auction listing: current bid, end time, seller address, status
- Direct NFT: null (standard metadata only)
- Plain URL: null (OG tags only)

## Database Schema

```
gallery_templates
  - slug (minimal_4, show_32, …), name, slot_count
  - layout (rectangular | l_shaped | open_plan), width, depth

layout_slots
  - template_id, slot_index, wall (back | left | right)
  - u, v (normalized 0..1), rotation_y, scale

galleries
  - name, slug, description, wall_color, frame_style
  - template_id, width_override, depth_override (optional)
  - owner_id (nullable until auth)

artworks
  - artwork_url, title, artist, external_id, aspect_ratio

artwork_placements
  - gallery_id, artwork_id, display_order, kind (slot | extra)
  - layout_slot_id (required for slot; unique per gallery)
  - override_wall, override_u, override_v, … (extras only)

users
  - wallet_address (unique), display_name, avatar_color

chat_messages
  - gallery_id, guest_name, body, inserted_at (recent history on mount; not cached separately)
```

Slot placements use predefined `layout_slots`; world x/y/z is computed by `Galleries.PlacementResolver` at read time. Extras (max 4 per gallery) use override coordinates.

**Chat (later):** Messages may become **Farcaster casts** replying to a gallery **parent cast id** — see `TASKS.md` → Future notes. Until then: Postgres = source of truth, PubSub = live fan-out only (no message cache layer).

## Conventions

- Module prefix: `SuchGalleryElixir` (app was generated with `--app such_gallery_elixir`)
- Web module prefix: `SuchGalleryElixirWeb`
- Follow Phoenix conventions: contexts for business logic, schemas for DB, LiveViews for UI
- Use `@moduledoc` on all public modules — explain *why*, not just *what*
- Use `@doc` on public functions
- prefer function clauses over `cond`
- prefer pattern matching over `if/else`
- No Elixir-specific magic — write code a reviewer can follow

## Phase 1 Tasks (June 1-10)

These are the immediate next steps. Work through them in order.

### Step 1: Add Ecto
```bash
# Add deps to mix.exs
{:ecto_sql, "~> 3.10"},
{:postgrex, ">= 0.0.0"}

# Create repo
# lib/such_gallery_elixir/repo.ex
defmodule SuchGalleryElixir.Repo do
  use Ecto.Repo,
    otp_app: :such_gallery_elixir,
    adapter: Ecto.Adapters.Postgres
end

# Add to application.ex supervised children
SuchGalleryElixir.Repo,

# Add database config to config/dev.exs
config :such_gallery_elixir, SuchGalleryElixir.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "such_gallery_elixir_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Add to config/runtime.exs for production
# Add ecto.setup and ecto.reset aliases to mix.exs
```

Then `mix ecto.create` (PostgreSQL must be running).

### Step 2: Migrations + Schemas (done — templates/slots, no `rooms` table)
- `gallery_templates`, `layout_slots`, `galleries`, `artworks`, `artwork_placements`, `users`
- `SuchGalleryElixir.Galleries` context with slot placement + `PlacementResolver`

### Step 3: Presence
- `lib/such_gallery_elixir_web/presence.ex`
- `use Phoenix.Presence, otp_app: :such_gallery_elixir`
- Track: `%{id: user_id, name: display_name, color: avatar_color, x: x, z: z}`

### Step 4: RoomChannel
- `lib/such_gallery_elixir_web/channels/room_channel.ex`
- `join("room:{id}", %{"user" => params})` — assign socket, track Presence
- `handle_in("move", %{"x" => x, "z" => z})` — update Presence, broadcast
- `handle_in("chat:new", %{"text" => text})` — broadcast to topic
- `handle_info(:after_join)` — push current Presence state to new joiner

### Step 5: Socket + Router (done)
- `lib/such_gallery_elixir_web/channels/user_socket.ex`
- `socket "/socket"` on Endpoint; `channel "room:*", RoomChannel`

### Step 6: LiveView Gallery Page
- `lib/such_gallery_elixir_web/live/gallery_live/show.ex`
- Renders room container, connects to Presence, displays chat
- Hook into RoomChannel via `{:ok, _topic, _socket}` from JS client

### Step 7: Three.js Client (Phase 1c — in progress)
- `assets/js/gallery_walk.js` (esbuild + npm `three`), route `GET /gallery/:slug/walk`
- Square room: floor + 4 walls; placements from `gallery_state` (resolved x/y/z)
- `square_32` template: 8 slots on each wall (`back`, `right`, `front`, `left`)
- WASD + pointer lock; `move` ~10 Hz; avatars as spheres + name sprites

## Do NOT

- Do NOT use Ecto multi if a simple pipeline works
- Do NOT add authentication yet (SIWE comes in Phase 3)
- Do NOT set up umbrella app structure
- Do NOT add Oban/Queuetopia — no background jobs needed yet
- Do NOT over-abstract — we have 4 tables and 1 channel
- Do NOT add CSS frameworks beyond Tailwind
- Do NOT worry about the Three.js client yet if you're working on Ecto/Channels — backend first

## Production Notes

- Deploy target: AWS (ECS Fargate + RDS, or single t3 instance for launch)
- Landing pages live at `/var/www/such.gallery/` on the server (static HTML, separate from this repo)
- `such.gallery` = production, `wow.such.gallery` = dev/preview
- PostgreSQL must be running for `mix ecto.create` to work — check with `systemctl status postgresql`

## Reference

- Phoenix Channels guide: https://hexdocs.pm/phoenix/channels.html
- Phoenix Presence: https://hexdocs.pm/phoenix/presence.html
- Ecto getting started: https://hexdocs.pm/ecto/getting-started.html
