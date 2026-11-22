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

## The island stays quiet between meetings (2026-11-21)

Achraf, after hearing what the island does when nobody is being announced: "the always-on
indicator is unnecessary", then "let's ditch all passive stuff on the island including the
indicator". This replaces the green outline for people waiting that was decided at the start.

- Gone: the grey dot and "Looking for people nearby", the green dot, count and outline for
  people not met yet, and the green outline the app drew around the island inside the app.
  People waiting are still shown in the plaza itself (the line above "Meet them").
- Kept: everything during a meeting, as before.
- The Live Activity keeps running with nothing in it. iOS only lets an app start one while it
  is on screen, so without it a pass that arrives with the phone in a pocket could not put
  anything on the island. Dropping it altogether (a plain notification instead) and starting
  it by server push were the other two ways; he picked this one.
- What iOS still shows for an empty activity, which an app cannot remove: a row on the Lock
  Screen (one small line, "People you pass show up here"), and the same line if the island is
  pressed and held.
- Seen in the simulator (iPhone 17 Pro, iOS 26.5): with the empty activity the island is a plain
  black pill about 10 points wider than the bare one (135 against 125), and that is with the
  room for content either side of the camera set to nothing; iOS does not go lower. After the
  two minutes of a meeting the island goes back to nothing by itself, 20 to 40 seconds late
  when the app is asleep, because iOS applies the end time when it gets round to it.
- Not dealt with: iOS takes any Live Activity off the island after eight hours and the app can
  only start it again when it is next opened, so a pass after that is recorded but not announced.

## The Spotify and Steam keys arrived (2026-11-21, build 5)

Achraf sent a Spotify client ID and a Steam Web API key. They are in
`App/Passby/Resources/Secrets.plist`, which git ignores and which ships inside the build.

- Steam, checked end to end in the simulator with a public profile: the three most played
  games fill in and the character holds the cover of the game played last.
- Spotify, checked as far as it goes without logging in to someone's account: Spotify knows
  the client ID, the developer dashboard lists the redirect `passby://spotify`, Spotify shows
  its "allow" page for the app (called "Passerby" there), and the button in the app opens
  Spotify's login page. What happens after a real login has not been run.
- The Spotify app is in development mode with nobody on its list of allowed accounts (the
  limit is five, and the owner needs Premium). Spotify lets anyone log in and then answers
  403 for accounts that are not listed. The app used to call every failure "Spotify didn't
  answer"; it now says that only a few listed accounts can log in, says so separately when
  an account has no top artists yet, and writes the status and Spotify's own reason to the
  diagnostics log. Reading the answer moved into `SpotifyReply` in PassbyCore, with tests.



## Staying logged in to Spotify, ten artists, and holding what you share (2026-11-21, build 6)

Achraf asked for three things: "the user stays logged in and every time they open the app it
updates the top artists list", "expand it up to top 10 artists not just 3", and "if the users
have something in common, eg a game or an artist, that the character holds the cover of the
thing they have in common such as an album cover".

What was built, and the choices that were mine:

- **Staying logged in.** Spotify's login gives a token to ask again with. It is kept in the
  Keychain (this phone only) and swapped for the new one Spotify sends each time it is used.
  Each time the app comes to the front the top artists are fetched again, at most once a
  minute. If Spotify stops accepting the login the app forgets it and keeps the last list;
  logging in again is in Settings. A login is only kept once Spotify has answered for the
  account, and a login left over from an earlier install is dropped at a fresh start.
- **Logged in, the list is Spotify's.** There is nothing to type: the Spotify screen shows the
  ten names and "Log out of Spotify". Logged out, the three fields are back. People who never
  log in still type three.
- **Ten artists.** A profile carries up to ten artists and still three games (he asked for ten
  artists only). Everything still travels in one Bluetooth value of 512 bytes, so when ten
  long names do not fit, the ones furthest down the list are left out first, never fewer than
  three before anything else is cut. Older builds read the first three.
- **Album covers.** The picture for an artist is the cover of the album their most played song
  is on, taken from the person's top songs, with the artist's photo as the fallback. This is
  my reading of "such as an album cover".
