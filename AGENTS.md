# such.gallery — Agent Coding Guide

## Project Overview

Real-time multiplayer 3D art galleries on Elixir/Phoenix. Users walk around rooms with WASD movement, see other avatars via Presence, and chat. Gallery owners curate their walls with NFTs from various sources. Auth is SIWE (Ethereum wallet).

Portfolio piece for a Director of Software Engineering role. Ship by end of June 2026.

## Stack

- **Elixir 1.17.3 / OTP 25** (via asdf — `.tool-versions` in project root)
- **Phoenix 1.7.23** with Bandit HTTP server (NOT Cowboy)
- **Phoenix LiveView 1.0.18** (rc.1 override in mix.exs — intentional)
- **Phoenix Channels + Presence** for real-time multiplayer
- **SIWE** via `siwe-ex` (Rustler NIF — Rust via asdf)
- **PostgreSQL** with Ecto
- **Three.js** (client-side, bundled via esbuild)
- **Tailwind CSS** (Phoenix Tailwind integration)
- **Alchemy API** for NFT metadata and wallet browsing
- **GraphQL subgraph** for auctionhouse listings

## Current State

Full working app: 3D walkable galleries, 2D magazine view, SIWE auth, curation page with artwork resolution from multiple sources, chat, presence.

### What exists:
- **3D walk** at `/gallery/:slug/walk` — Three.js room with WASD, artwork on walls, avatars, mobile nav
- **Magazine view** at `/gallery/:slug` — 2D grid with presence dots and chat
- **Curation page** at `/galleries/:slug/curate` — 2D LiveView, owner-only, three input methods
- **SIWE auth** — nonce/verify/session endpoints, RequireAuth plug, wallet button component
- **Chat** — Phoenix Channel `room:{gallery_id}`, Postgres history, Presence
- **Artwork resolution** — Alchemy (NFTs, metadata), subgraph (auction listings), URL parsing
- **Dev mode** — env-controlled, shows error details and debug timing panel

### Key files:
- `lib/such_gallery_elixir/galleries.ex` — main context (CRUD, placements, chat, gallery_state)
- `lib/such_gallery_elixir/galleries/lookup.ex` — unified resolver (subgraph/alchemy/URL routing)
- `lib/such_gallery_elixir/galleries/alchemy_client.ex` — Alchemy HTTP client
- `lib/such_gallery_elixir/galleries/subgraph_client.ex` — GraphQL subgraph client
- `lib/such_gallery_elixir/galleries/input_parser.ex` — parses cryptoart URLs, NFT refs, plain URLs
- `lib/such_gallery_elixir/accounts.ex` — SIWE auth, user get/create
- `lib/such_gallery_elixir_web/live/gallery_live/curate.ex` — curation LiveView
- `lib/such_gallery_elixir_web/channels/room_channel.ex` — real-time room
- `assets/js/gallery_walk.js` — Three.js walk client

## Architecture

```
Three.js client (3D) / LiveView client (2D magazine)
        ↕ WebSocket
Phoenix Channels — one topic per gallery room
  ├── Presence (avatars: position, name, color)
  ├── handle_in("move", %{x, z}) → broadcast position
  └── handle_in("chat:new", %{text}) → broadcast message
        ↕ Ecto / PostgreSQL
Galleries → has_many ArtworkPlacements → Artworks
GalleryTemplates → has_many LayoutSlots (predefined frame positions)
Users (SIWE wallet-based)
        ↕ REST
Alchemy API (NFT metadata, wallet browsing)
Auctionhouse Subgraph (GraphQL — listings)
```

Each gallery = one walkable space + one Phoenix Channel topic (`room:{gallery_id}`). Presence tracks all connected avatars. Positions broadcast at ~10Hz from Three.js.

### Artwork Resolution

Three input paths on the curation page:
1. **Paste link** — cryptoart.social URL (`/listing/eth/N` → mainnet, `/listing/N` → Base), NFT ref (`nft:chain:contract:tokenId`), or plain image URL
2. **Browse wallet** — Alchemy `getNFTsForOwner` with pagination
3. **Direct lookup** — chain + contract + tokenId via Alchemy

All routed through `Lookup.resolve/1` → subgraph or Alchemy.

## Database Schema

```
gallery_templates
  - slug (minimal_4, show_32, square_32), name, slot_count
  - layout (rectangular | l_shaped | open_plan), width, depth

layout_slots
  - template_id, slot_index, wall (back | left | right | front)
  - u, v (normalized 0..1), rotation_y, scale

galleries
  - name, slug, description, template_id
  - owner_id (nullable)

artworks
  - artwork_url, title, artist, external_id, source_type, metadata_status

artwork_placements
  - gallery_id, artwork_id, layout_slot_id
  - display_order, kind (slot | extra)

users
  - wallet_address (unique), display_name, avatar_color

chat_messages
  - gallery_id, guest_name, body, inserted_at
```

## Conventions

- Module prefix: `SuchGalleryElixir` (app generated with `--app such_gallery_elixir`)
- Web module prefix: `SuchGalleryElixirWeb`
- `@moduledoc` on all public modules — explain *why*, not just *what*
- `@doc` on public functions
- Prefer function clauses over `cond`, pattern matching over `if/else`
- No Elixir-specific magic — write code a reviewer can follow
- Artwork planes use `MeshBasicMaterial` (NOT `MeshStandardMaterial`) for 1:1 JPEG color accuracy
- Edit gallery = 2D web page, NOT 3D
- Frame style and wall color are NOT NFT metadata traits (server-managed visuals only, not in current scope)

## Build & Deploy

- `source ~/.asdf/asdf.sh` before any `mix` commands (Elixir + Rust via asdf)
- `MIX_ENV=prod mix compile` for production builds
- `start_prod.sh` exports env vars from `.env` (Alchemy, subgraph, dev mode)
- Deploy via `pm2 restart such-gallery` (runs start_prod.sh)
- `.env` is gitignored (never commit API keys)
- Git repo: `mxjxn/such-gallery-elixir` on `main`
- Live: https://such.gallery

## Do NOT

- Do NOT use `on_mount` hooks referenced by string tuple in `live_view` macro — causes prod crash loop (module not compiled at runtime). Assign directly in `mount/3` instead.
- Do NOT set up umbrella app structure
- Do NOT add Oban/Queuetopia — no background jobs needed yet
- Do NOT add CSS frameworks beyond Tailwind
- Do NOT propose wall color / frame style features — these were AI placeholders, never agreed on
- Do NOT propose auto-generation of galleries — explicitly off the table
