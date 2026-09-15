# Account membership and individual logins

This change separates **login identity** from **streaming account**.

- Email identifies a person/login identity.
- `accounts.id` identifies the streaming account.
- `account_members` connects a person to one or more accounts.
- Each account owns its own home server.
- A member's physical location does not change the account/server they access.
- Passwords are stored only as Argon2id hashes in `member_identities` (and the legacy owner credential table during migration).
- Actual movie, TV, and music files remain on the account's home server.

## Supabase migration order

1. `lib/supabase/migrations/streaming_service.sql`
2. `lib/supabase/migrations/live_persistence.sql`
3. `lib/supabase/migrations/account_membership.sql`

## Example

Account A -> Server A (Dallas)

- cesar@example.com -> owner
- sister@example.com -> member
- brother@example.com -> member
- mom@example.com -> member
- dad@example.com -> member

All five identities can authenticate with their own passwords and resolve to Account A / Server A.

If brother later creates Account B, the same identity can be both:

- owner of Account B / Server B (Chicago)
- member of Account A / Server A (Dallas)

The email never determines the server by itself.