- **In common.** Names are compared without regard to capitals, accents, punctuation or
  spacing. With several things in common the one highest up both lists wins, an artist before
  a game when level. On your phone the other person's character holds that, and their card
  says "You both like ...". Your own character keeps what you chose.
- **Where the shared picture comes from.** Pictures are not sent between phones beyond the one
  each person already holds, because ten of them do not fit in the Bluetooth value. The phone
  uses, in order: the other person's own picture if the shared thing is what they hold, the
  picture this phone has for it (every artist from your own Spotify login, your own game
  covers), and for a game the Steam shop's search by name. Otherwise it is a plain card with
  the name. So someone who typed their artists by hand sees a plain card for a shared artist
  unless it is the other person's favourite.

Checked in the simulator: ten artists on the Spotify screen and on a card, people holding the
shared album or game cover with pictures fetched from Spotify and Steam, logging out, and a
made-up login being turned down by Spotify and forgotten. Not checked, because it needs a real
Spotify login: logging in, the list coming back with covers, and the fetch on opening the app
succeeding.

## No arrow, though distance works (2026-11-21, build 7)

Achraf reported no direction arrow on the island, then none in the app either, "though distance
works".

- On the island there cannot be one. Apple's documentation for `sessionWasSuspended` says iOS
  suspends ranging between two phones when the app goes to the background, and the island only
  shows then. This corrects the earlier note that the island could show distance in the
  background: it gets neither, and shows the waving figure.
- In the app, iPhone 14 and later only get a direction with the camera's help, and Apple's
  documentation says the app has to coach the person to move the phone about before it
  settles. The announcement only showed that instruction while there was no distance, and
  distance arrives almost at once, so nobody was ever told. Now the line under the title gives
  the distance and what the phone needs ("Move your phone slowly from side to side"), from
  the first moment and following what iOS says is missing: side to side, up and down, any
  movement, more light, getting closer, or allowing the camera in Settings. The wording is in
  `Bearing.line` in PassbyCore, with tests.
- The diagnostics log now records whether camera access is allowed when ranging starts, and
  what iOS says is missing each time that changes.

Not confirmed on a phone: that moving the phone about is all that was missing. If the arrow
still does not appear, the diagnostics log from that phone says which part fails.

## Forgetting one person (2026-11-21, build 8)

Achraf: "we should be able to forget/remove people individually too (on their profile)".
Every person's card now ends with "Forget <name>". It asks once, then takes that person out of
the plaza: from the list it goes back to the list, in the middle of meeting new people the next
one steps up, otherwise the card closes. An announcement about them ends too. As with "Forget
everyone", nothing is blocked: a phone that is still in range, or passes again later, comes
back as a new person (my choice; he did not say which he wanted).

## A decision instead of a countdown (2026-11-22, build 9)

Achraf: "the dynamic island (fake one) in-app has to be re-made into a real dynamic island
element and the count down shouldn't be a count down but rather a sort of yes no, hit, skip
kinda button with a decision w/ the green border around the big island pulsing".

- The announcement is now a question with two answers, "Skip" and "Meet". The bar that ran
  down fifteen seconds is gone and so is the fifteen seconds: it stays until answered. Left
  alone it ends after two minutes, because the other person has walked on by then. The rules
  are `Meeting` in PassbyCore, with tests.
- "Meet" turns the announcement into the pointing view (arrow, distance, what the phone needs),
  for two minutes from the yes or until "Done". Tapping the person there opens their card.
  "Skip" closes it. Either way the person is in the plaza as before.
- The real Dynamic Island has the same two buttons on its big form, and so has the Lock Screen
  row. "Skip" is an App Intent (`SkipMeetingIntent`), which iOS runs inside the app without
  opening it. "Meet" is a link (`passby://meet`) because a yes has to open the app: the phone
  can only work out the way to someone while the app is on screen.
- iOS does not show an app's own Live Activity while that app is on screen, so the real
  island cannot be what you see inside the app. What the app draws there is now made to be the
  same thing: the big island's shape, corner and margins, in the island's own place, opening
  out of the real island and closing back into it, the clock and battery stepping aside as
  they do under the real one, and the same words and buttons (`ChoiceLabel`, shared by both).
