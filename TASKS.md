## June 2026 — Ship Month

### Phase 1: Skeleton (June 1-10) — DONE
- [x] Phoenix project scaffold + PostgreSQL
- [x] Schema: gallery templates, slots, galleries, artworks, users
- [x] Phoenix Channel for single room state (`room:{gallery_id}`)
- [x] Presence module (avatar positions, names)
- [x] Chat (broadcast + Postgres history, last 30 on mount)
- [x] Magazine LiveView at `/gallery/:slug` (presence + chat)
- [x] Three.js walk at `/gallery/:slug/walk` (square room, artwork planes)
- [x] WASD movement + position broadcast (~10 Hz)
- [x] `square_32` template: 8 frames per wall (32 total)
- [ ] Mobile polish for 2D magazine grid — optional, defer

**Already in codebase (Phase 1):** `Galleries.create_gallery/2`, `assign_artwork_to_slot/4`,
`PlacementResolver`, `gallery_state/1`, `wall_color` + `frame_style` on galleries, templates
`minimal_4` / `show_32` / `square_32`.

---

### Phase 2: Gallery System (June 11-20)

Work in this order — later items depend on earlier ones.

#### 2a. Gallery CRUD (create, configure, persist) — START HERE
- [ ] LiveView or form: **New gallery** (`/galleries/new`)
  - Pick template: `minimal_4` | `square_32` (template locked after create)
  - Fields: name, slug, optional description
  - Defaults: `wall_color`, `frame_style` from schema defaults
  - Redirect to `/gallery/:slug` on success
- [ ] **Edit gallery** (`/galleries/:slug/edit`)
  - Update: name, description, `wall_color`, `frame_style`
  - Do NOT change template after create (avoids re-slotting)
- [ ] Context: `update_gallery/2`, optional `list_galleries/0` for index
- [ ] Home / index: link to demos + “Create gallery” (no owner filter until SIWE)
- [ ] Tests: changeset, create flow, edit flow

**Open decisions (discuss before build):**
- [ ] Who can create — open `/galleries/new` vs gated later?
- [ ] Slug — user-chosen vs auto from name?
- [ ] Delete gallery — skip v1 or soft-delete?

#### 2b. Place collection from image URLs
- [ ] Context: `place_collection(gallery, urls_or_works)` — create `Artwork` rows, assign to free slots in order
- [ ] UI: paste URLs (one per line) on gallery edit or dedicated “Add art” step
- [ ] Overflow rules when URLs > slot count (pick one: truncate / error / extras max 4)
- [ ] Store `external_id` on artwork when provided (for dedup / cryptoart.social)
- [ ] Tests: fill slots, overflow, idempotency behavior

**Open decisions:**
- [ ] Metadata — URL only vs fetch OpenGraph/HEAD for title?
- [ ] Re-run — replace all placements vs fill empty slots only?
- [ ] Aspect ratio on `artworks` — store now for future frame sizing?

#### 2c. Wall color customization
- [ ] Color picker on gallery edit (hex validation already in changeset)
- [ ] Walk mode already reads `gallery_state.wall_color` — verify after edit

#### 2d. Frame customization (styles)
- [ ] Schema has `frame_style`: `classic` | `minimal` | `ornate`
- [ ] Walk: differentiate frames in Three.js (mesh/material per style)
- [ ] Magazine: optional CSS borders on thumbnails
- [ ] Edit form: frame style selector

#### 2e. Artwork sources: own collection + cryptoart.social
- [ ] Adapter pattern: `Source.list_works(ref) → [%{url, title, artist, external_id}]`
- [ ] “Own collection” = pasted URLs (2b) until wallet-linked
- [ ] cryptoart.social HTTP client + map to same struct → `place_collection/2`
- [ ] UI: browse/select works before placing

**Open decisions:**
- [ ] cryptoart.social API shape + auth
- [ ] Select all vs pick N before place

