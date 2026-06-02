## June 2026 — Ship Month

### Phase 1: Skeleton (June 1-10)
- [x] Phoenix project scaffold + PostgreSQL
- [x] Schema: gallery templates, slots, galleries, artworks, users
- [x] Phoenix Channel for single room state (`room:{gallery_id}`)
- [x] Presence module (avatar positions, names)
- [x] Chat (broadcast messages to room)
- [x] Magazine LiveView at `/gallery/:slug` (presence + chat via JS hook)
- [ ] Three.js: basic room (floor, walls, artwork planes) — Phase 1c
- [ ] WASD movement + position broadcast — Phase 1c
- [ ] Mobile polish for 2D grid — optional

### Phase 2: Gallery System (June 11-20)
- [ ] Dynamic gallery generation from image URLs
- [ ] Artwork placement algorithm (walls, spacing, sizing)
- [ ] Multiple room layouts / procedural generation
- [ ] Frame customization (styles, colors)
- [ ] Wall color customization
- [ ] Gallery CRUD (create, configure, persist)
- [ ] Artwork sources: own collection + cryptoart.social API

### Phase 3: Polish + Events (June 21-30)
- [ ] Custom or procedural 3D room models
- [ ] Auth (SIWE wallet connect)
- [ ] Gallery minting contract (simple ERC-721 → gallery ID)
- [ ] AWS deployment (ECS Fargate + RDS, or t3 instance)
- [ ] One curated live event — invite, test, iterate

### Not Doing (Post-June)
- Multiple floor plan types beyond initial set
- Complex avatar customization (colored spheres + names for launch)
- Marketplace / economy for galleries
- Advanced lighting / PBR materials

### Future notes
- **Chat → Farcaster casts:** Room chat may eventually publish as Farcaster casts (not only in-app PubSub/Postgres). Each gallery (or thread) would map to a **parent cast id**; user messages become **reply casts** targeting that parent. Postgres `chat_messages` stays useful as local cache/history and offline fallback until/unless reads move to a Farcaster indexer. Design for: `parent_cast_id` on gallery (or dedicated channel record), optional `cast_hash` on `chat_messages`, write path = persist locally → publish cast → PubSub for live UI.
