## June 2026 — Ship Month

### Phase 1: Skeleton — DONE
- [x] Phoenix project scaffold + PostgreSQL
- [x] Schema: gallery templates, slots, galleries, artworks, users
- [x] Phoenix Channel for single room state (`room:{gallery_id}`)
- [x] Presence module (avatar positions, names)
- [x] Chat (broadcast + Postgres history, last 30 on mount)
- [x] Magazine LiveView at `/gallery/:slug` (presence + chat)
- [x] Three.js walk at `/gallery/:slug/walk` (square room, artwork planes)
- [x] WASD movement + position broadcast (~10 Hz)
- [x] `minimal_4`, `show_32`, `square_32` templates seeded
- [x] MeshBasicMaterial for artwork planes (1:1 JPEG color/brightness)
- [x] SIWE auth — nonce, verify, session, RequireAuth plug, wallet button UI
- [x] Demo galleries seeded: `demo` (minimal_4), `square` (square_32)

---

### Phase 2: Curation System — DONE
- [x] 2D curation page at `/galleries/:slug/curate` (LiveView, owner-only)
- [x] Slot grid showing frame positions with artwork assignments
- [x] Three input methods for artwork resolution:
  - Paste a link (cryptoart.social URL, NFT ref `nft:chain:contract:tokenId`, plain image URL)
  - Browse wallet NFTs via Alchemy `getNFTsForOwner` (paginated)
  - Direct chain/contract/tokenId lookup via Alchemy
- [x] Alchemy API client (`getNFTsForOwner` v3, `getNFTMetadata` v1)
- [x] Subgraph client for auctionhouse listings (GraphQL)
- [x] InputParser for cryptoart.social URLs (`/listing/eth/123` → mainnet, `/listing/123` → Base)
- [x] Unified Lookup module routing resolves through subgraph/alchemy/URL paths
- [x] Owner authorization — only gallery owner can curate
- [x] Dev mode — error details, debug timing panel, yellow banner (env-controlled)

---

### Phase 3: Chat Auth Context — NEXT

Wire SIWE auth into the gallery show page so signed-in users get their wallet identity in chat, anonymous users stay as guests.

- [ ] ENS resolution — resolve ENS names for display (Alchemy `names/resolveName` or direct RPC)
  - Fallback: `0x123456...7890` (first 6 chars after 0x + last 4)
- [ ] Update `show.ex` mount — check `current_user` from session, use `user.display_name` if authed, `Guest-XXXX` otherwise
- [ ] Pass wallet identity to walk JS hook via `data-*` attributes (replaces random guest name)
- [ ] Update `truncate_address` — currently 4+4 chars, change to 6+4 per user preference
- [ ] Refresh ENS on login if display_name is still truncated address

#### Slash Commands (after chat auth)
- [ ] `/bid` — place bid on artwork in gallery
- [ ] Command router in RoomChannel — parse `/` prefix, route to handlers instead of persisting as chat
- [ ] Auth gate on commands — `/bid` requires wallet, `/help` works for everyone

---

### Explicitly NOT in scope
- Wall color and frame style customization (AI-invented placeholders, never discussed)
- Auto-generation of galleries (off the table until further notice)
- Gallery CRUD — create/edit forms beyond curation (future)
- Mobile magazine polish
- Multiple room layouts / procedural generation
- Farcaster casts from chat
- Image upload to S3
- Marketplace / economy for galleries

### Future notes
- **Chat → Farcaster casts:** Room chat may eventually publish as Farcaster casts. Each gallery would map to a parent cast id; messages become reply casts. Postgres stays as local cache/history.
- **Gallery minting:** ERC-721 — gallery as an NFT (post-launch)
- **3D edit mode:** Curation page is 2D for now, may enhance to 3D in future