- The green edge pulses inside the app while the question is open. On the real island the
  edge is green but steady: iOS draws that edge itself and does not let a Live Activity run a
  repeating animation.

Checked in the simulator: the question stays up well past fifteen seconds; "Meet", "Done" and
"Skip" inside the app; "Skip" and "Meet" on the real island with the app out of sight. Not
checked: the Lock Screen row (the simulator would not lock), and all of it on a real phone.

## Sculpted hair (2026-11-22, build 10)

Achraf wanted the haircuts to look like the Miis': "it doesn't have to be the exact shape, but
the artistic direction has to be similar w/ the angles and stuff", plus "kind of glow the way
mii have". The Mii hairstyles themselves were not copied or used as models; what was taken is
the general direction he described, done with Passby's own shapes:

- Each of the eight haircuts (same names, same order, so existing characters keep theirs) is
  now one solid sculpted shape instead of a dome with boxes and balls: thick, with a hard cut
  edge, hairlines made of straight lines with corners (temples, sideburns, a squared nape, a
  point on the bun's hairline, a jagged fringe on the spikes), creases where it is combed, and
  pointed tips. `HairMesh` builds a shape from two things per angle round the head: how low the
  hair reaches and how far it stands off the head.
- Hair is glossy: a sharper highlight than the rest of the character, a soft band of shine
  round the crown and a paler rim, in a lighter tone of the hair's own colour. The buzz cut
  hardly shines.
- A cap or beanie presses the hair flat on top; the bun loses its knot under one.

Checked by eye in the simulator (`tools/sim.sh hair`, `gallery`, `plaza`, `me`, `card`). The app
icon still shows the old hair; it is a saved picture and was not redrawn.

## A clip for the demo (2026-11-22)

Achraf asked for a short video for the ad or demo: his character appearing, walking into the
plaza to the front and introducing itself, with the card of his interests coming up, and none
of the app's controls on screen.

- The app has a film mode, `-demo film`: no buttons, bars or status bar; a few people in the
  plaza and nobody of yours in the middle; after a moment the person described by the
  `-film...` launch arguments pops into the ring, walks to the front while the view eases in on
  them, and their card opens with no buttons on it.
- `tools/film.py` records it in a simulator without a Dynamic Island, collects the sounds the
  app made (the app keeps the speaker silent and writes them to a file), lays the plaza tune
  under them, and cuts a twelve-second clip with a fade at each end.
- Two things in the plaza itself changed for it and apply to the app too. Someone who turns up
  after the plaza has filled now pops into place. And with nobody of yours in the middle, a
  newcomer can be given a place nearer the viewer and room around them (`soloGreetHeight`,
  `givesArrivalsRoom` on `PlazaScene`, with tests); only the film uses that.

The clip made that night shows only what was known of his profile: his look, his greeting and
one artist. The cover his character holds in it is an album cover by that artist, not the same
one his phone shows, which could not be identified from a screenshot.

He then asked for it in landscape instead of portrait. `tools/film.py --wide` does that: the
app, which is otherwise upright only, turns on its side for a film (`-filmwide`), the plaza
fills the wide picture, the card is a panel in the bottom right, and the newcomer stands a
little left of the middle with more floor kept clear round them (`soloGreetAcross`,
`arrivalRoom` on `PlazaScene`, with tests). The view starts on the crowd and the ring and eases
in about four times closer as they walk up. The recording is turned upright again and cut to the
middle 16:9, 1920 by 1080.

## First-run screens with a console-menu feel (2026-11-22, build 11)

Achraf: "let's now try to work on the onboarding, try to make it look better/ look more like a
wii menu ... since we'll be demoing that". The Wii Menu itself (its channel grid, bottom bar,
logo, sounds) was not copied. What was taken is the general feel of a 2000s console's setup
menu, done as Passby's own design (`Console` in `ConsoleKit.swift`):

- A bright white screen with fine level lines, fading into the plaza's floor lower down.
- The character large in the middle on a lit disc. It gives a little jump when it changes.
- The step named in a glossy pill at the top with a bar per step; one glossy pill at the
  bottom to move on, with a round one beside it to go back.
