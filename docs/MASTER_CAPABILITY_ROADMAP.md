# Master capability roadmap

This document records the master additions list provided for the project. It distinguishes the Phase 1/2 foundation carried forward, numbered Phase 3 additions, and the separate productionization work. A capability appearing here means it is established in the product plan or incorporated into the project materials; it does not by itself certify that every production implementation is complete.

The canonical owner and shared-service rules remain in [Canonical Architecture](CANONICAL_ARCHITECTURE.md). The existing [implementation roadmap](../lib/roadmap_features.dart) remains the code-level feature map and is not renumbered to match this master list.

The core owned-library invariant is that only media acquired and imported/ripped from physical media the account owns becomes library media. Provider catalogs enrich entities but never create owned library records; marketplace purchases become ownership only after receipt/registration, and library media only after validated import. **Ownership & Physical Media Provenance** is an explicit cross-cutting group within the existing 500, mapped primarily across 31–48, 89–101, 116–128, 156–169, 282–296, 332–341, and 477–486. It adds no new numbered range.

## Phase 1/2 foundation carried forward

- Home/server connectivity, home tutorial and first-use guidance.
- Profiles, profile customization, account members, permissions, invitations, roles, statuses, and member/profile separation.
- Collections, watch progress/history, recommendations, playlists, recaps, Group Watch, music customization, and music visualizer.
- Media importing and ripping workflows; catalog/metadata architecture; media editions and versions; server-specific media ownership; storage management.
- Smart-home/security-related functionality and comics/manga support.
- Marketplace, marketplace search, stores, checkout/payment foundation, shipping/fulfillment foundation, seller commission controls, digital listings/purchases/fulfillment, product/store reviews, and seller workflows.
- Backend API, Supabase application-state architecture, account/device/session infrastructure, backend-to-Supabase synchronization, email-service foundation, MOCK ARM, and Phase 1 payment verification.
- Phase 2 backend functionality.

## Numbered Phase 3 additions

### #1–#16

1. **Marketplace Shipping Calculation** — shipping estimates, shipping origin, carrier configuration, and development calculation foundation.
2. **Seller Commission Controls** — seller-specific commission configuration and marketplace commission handling.
3. **Create Store → My Store / Store Dashboard** — seller store creation, My Store, seller dashboard, and store management.
4. **Full Store Customization / Store Builder** — appearance, sections, and seller-controlled presentation.
5. **Multi-Currency Marketplace** — multiple currencies and currency-aware pricing.
6. **Store Drafts + Preview** — save unfinished changes and preview before publishing.
7. **Store Version History** — revisions, previous versions, and restore/version-management foundation.
8. **Universal Sharing / Deep Links** — shareable products, stores, and content with deep-link navigation.
9. **Global Notification Center** — centralized marketplace and system notifications.
10. **Activity / Audit History** — user activity and administrative/seller auditing.
11. **Backup & Restore for Personal Configuration** — back up and restore personal configuration.
12. **Signup Password Validation & Submission Consistency** — password validation and consistent signup submission.
13. **Account Recovery & Secure Credential Management** — recovery workflows and credential/security management.
14. **First-Run Account Setup Wizard** — guided initial account configuration.
15. **Auto-Translate Lyrics** — automatic lyric translation support.
16. **Global Language & Localization System** — localization infrastructure, language selection, and internationalized UI/content support.

### #17–#53: Media Universe expansion

The supplied list groups these additions as a media-universe expansion rather than giving a separate title for every number. The recorded scope includes:

- Franchise/universe graphs, cross-media relationships, watch-order and listen-order relationships, franchise timelines, and continuity tracking.
- Relationship panels and editors; relationship search; cross-series connections; discovery/navigation between connected works; franchise dashboards and exploration.
- Collections and universe grouping; timeline views; spoiler-safe modes; progress-aware relationship displays, recommendations, and navigation.
- Metadata conflict handling and resolution, metadata locking, metadata refresh and refresh controls, improved metadata synchronization, country/region metadata, and release-date tracking.
- Release alerts and calendars; credits and people relationships; lyrics metadata; media entry points; resume functionality; and Play Next.

### Other Phase 3 expansions recorded before #114

