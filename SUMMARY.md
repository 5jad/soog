# Summary: محمد — سوق (زبون ويب) — v3 React

## Goal
Rebuild the "زبون" web store as a React/Vite SPA (after old design scored 0), in 4 areas — customer `/store`, vendor `/vendor`, delivery `/delivery`, admin `/admin` — with a design system matching the mobile app identity, delivered in phases (customer → vendor → delivery → admin), deployed and verified live after each phase.
Live backend: Vercel (`https://soog-delta.vercel.app`) + Neon + Telegram bot.

## Approved Decisions
- Identity matches the mobile app: primary blue `#1D4ED8`, deep navy `#1E3A8A`, light sky `#38BDF8`, cyan `#06B6D4`, accent orange `#F97316`, background `#FAF9F6`, Cairo font, RTL.
- Old design deleted entirely; admin panel replaced by new 4-area web; phased delivery with live check after each phase.
- Phase 1 (customer) signals: Amazon-style 2-row header, Shein-style cards, cart drawer, order-tracking live map, points wheel, community chat (from study of 2026 best practices: Amazon/Shein/Temu/Noon/Zalando/Stripe/Glovo).

## Deleted (GONE, do not resurrect)
- `store-app/` (old source), `backend/src/public/store`, `backend/public/store` (old built output).

## Current State (Phase 1 COMPLETE, LIVE)
- Live at `https://soog-delta.vercel.app/store/` (HTTP 200, `assets/index-D4Neo7I5.js`, built 2026-08-11).
- `store-app/` is the new source: Vite 5.4 + React 18 + react-router-dom 6.26 (HashRouter) + leaflet 1.9.4; `base:'./'`; 62 modules; all pages compile.
- Design system `src/styles.css`: tokens, buttons, glass cards, nav pills, product/store cards, cart drawer, modals, timeline/steps, spin wheel, leaflet map, chat bubbles, orders, tables, skeletal loading, toasts, responsive at 900px/560px.
- `src/api.js` (`api/fmt/priceOf/pct/U/STAT/STAT_ORDER/timeAgo/copy`), `src/ctx.jsx` (AppProvider: token/me/cartN/favs/notifN/toast/prodId/cartOpen/loginOpen + login/logout/refreshCart/refreshFav/refreshNotif/toggleFav/addToCart).
- `src/components/`: Layout (2-row header, nav, pop, glass BottomNav), Promo (live `/api/ads` slider + fallback), Cards (ProductCard/StoreCard/DealCard/CatIcon), ProductModal, CartDrawer (free-shipping bar, coupon with subtotal, totals+fees), LoginModal (login/register/OTP tabs).
- Pages (14): Home, ProductsPage (all/category/search/offers, sort, color+size+price filters via `/products/meta`), StoresPage, StorePage (navy hero, coupons, tabs, follow, rating breakdown), ProductPage (variants, ask-vendor questions, sticky-cta, related; "Buy now" opens cart drawer), Checkout (address step + review per store + points redeem limited to first store + group order), Orders, OrderDetail (timeline, live-tracking card, cancel/reorder), Track (leaflet map: store/courier/user markers, path polyline, 12s polling, call/chat), ChatList (conversations + inline chat, 4s polling), Points (spin wheel 10 segments 4–6s animation, referral copy, tx list), Notifications (read/unread, nav by type), Favorites, Account (profile, addresses CRUD, roles links), Logout, ComingSoon (/vendor /delivery /admin placeholders).

## Work State
### Completed
- ✅ Old design deleted; study; project scaffold; npm install (67 pkgs).
- ✅ Design system, api, ctx, ui, components, layout, promo.
- ✅ All 14 customer pages; addBtn("Buy now") bug fixed (opens cart instead of navigating to /orders); `useParams` fixed in StorePage.
- ✅ `npm run build` clean (1.80s, no errors).
- ✅ dist copied to both `backend/src/public/store` and `backend/public/store`; pushed as commit `e1948cd` "Zaboon web v3: React SPA customer area (identity of mobile app)"; live check passed.

### Active
- ⏳ Phase 2: vendor area (`/vendor`) — products/categories/options management, orders accept/cancel/assign, coupons, profile/stats (server: `vendor.js` — routes exist: products CRUD incl options/categories, orders accept/assign, coupons, wallet, stats). Deliver + deploy + verify, then Phase 3 (delivery, `/delivery` — server exists) then Phase 4 (admin).

### Blocked
- ⚠️ USER ACTION NEEDED: add `TELEGRAM_BOT_TOKEN=8963795450:AAHKfSY7fq5Qg1-vhUaENVFta1ncYdmQ8Oo` to Vercel env vars (live bot doesn't reply without it).

## Next Steps
1. Phase 2 vendor pages in `store-app/src/pages/vendor/`: Dashboard (stats from `/api/vendor/stats`), Products (+options/categories CRUD via `POST /products`, `GET /products`, etc.), Orders (accept/cancel/assign from `/orders` + polling), Coupons, Profile/KYC, Wallet. Update `App.jsx` routes, Layout nav ("Enter as vendor" gate by role), build, copy dist, push, verify.
2. Phase 3 delivery pages (`/delivery`): new orders map, pickup, track, cash reports (delivery.js routes ready).
3. Phase 4 admin rewrite (`/admin`).
4. Test live: browse category, add to cart, checkout, track a real order.

## Commands
- Build: `npm run build` (in `store-app/`)
- Copy: `cp -r store-app/dist/* backend/src/public/store/ backend/public/store/`
- Deploy: git add -A && commit && push (Vercel auto-deploys ~50s); verify with curl.

## Notes / Gotchas
- Shell env: long commands hang; background processes get killed — verify with short-timeout curls (25s) after deploy.
- API shapes (verified by reading routes): `/stores` → rating/reviews_count/governorate_name/district_name/is_open/on_vacation/category_name/verified; `/stores/:id` → reviews+rating_breakdown+coupons; `/ads` → title/art/gradient/store_id/status; `/products` filters q/category_id/colors/sizes/min_price/max_price/best/sort/offer + `/products/meta` colors/sizes; `/cart` items have store_id/store_name/logo/delivery_fee/free_delivery_min; orders: `POST /api/customer/orders` (address info=address_id; group_id joins stores; redeem_points only first store to avoid stale-batch over-deduction); track `GET /orders/:id/track` (courier_lat/lng, path, chat via POST /conversations); `/points`, `/spin` (choices incl 0/200), `/referral`; notifications/read-all; favorites → `POST /api/customer/favorites` returns `{favorite:bool}` and GET `/favorites` → `{products}`.
- Mobile app `app/` is the visual reference for identity.
- `backend/.env` (secret, gitignored) holds Neon + Telegram token.