#### 2f. Artwork placement algorithm — MOSTLY DONE
Slot geometry is predefined on `layout_slots`; world coords via `PlacementResolver`.
Phase 2 scope = **auto-fill slots from a list** (same as 2b), not free-form drag-drop.

- [ ] Optional follow-up: scale frames from `aspect_ratio` in resolver
- [ ] Defer: manual slot picker UI, drag-to-place editor

#### 2g. Multiple room layouts / procedural generation — LIGHT for June
- [ ] Prefer new **hand-authored templates** (seed data) over runtime generator
- [ ] Candidates: fix/deprecate `show_32` (all back wall), add `wide_*` if needed
- [ ] Defer: L-shaped / open_plan procedural generator, runtime slot generation

---

### Phase 2 defer (explicitly not in June scope)
- Auth / `owner_id` (Phase 3 SIWE)
- Change template after gallery create
- Image upload to S3 (URLs first)
- Farcaster casts (see Future notes)
- New custom 3D room meshes (Phase 3)

### Suggested Phase 2 schedule (if June is tight)
| Week | Focus |
|------|--------|
| 1 | 2a Gallery CRUD + home links |
| 2 | 2b Place collection from URLs |
| 3 | 2c Wall color + 2d Frame style in walk |
| 4 | 2e cryptoart.social or buffer/polish |

---

### Phase 3: Auth + Events (June 22-30)

#### 3a. SIWE Auth — IN PROGRESS
Dependencies: `siwe` (spruceid/siwe-ex), `ex_abi` (hex encoding helpers)

- [x] Install Rust via asdf (siwe-ex uses Rustler NIF)
- [ ] `Siwe` lib module: wrapper around `siwe` hex package
  - `generate_nonce/0` → `Siwe.generate_nonce()`
  - `parse_message/1` → `Siwe.parse(message_string)`
  - `verify/2` → `Siwe.parse_if_valid(message, signature)` → returns `{:ok, %Siwe{}}` or `{:error, reason}`
  - Verify domain matches `such.gallery`, chain_id allowed, not expired
- [ ] `Accounts` context:
  - `get_or_create_user/1` — find by wallet_address, or create with defaults
  - `verify_siwe_session/2` — parse + verify + return user, fail on mismatch
- [ ] JSON API endpoints:
  - `POST /api/siwe/nonce` — generate nonce, store in session, return JSON `{nonce}`
  - `POST /api/siwe/verify` — accept `{message, signature}`, verify, set `user_id` in session, return `{address, display_name}`
  - `DELETE /api/siwe/session` — clear session, log out
- [ ] `RequireAuth` plug: reads `user_id` from session, assigns `current_user`, redirects or 401
- [ ] Router: protect `/galleries/new` and `/galleries/:slug/edit` behind auth
- [ ] Frontend JS: wallet connect button, `personal_sign` flow, nonce request, verify call
- [ ] Tests: SIWE message parse, signature verify (use known test vectors), auth flow integration

#### 3b. Minting contract — TODO
- [ ] Simple ERC-721 (non-upgradeable)
- [ ] Mint = gallery ID claim
- [ ] Deploy script

#### 3c. Live event — TODO
- [ ] Invite list
- [ ] Test SIWE flow end-to-end
- [ ] Iterate

### Not Doing (Post-June)
- Multiple floor plan types beyond initial set
- Complex avatar customization (colored spheres + names for launch)
- Marketplace / economy for galleries
- Advanced lighting / PBR materials

### Future notes
- **Chat → Farcaster casts:** Room chat may eventually publish as Farcaster casts (not only in-app PubSub/Postgres). Each gallery (or thread) would map to a **parent cast id**; user messages become **reply casts** targeting that parent. Postgres `chat_messages` stays useful as local cache/history and offline fallback until/unless reads move to a Farcaster indexer. Design for: `parent_cast_id` on gallery (or dedicated channel record), optional `cast_hash` on `chat_messages`, write path = persist locally → publish cast → PubSub for live UI.