- Expanded profile management, account/member separation, owner/admin/member roles, invitations, member status management, profile-specific configuration, and profile customization snapshots.
- Music configuration, device persistence and fingerprinting, secure device sessions, account recovery, credential management, backend-only credential storage, account synchronization, and external account/profile IDs.
- Promotions, discounts, seller campaigns, loyalty functionality, store-credit concepts, promotional rules, buyer eligibility rules, campaign configuration, and marketplace promotional infrastructure.
- Digital products, listings, purchase flows, digital fulfillment concepts, and separation between physical and digital fulfillment.
- Seller fulfillment workflows; buyer/seller and product/store reviews; review aggregation; buyer review photos; store ratings; and aggregated seller/store reputation.

### #114–#116

114. **Buyer Reviews, Photos & Store Rating Aggregation** — buyer reviews and photos, product-review information, store-rating aggregation, and aggregated seller/store reputation.

115. **Personal Randomized TV Guide / My TV Channel** — My Channel, TV Guide, Now Playing, Next, Later, and Play Now. The channel generates a continuous schedule from eligible content in the user's own library and supports 24/7-style programming, randomized selection, smart variety, repeat avoidance, multiple personal channels, programming modes/history, a channel editor, and profile-specific rules. It becomes available when the library has enough eligible content and does not insert commercial advertising into the personal channel.

116. **Live Shopping + Seller Product Videos + Optional Randomized Buyer Rewards** — seller livestreams and recorded product videos; prominent store placement; vertical video and swipe navigation; product cards and carousels; pinned/featured products; cart and purchase flows that keep buyers in the viewing experience; buyer Q&A, polls, live interaction, purchase notifications, scheduling, upcoming-stream notifications, replays, moderation, and inventory awareness. Sellers may optionally enable randomized rewards such as discounts, products, store credit, loyalty points, free shipping, or other configured prizes. Eligibility can use purchases, spend, quantities, selected products, followers, or seller-defined rules, with anti-abuse controls, validation, auditing, and event tracking. Rewards are opt-in per seller/event.

## Separate productionization and cleanup track

The numbered feature additions do not replace the broader Phase 3 productionization work. That work includes consolidating Phase 1/2 functionality into the normal Flutter/backend/Supabase architecture; removing temporary phase-specific wrappers or files only after verification; and completing production payments, backend/HTTPS, authentication/security, email, marketplace/shipping, home-server connectivity, media processing, Group Watch infrastructure, TV support, scalability, testing, and release hardening.

## Commerce ecosystem expansion

This is an expansion of the existing canonical commerce owners, not a second buyer store or seller store architecture. New implementation work maps to these established ranges:

| Canonical range | Owner | Scope expanded |
|---|---|---|
| 263–281 | Marketplace | Federated product/store discovery, categories and associations (genres, franchises, artists), advanced filters, recommendations, comparisons, product media, variants, bundles, customization, limited editions, digital and physical goods, and preorder/backorder availability. |
| 282–296 | Commerce transactions | Bag/cart, save for later, wishlist, checkout, buyer payment methods, purchase verification, gifts and gift cards, applicable subscriptions, order history/status, buyer protection, returns, refunds, and exchanges. |
| 297–306 | Reviews and reputation | Product/store reviews and aggregation, review media, seller replies, and reputation signals. |
| 307–323 | Stores and sellers | Seller dashboard and identity, store customization/merchandising, product management, customer interactions, verification, badges, and compliance/support workflows. |
| 324–331 | Seller analytics | Store, sales, product, customer, traffic, conversion, follower, and marketplace reporting. |
| 332–341 | Shipping and fulfillment | Shipping origins, carriers, estimates, delivery tracking, physical fulfillment, digital fulfillment, notifications, returns, refunds, and exchanges. |
| 342–352 | Loyalty, rewards, and promotions | Points, store credit, member pricing, referrals, coupons, personalized campaigns, scheduled/flash sales, discounts, eligibility, and loyalty programs. |
| 353–367 | Collaboration and creator commerce | Discovery, invitations, workspaces, chat, shared files/products/collections, campaigns, contracts, approvals, revenue splits/accounting, creator partnerships, and affiliate/referral partnerships. |
| 368–387 | Live shopping | Seller scheduling and streaming, product videos, pinned products/carousels, in-stream product discovery and purchase, Q&A, polls, chat/reactions, product drops, and replays. |
| 388–394 | Randomized live rewards | Optional seller-configured reward events, viewer eligibility, prize inventory/types, anti-abuse checks, notifications, audit records, and reward history. |

