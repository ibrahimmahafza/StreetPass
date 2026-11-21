# Passby: design

Date: 2026-11-20. Working name "Passby" (Claude's call; the name is free to change).

## Intent

A hackathon entry for the theme "undo": bring back old software. Passby revives
the passing-by experience of early-2010s handhelds. Two people who both have the
app walk past each other, their phones notice, and the next time either opens
the app the other person is waiting in their plaza to say hello. It should feel
like that era: bright, white, friendly, a little toy-like.

It is for a live demo with a handful of phones in the room, not for the App
Store.

## Goals

- Onboarding in four short steps: name, make your character, Instagram handle,
  link Spotify or Steam. Then the plaza.
- Passing: two iPhones with the app swap a small profile over Bluetooth. No
  server, no accounts.
- The outline of the Dynamic Island goes green when someone new is waiting,
  the way a handheld's notification light did.
- The plaza fills the whole screen: a tilted white-and-aqua checkerboard seen
  from above, with everyone you have passed wandering on it. New people wait in
  a pulsing green ring until you press "Meet them", then walk up and greet you
  one at a time with a card: name, Instagram, three artists, three games, how
  many times you have passed.
- Tap anyone in the plaza to see their card again.
- Three round frosted buttons in a row at the top: your character, people you
  passed, settings. Each opens a white sheet.
- Sound: an arrival jingle, button blips, a babble voice that reads greetings,
  and an easygoing background music loop. Separate switches for music and
  sounds.

## Non-goals

Accounts, a server, chat, mini-games, Android, iPad layouts, localisation.

## Anti-goals

- Nintendo's characters, art, sounds or music. Achraf asked for Mii lookalikes,
  the Mii plaza art and the Mii music several times; Claude declined each time.
  Characters, plaza, sounds and music are original. This is Claude's call, not
  something Achraf agreed with.
- Anything that can stall the live demo: a login with no way around it, or
  relying on two locked phones finding each other in a pocket.

## Constraints

- iPhone only, iOS 17 or later. Built with Xcode 26.6 on Achraf's Mac; signing
  team `62GLRR66AN`. His phone is an iPhone 16; two iPhone 15 Pro Max have been
  paired with this Mac before.
- Bluetooth does not work in the simulator. Settings therefore has a "Simulate
  a pass" action, which is also the demo fallback.
- A Live Activity can only be started while the app is open and lasts about
  eight hours. It can be updated from the background.
- A Bluetooth characteristic holds at most 512 bytes, so the swapped profile is
  compact JSON with capped string lengths.
- Real Spotify login needs a Spotify developer client ID, and Steam needs a
  Steam Web API key. Both come from Achraf. Without them, and whenever a login
  fails, the person types their three artists or three games by hand.

## Approaches

1. **Native Swift, Bluetooth, Live Activity, no server (picked).** Both
   headline features, the green island outline and background Bluetooth, are
   native iOS features. Same stack as Achraf's Gym Log app, so his Mac is
   already set up for it.
2. React Native or Expo. Dropped: both headline features would still need
   native modules, so it adds a layer without removing any native work.
3. Location matching through a server. Dropped: needs a backend, accounts and
   constant location upload. Too much for a demo.

Achraf handed the how to Claude; approach 1 is Claude's pick.

## Decided with Achraf

- The look comes from the third mockup: full-screen checkerboard plaza, round
  floating buttons, white panels, plain grey text, no gloss. He called the
  checkerboard good and "the rest pretty fine".
- Round buttons sit at the top.
- The green Dynamic Island outline stays exactly as mocked.
- Minimal: the plaza, three menus, the "Meet them" flow. Nothing else.
- Background music is wanted.

## Claude's calls

- Characters: big-headed figures in hoodies with a changeable face, hair, hoodie
  colour and one extra. All drawing lives in one file so the look can change
  without touching anything else.
- The green outline is done twice: a Live Activity with a green keyline tint
  (visible outside the app) and a green glow drawn around the island inside the
  app (visible in the demo).
- Background music is an original loop rendered to an audio file by a script
  in the repo.
- Deadline unknown; scope assumes a demo this weekend.

## Left to the builder

- Project layout: a Swift package for the logic that can be unit tested
  (profile, payload encoding, store, encounter rules), an app target for UI,
  Bluetooth, audio and logins, and a widget extension for the Live Activity.
- How the project file is produced.
- The exact Bluetooth exchange, within the 512-byte limit.
- The melody and arrangement of the music loop.

## Changes after the first build (2026-11-20, late)

- **Characters are low-poly 3D.** After seeing the first build Achraf dropped the Mii
  request ("it doesn't have to be the miis") and asked for the characters to be
  "slimmer, lower poly, facial features sharper, and 3d". They are now flat-faced 3D
  models built in code (`Character3D.swift`): slim body, bevelled box head, sharp
  cut-out eyes, brows, nose and mouth. Same seven choices as before.
- **The plaza is real 3D** (SceneKit): a tilted camera over a checkerboard floor, people
  turn to face where they walk. `PlazaScene` is the simulation, `PlazaStage` draws it,
  `PlazaCamera` in PassbyCore is the shared geometry. Cards and lists use rendered stills.
- **Passing counts by last sighting.** Someone counts as passed again after ten minutes
  out of range, so phones left together stay one pass. Settings has "Forget everyone".
- **Bluetooth retries within about five seconds** after a failed attempt.

