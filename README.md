# such.gallery — Real-time 3D Art Galleries

Walk around rooms with NFT art on the walls. See other visitors. Chat. Gallery owners curate their walls.

## Stack

- **Backend**: Elixir / Phoenix + PostgreSQL
- **Real-time**: Phoenix Channels + Presence
- **3D**: Three.js (WASD walk, pointer lock, mobile touch nav)
- **Auth**: SIWE (Ethereum wallet)
- **Artwork resolution**: Alchemy API + auctionhouse subgraph
- **Deploy**: PM2 on VPS, such.gallery

## Features

- **3D gallery walk** — WASD movement, artwork on walls, avatar presence
- **2D magazine view** — quick browse with presence and chat
- **Curation page** — assign NFTs to frame slots via paste/browse/lookup
- **Chat** — real-time room chat with guest or wallet identity
- **SIWE auth** — sign in with Ethereum wallet
- **Dev mode** — debug panel with error details and timing
- **Portable exhibitions** — owner-published, immutable JSON revisions for Social and other clients

## Architecture

```
Three.js (3D walk) / LiveView (2D magazine)
  ↕ WebSocket
Phoenix Channels (room state, presence, chat)
  ↕ Ecto / PostgreSQL
Galleries → ArtworkPlacements → Artworks
  ↕ REST
Alchemy API (NFT metadata) / Subgraph (auction listings)
```

Each gallery = one Phoenix Channel topic. Presence tracks connected avatars in real-time.

## Exhibition publication API

Gallery owners publish a snapshot explicitly. Republishing creates a new revision;
unpublishing removes the current public pointer while historical revision URLs remain valid.

```text
GET    /api/v1/exhibitions/:slug
GET    /api/v1/exhibitions/:slug/manifest/:revision
POST   /api/v1/exhibitions/:slug/publish
DELETE /api/v1/exhibitions/:slug/publication
```

The read endpoints are public. Publishing and unpublishing require the gallery
owner's SIWE session. The current endpoint has a short shared cache lifetime;
revision responses are immutable and can be cached permanently.