### Buyer experience

- **Discovery:** Product search across categories, genres, franchises, artists, and stores; advanced filtering; personalized recommendations; and side-by-side comparison.
- **Product page:** Variants, bundles, customization, collectible/limited-edition details, physical or digital delivery, preorder/backorder state, media, and review photos/videos.
- **Shopping and transactions:** Cart, wishlist, save for later, multiple buyer payment methods, checkout, purchase verification, gifting/gift cards, and subscriptions when supported by the product.
- **Orders and protection:** Order history and status, tracking and delivery estimates, returns, refunds, exchanges, and buyer protection.
- **Rewards and social shopping:** Loyalty, points, store credit, member pricing, referrals, coupons and sales; store follows, stories, events and memberships; reviews and replies; sharing to chats/stories; and purchases from live events.
- **Live shopping:** Stream/replay viewing, pinned products and carousels, in-stream cart and checkout, Q&A, polls, chat/reactions, and flash deals/product drops.

### Seller experience

- **Dashboard and analytics:** Performance overview for sales, orders, traffic, conversion, customers, followers, products, and reports.
- **Catalog and merchandising:** Create/edit physical and digital products, variants, bundles and limited editions; manage inventory/pricing, promotions, preorders/backorders, store homepage/branding/navigation/categories/collections/announcements/stories/events, and featured products.
- **Visual storefront design:** Reuse the shared page-presentation tokens for preset/custom themes, light/dark/device appearance, brand colors, solid/gradient/image backgrounds, hero/banner text and positioning, mobile hero imagery, typography scale/family, button/card shape, product card layout/image ratio, responsive grids, and section ordering. The Store page renderer applies the saved configuration without changing commerce behavior.
- **Orders and fulfillment:** Manage orders, origins and carrier configuration, delivery, physical and digital fulfillment, buyer notifications, returns, refunds and exchanges.
- **Payments and business identity:** Seller payment acceptance and seller payout destinations remain separate domains. Track payout account, history/status, provider references, verification, and tax/business information without exposing payout credentials to buyer checkout.
- **Growth and seller identity:** Campaigns, coupons, loyalty, store credit, member pricing, referrals, personalized and scheduled promotions; seller verification, badges, reputation, reviews/replies, support and compliance.
- **Collaboration:** Seller/creator discovery, invitations, shared workspace/chat/files/products, campaigns, contracts, approvals, revenue splitting, accounting, and affiliate/creator partnerships.
- **Live seller commerce:** Schedule → add products → go live → sell → fulfill. Optional rewards progress through eligibility → prize → notification → reward history, with seller configuration and auditability.

### Existing implementation boundary

The repository already has a local marketplace catalog with search and media associations, category/sort controls, recommendation scoring, product/store screens, cart, wishlist, save-for-later, product comparison, development checkout, local order records, store customization, seller payout-destination APIs, seller sales/order summary from local records, and the initial live-shopping schedule/interaction foundation. These are foundations and should be reused. Production payment capture, durable buyer order lifecycle, full seller analytics, returns/refunds, collaboration, full live streaming/cart checkout, and randomized reward eligibility/issuance still require implementation; the roadmap does not mark them complete merely because their canonical owner or UI concept exists.

Buyer checkout payment methods and seller payout destinations must stay separate in APIs, persistence, permissions, and UI. A payout provider reference is not a buyer payment token, and neither domain should store raw card or bank credentials.

## Numbering and implementation notes

- The supplied summary names #1–#16 and #114–#116 individually, and groups #17–#53 by theme. It does not provide separate entries for #54–#113, so this document does not invent them.
- Existing implementation files, schemas, and architecture documents remain authoritative for whether a particular behavior exists in code and what remains to be done.
- New roadmap requests should map to an existing canonical capability owner where possible. Use the ownership and no-duplicate rules in [Canonical Architecture](CANONICAL_ARCHITECTURE.md).