- A blue glow that breathes on whatever is picked or wants pressing: the main pill, the open
  tab, the tile in use, and the two link tiles until something is linked.
- A welcome first: the name of the app, one line about it, and "Start".
- Making the character is now tabs and tiles (`LookStudio`): a round tab per part, and every
  choice for that part as a tile showing the character with it, instead of seven rows of
  arrows. The "Your character" sheet in the plaza still uses the rows.
- The link screens (`LinkEntry`) are unchanged inside; the app's ordinary buttons and fields
  take the glossy look wherever `\.console` is set in the environment, which is only here.
- Settings has "Start over from the welcome", behind one confirmation, so the first-run
  screens can be shown again at a demo without reinstalling. It removes the character, the
  links and everyone passed.

Checked in the simulator by tapping through from the welcome to the plaza, with the keyboard
up for the name and for a game, and by starting over from Settings. Not checked on a phone.

## "You both like…" opens into a list (2026-11-22, build 12)

Achraf asked for names two people have in common to be green, and for "a common interests
section on profiles with the label 'you both like...'" that shows the list when expanded.

- The green was already there from build 6: on someone's card, the artists and games you also
  list are bold and green in "Listens to" and "Plays". That stays.
- The one-line "You both like Stromae, Angèle and 1 more" is now a section. Closed, it is a
  green row: "You both like…", how many things, and an arrow. Tapped, it opens into the list,
  best match first: each thing with its cover when this phone has one (the plain card with a
  music note or a game pad otherwise), its name in green, and whether it is an artist or a
  game. Past four it scrolls, so a long list cannot push the card off the screen.

Checked in the simulator on the demo card (two artists and a game in common), including the
scrolling case. Not checked on a phone.

## The island's green edge keeps up with it (2026-11-22, build 13)

Achraf noticed that inside the app the green edge opened more slowly than the black island.
Measured frame by frame in the simulator: while the black shape grew from 167 to 481 pixels the
edge stayed at 157 and only caught up about a second later. The edge was a separate layer whose
pulse was an animation of its own, and that animation was also being applied to the edge's
shape. The black shape and the edge are now one view (`IslandBody`), drawn from the same
outline on every frame, with the pulse worked out from the clock rather than animated. After
the change the edge sits 8 to 10 pixels outside the black shape on every frame of the opening.

## Log in with Steam (2026-11-22, build 14)

Achraf: "please do a proper steam log in like for spotify".

- "Log in with Steam" on the Steam link screen opens Steam's own sign-in page in a sheet
  (`SteamSignIn`). Steam's sign-in is the old OpenID kind made for websites: it ends by sending
  the browser to an address of the site's with a signed statement of who signed in. Whether
  Steam would hand back to an app address like `passby://` could not be found out from outside
  (its page checks nothing until someone has signed in), so the app shows the page in its own
  web view, gives Steam an ordinary web address to come back to (`https://passby/steam`, where
  nothing lives), and catches that last move instead of opening it. The bar over the page
  always shows which site is on screen. The app only ever reads that final address.
- The statement is sent back to Steam to confirm it is genuine before it is believed
  (`SteamLogin` in PassbyCore, with tests; Steam answers `is_valid:false` to a made-up one,
  checked against the real service).
- As with Spotify, the login is kept (the Steam ID, in the Keychain) and the three most-played
  games, and the one played last for the card, are read again each time the app opens
  (`PlazaState.setTopGames`, tested). Logged in, the Steam screen shows the list and "Log out
  of Steam"; Settings marks the row "Logged in".
- Signing in does not give access to private data: games are still read with the Steam Web API
  key, so a person's game details must be public. When they are not, the login is not kept and
  the app says where in Steam to change it.
- Looking a profile up by link or name, and typing three games, both still work.

Checked in the simulator: the sheet opens Steam's real page and Cancel comes back; with a
public profile's ID planted as if logged in (`-steamid`, debug builds only), the games arrive
when the app opens, the logged-in screen lists them and logging out returns to the entry
screen. Not checked, because it needs a real Steam account: the sign-in itself, Steam handing
back to `https://passby/steam`, and the confirmation of a genuine sign-in.
