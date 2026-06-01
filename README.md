# such.gallery — MMO 3D Gallery Experience

Real-time multiplayer 3D art galleries. Walk around, chat, view collections.

## Stack

- **Backend**: Elixir / Phoenix + PostgreSQL
- **Real-time**: Phoenix Channels + Presence
- **3D Client**: Three.js
- **Mobile**: 2D grid view (same channels, same presence)
- **Auth**: SIWE (Ethereum wallet login)
- **Deploy**: AWS (ECS Fargate + RDS)

## Architecture

```
Client (Three.js / 2D fallback)
  ↕ WebSocket
Phoenix Channels (room state, presence, chat)
  ↕ Ecto/PostgreSQL
Galleries, Artwork, Users, Frames
  ↕ REST
cryptoart.social API (listings, collections)
```

Each gallery room = one Phoenix Channel topic. Presence tracks all connected avatars in real-time. Artwork metadata stored in Postgres, images loaded client-side from external URLs.

## Target Scale

- 300 concurrent users per room
- Multiple simultaneous rooms
- Phoenix handles 10K+ WebSocket connections per node — single node sufficient for launch

## Features

- **3D galleries**: Walkable rooms with artwork on walls, real-time avatar presence
- **Dynamic generation**: Galleries created from art collections (own + cryptoart.social listings)
- **Customization**: Frame styles, wall colors, room layout options
- **Chat**: Real-time room chat
- **Mobile fallback**: 2D grid view with presence dots and chat
- **Gallery minting**: ERC-721 — gallery as an NFT (post-launch)
- **Events**: Curated live openings, scheduled showings
