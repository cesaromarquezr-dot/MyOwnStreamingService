# Shop Marketplace

## Scope

The Shop destination is the general marketplace. Contextual Shop buttons use the same catalog but filter by the selected movie, show, franchise, song, artist, album, playlist, or collection.

## Checkout

There are two checkout entry points:

1. Store checkout: checkout from a single seller store, including Buy Now for one product or checkout of that store's bag lines.
2. All-stores checkout: checkout every product currently in the global bag, regardless of seller.

The checkout offers the saved subscription payment method or a different card. Raw PAN/CVV values are never persisted. The current Flutter implementation uses a development payment gateway; production must replace it with a PCI-compliant provider-side tokenization/hosted checkout integration.

## Seller flow

A real `shop_stores` record is the seller source of truth. Store owners get Seller Dashboard in navigation. Sellers can create products, associate one product with multiple media entities, manage inventory/featured state, edit/delete products, and edit store appearance.

## Import Review

Verified disc review now includes languages found, subtitles found, and extras. Extras can include behind-the-scenes material, deleted scenes, audio commentary, trailers from other movies, and other detected bonus features.

## Combined playlist/collection

A combined collection stores normal media IDs and music track IDs in one container. The original collection and playlist remain unchanged. The Collections UI provides a Combine action for selecting an existing collection and playlist.

## Marketplace checkout, seller payouts, and shipping

- Sellers can enable or disable Card on File, Credit/Debit Card, Apple Pay, Google Pay, PayPal, and Shop Pay.
- The platform commission is seller-configurable but cannot be lower than 5%.
- The checkout displays products, shipping, and a seller-funded platform service fee. The service fee is deducted from seller proceeds rather than silently added on top of the buyer's displayed total.
- Example: if the buyer total is USD 100.00 and the seller commission is 5%, the platform records USD 5.00 and the seller payout estimate is USD 95.00.
- Products remain priced in the seller's/store's currency while checkout can display a buyer-selected currency. Production must replace the development exchange-rate table with a verified foreign-exchange provider.
- A successful payment creates a seller notification such as `John Smith paid for Christmas Mugs`.
- Seller order handling supports shipping-company and tracking-number entry plus a seller-to-buyer message such as `Hello, John, I'm Johanna. Your tracking number is ... from ...`.
- Raw card numbers and CVV values are not persisted. Production payment methods must use provider-hosted/SDK tokenization.

## Seller promotions

Stores can publish and activate store-wide promotions such as:

- **Buy X, get Y free** — for example, Buy 3, Get 1 Free.
- **Coupon percentage** — for example, `HOLIDAY10` for 10% off.

Promotions are applied at checkout, after quantity pricing and before the
seller-funded platform commission is calculated. The original product price
remains unchanged. Sellers can disable or delete promotions from Store
Settings, and buyers can enter a coupon code during checkout.

## Buyer orders, shipping, questions, and reviews

After a successful checkout, the buyer is returned to the main Shop page and the purchased order is recorded. Each seller receives a notification containing the buyer name and the purchased product details, including quantity, variant/options, and any customization details supplied with the order.

Sellers can open the order and send the buyer the shipping company, tracking number, and a message when the package is ready. Buyers can view their Shop orders and delivery status.

Buyers can also ask a seller whether a product is available. Seller dashboards expose these questions so the seller can reply.

After delivery, a buyer can submit a 1–5 star rating, written review, and product photos. The production implementation should store photos in object storage and keep only safe URLs/paths in the review record. Development mode includes a manual “Mark as delivered” action; production should transition delivery status from a carrier integration/webhook.


### Seller-controlled customization
Sellers can mark each product as customizable or not. Customizable products can independently allow color selection, size selection, custom text, and a customer-supplied image. Non-customizable products (for example, a fixed Disney Loteria product) show no customization step at checkout. On computers, image customization uses an Import image from computer action; on phones, the buyer can Take a photo or Choose from library.
