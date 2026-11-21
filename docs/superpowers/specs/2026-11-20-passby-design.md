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

- **Characters are smooth 3D with egg heads and pencil faces.** After seeing the first
  build Achraf dropped the Mii request ("it doesn't have to be the miis"). A low-poly
  version came back as "way too cubical", and he then asked for heads like "up-side down
  eggs" and facial features that "look more pencil drawn". The models are built in code
  (`Character3D.swift`): a slim body in a hoodie, a smooth egg head that is widest above
  the middle, and a face sketched as pencil strokes onto its front. Same seven choices.
- **The plaza is real 3D** (SceneKit): a tilted camera over a checkerboard floor, people
  turn to face where they walk. `PlazaScene` is the simulation, `PlazaStage` draws it,
  `PlazaCamera` in PassbyCore is the shared geometry. Cards and lists use rendered stills.
- **Passing counts by last sighting.** Someone counts as passed again after ten minutes
  out of range, so phones left together stay one pass. Settings has "Forget everyone".
- **Bluetooth retries within about five seconds** after a failed attempt.
- **Zoom, and a bar at the bottom.** Achraf asked for "a feature to be able to zoom" and a bar
  at the bottom. The menu was briefly moved into that bar; he then asked for the round buttons
  back at the top with the bar kept "just to not make the app look too empty". The bar now
  shows numbers (people, passes, whether passing is on) in the same frosted style, which is
  Claude's call for what it should hold. Pinch zooms up to three times around the fingers; a
  drag slides the view while zoomed. People are always placed through the unzoomed camera, so
  zooming never moves them.
- **"Time to meet someone new".** Achraf asked that when two phones detect each other the
  Dynamic Island pops up with that line and an arrow towards the other person that updates
  live like a compass, for 15 seconds. Bluetooth has no sense of direction, so the phones swap
  a ranging token during the Bluetooth exchange and range each other with the Ultra Wideband
  chip (`NearbyFinder`). With the app open, the app draws the island opening itself (iOS hides
  an app's own Live Activity while it is on screen). With the app in the background, the Live
  Activity is updated with an alert, and its meeting state expires through a stale date.

## Changes after the first test on two phones (2026-11-21)

Achraf and a friend installed build 1 from TestFlight. Bluetooth passing worked ("you pretty
much nailed the bluetooth thing"). He asked for five changes.

- **Collisions.** "You need to fix the collision physics." In build 1 people were pushed apart
  when they overlapped, so someone standing could be slid across the floor by a walker. Now
  nobody is ever pushed. Someone standing stays exactly where they are; someone walking stops at
  whoever is in the way, picks a side and goes round, turns before stepping and only steps the
  way they face. The rules are `Crowd` in PassbyCore, and `PlazaScene` moved into PassbyCore so
  its tests can check every frame that nobody standing moved, no step was sideways or backwards,
  and no two people overlapped.
- **Your character in the middle.** "One's mii should always be at the center of the
  chessboard." Your own character now stands at the centre of the floor and never wanders.
  Nobody stops to stand within 3.7 floor units of you, and people who walk up to say hello
  gather beside you and face you while you turn to whoever is talking. The clear space and the
  greeting places are Claude's calls. Tapping your character opens the character sheet.
- **Moving the view.** "We should be able to not just zoom." He did not say what else, so this
  is Claude's reading: the plaza moves like a map. Drag slides it (at any zoom now), pinch
  zooms, and twisting two fingers turns it. People standing about face wherever the view is.
- **Title.** "Time to meet someone new" became "Time to make a new friend".
- **The island with the app in the background.** He asked that it "point to that person you
  just met's phone" and that "the big dynamic island in background mode should run for way
  longer". What was done, and what cannot be:
  - The meeting now lasts two minutes on the island (15 seconds before). The panel inside the
    app still lasts 15 seconds, and comes back when the app is opened during the two minutes.
  - iOS closes the big island a few seconds after an announcement and gives apps no way to keep
    it open. The announcement is therefore repeated silently five times, five seconds apart, so
    the big island keeps coming back for about half a minute. Both numbers are Claude's.
  - A paused ranging session does not restart by itself; the app now restarts it when iOS allows
    ranging again and when the app is opened.
  - Direction between two phones comes from the Ultra Wideband chip alone only on older iPhones
    (reports say 11 to 13). Later ones, including Achraf's iPhone 16, need the camera's help,
    and the camera cannot run in the background. So on those phones the island can show how far
    away the person is but not an arrow, until the app is opened. Whether iOS delivers ranging to
    an app in the background at all is barely documented (iOS 18.4 added it for apps with an
    active Live Activity); the app logs whether it happens.

## Pictures in their hands (2026-11-21)

Achraf asked to "make someone hold like their favorite artist or most recent game in their
hand", with a photo of the handheld's plaza for reference, and for the real Spotify and Steam
connections. The idea is done with this app's own characters; nothing is copied from the photo.

- A character holding something stands with both arms forward and a square card between the
  hands (a second set of body meshes, `BodyMesh`), and keeps it there while walking.
- The profile carries a short reference to the picture, not the picture: a Spotify image id
  for an artist, a Steam app number for a game (`Holding` in PassbyCore). Each phone fetches
  the picture itself and keeps it (`HoldingArt`). A reference that is not exactly the right
  shape is dropped, so nothing a stranger's phone sends can make the app fetch from anywhere
  but Spotify's and Steam's image hosts. Older builds ignore the new field.
- Spotify login gives the top artist's picture; Steam gives the most recently played game.
  Both need keys only Achraf can create (see the README), so they are untested. Without them:
  a game typed by hand gets its cover from the Steam shop's public search when the name matches
  exactly, and an artist typed by hand gets a plain card.
- Claude's calls: the favourite artist is held if there is one, otherwise the game; the last
  thing linked replaces it; the character sheet has a row to switch or hold nothing; people who
  set up in an earlier build get a card for what they had already listed.

