# Account-Owned TV Channels + Automatic TV Guide

The TV system does **not** generate themed channels. Each account owns its channels and can create or delete them. The platform currently starts each account with one optional **Variety** channel.

## Pipeline

`Account-Owned Channel -> Channel Contents -> Content Intelligence -> Profile Eligibility -> Seasonal Ordering -> TV Guide / EPG`

The important boundary is that the intelligence system never creates a Marvel, Sitcoms, Halloween, Christmas, or other themed channel automatically. If a user wants one, they create it and decide what belongs in it.

## Default channel

A new account starts with:

- Variety

The Variety channel has no content filter, so its guide can use the account's accessible library. The account can delete Variety at any time. If it is deleted, the TV system stays empty until the user creates another channel.

## User-created channels

Users can create channels with:

- channel name
- Movies / Shows / Music content types
- title, genre, franchise, actor, artist, theme, or other keyword filters
- liked/favorites-only behavior
- guide start time

The TV Guide is generated from the contents that match that specific channel.

## Content intelligence

The intelligence layer derives explainable signals from metadata already present in the media graph:

- genres and tags
- franchises and themes
- holiday/season signals
- family vs mature signals
- movie vs episode/show classification

These signals influence **program ordering**, not channel ownership.

## Seasonal behavior

Seasonal programming remains active inside each user-created channel. For example:

- February can prioritize Valentine's/romance titles that are already in the channel.
- October can prioritize Halloween/horror titles already in the channel, while Kids profiles filter stronger material.
- December can prioritize Christmas/holiday titles already in the channel.

Seasonality never adds content to a channel that the user did not put there.

## Account scope

Channel settings are stored at the account level so the account's channel lineup is shared across its profiles/devices. Profile governance still determines which programs are eligible for the selected profile's guide.

## Backend API

Authenticated endpoints remain available for shared intelligence/policy support:

- `GET /api/v1/tv-channels/capabilities`
- `GET /api/v1/tv-channels/definitions?kids=true|false` — compatibility endpoint; it returns no generated channel catalog.
- `GET /api/v1/tv-channels/seasonal-policy?kids=true|false`
- `POST /api/v1/tv-channels/classify`

## Persistence

`Backend/database/tv_channels.sql` retains durable channel/intelligence/schedule storage for future server-side EPG generation. The Flutter TV screen currently persists account-owned channels through the authenticated application-record system and generates the guide from those channels locally.

## User-defined programming rules

Channels never receive platform-created themed content. Instead, each account can define programming rules for its own channels. A rule is matched against the account's owned-library intelligence graph, including title, description, themes, tags, franchise, genre, studio, production/company, relationships, actors, directors and writers.

Example: **October Horror Nights** can match `horror`, `slasher`, and `halloween`, activate only in October, and be marked **nightly**. The guide then gives matching movies a strong scheduling priority every night in October without adding any title that the account does not own or place in that channel.

The same mechanism supports Christmas in December, Valentine's programming in February, summer themes, franchise marathons, studio nights, actor/director nights, or any custom combination. Rules influence the schedule inside the channel; they do not create channels or bypass profile content-safety rules.
