# Server → Profile → Device → TV end-to-end milestone

## Acceptance flow
1. Sign in with a normal account.
2. Confirm only unclaimed servers are shown.
3. Claim a server and assign a custom display name.
4. Confirm a second account cannot claim that same server.
5. Confirm an already-assigned account skips server selection on the next sign-in.
6. Select a profile; the current phone is registered as a media device.
7. Open two player screens from the same profile/device context and confirm each playback session remains independent.
8. On a TV, open **TV Host Mode** and display the six-digit pairing code.
9. On a phone, open **TV Controller**, pair using the code, and verify the phone device ID is used rather than a shared hard-coded controller ID.
10. Verify Remote, Gamepad, Keyboard, and Second Screen commands travel through the authenticated TV pairing.
11. Verify unauthorized profiles/devices cannot send commands to a paired TV.
12. Verify the TV publishes its current playback state and the phone can read it without taking over the phone's own playback session.

## Architecture contract
- Profile is the shared identity.
- Device session identifies the physical phone/TV.
- Playback session identifies one title playing on one device.
- Multiple playback sessions may coexist for the same profile.
- TV pairing is authenticated to the account and profile.
- SSH credentials are never returned to clients.
