# Passby

Walk past someone who also has the app and your phones swap a small profile over
Bluetooth. The Dynamic Island opens to say "Time to make a new friend", and next time
you open the app they are waiting in your plaza to say hello.

Built for a hackathon with the theme "undo": bringing back the passing-by experience
of early-2010s handhelds. The characters, plaza, sounds and music are original to this
app; nothing here comes from the games that inspired it.

## What is in it

- Onboarding with the feel of a 2000s console's setup menu: a welcome, then name, character
  (tabs and tiles), Instagram, Spotify or Steam. Settings > "Start over from the welcome"
  shows it again for a demo.
- A full-screen 3D checkerboard plaza. Your own character stands in the middle and everyone
  you have passed walks around you.
- Three round buttons at the top: your character, people you passed, settings.
- A bar along the bottom with your numbers: people, passes, and whether passing is on.
- People in the plaza are solid and nobody is ever pushed: someone standing stays put, someone
  walking goes round whoever is in the way, turns before stepping and only steps forwards.
- The plaza moves like a map: drag to slide it, pinch to zoom, twist two fingers to turn it.
- Characters hold up a small square picture: an album cover for their favourite artist (from a
  Spotify login) or the cover of the game they played most recently (from Steam). Typed-in games
  get their cover looked up by name; anything without a picture gets a plain card with a music
  note or a game pad. You choose which to hold, or nothing, on your character sheet.
- When someone you passed lists an artist or a game that you list too, their character holds
  that instead on your phone, and their card says "You both like ..." with the shared names in
  green. Your own character keeps holding what you chose.
- A Spotify login stays logged in. Each time the app is opened it fetches your top ten artists
  again, so the list and the card in your hands keep up with what you listen to.
- "Meet them": new people walk up one at a time with a card showing their name,
  Instagram, up to ten artists, three games and how often you have passed.
- Each person's card has "Forget" at the bottom, which takes just that person out of your
  plaza after asking once. If you pass them again they are new again.
- The Dynamic Island is left alone until someone is detected: no dot, no count, no outline.
  A Live Activity still runs the whole time, because iOS will not let an app start one from
  the background, but between meetings it draws nothing on the island and is one small line
  on the Lock Screen.
- When two phones detect each other, "Time to make a new friend" comes up and asks: "Skip"
  or "Meet". Nothing counts down. With the app out of sight the question is on the real
  Dynamic Island (and the Lock Screen): "Skip" closes it without opening the app, "Meet"
  opens the app. The big island is brought back every five seconds for the first half minute
  (iOS closes it by itself and an app cannot hold it open). Inside the app, where iOS hides
  an app's own island, the app draws the same big island in the same place, opening out of
  the real one, with its green edge pulsing while it asks. After "Meet" it points the way,
  with an arrow that turns towards the other person on phones that can tell, until "Done".
  Left unanswered, the question ends by itself after two minutes.
- Synthesised sounds, a babble voice and a looping background tune.

iPhone only, iOS 17 or later. No server and no accounts.

## Run it in the simulator

```
brew install xcodegen          # once
tools/sim.sh waiting           # builds, launches, saves build/shots/waiting.png
```

Demo screens: `plaza`, `waiting`, `card`, `me`, `people`, `settings`, `onboarding`,
`gallery`, `icon`. The script launches muted; run the app from Xcode to hear it. The 3D
view takes a few seconds to warm up in the simulator; use `WAIT=6` for `card`.

The simulator has no Bluetooth. Use Settings, "Simulate a pass".

## Put it on a phone

Plug in an unlocked iPhone, then:

```
tools/install.sh
```

The first run registers the bundle IDs `com.passbyplaza.app` and
`com.passbyplaza.app.live` with the developer team set in `project.yml`
(`DEVELOPMENT_TEAM`). Change the team or the IDs there if you need to.

## TestFlight

```
tools/testflight.sh
```

builds a signed release and uploads it. The app is listed in App Store Connect as
"Passby Plaza" ("Passby" was taken as a store name; the name under the icon is still
Passby). Every upload goes automatically to the internal testing group "Team"; testers
install it from the TestFlight app. Internal testers have to be members of the App Store
Connect team first (Users and Access), then added to the group.

## When a test on a real phone goes wrong

The app keeps a running record of what Bluetooth, ranging and the island did.

- On the phone: Settings, Diagnostics. "Share" sends the text anywhere.
- Over the cable: `tools/logs.sh` copies the record off the phone and prints the end of it.
- Live: `tools/watch.sh` launches the app on the phone and prints each line as it happens.

## Demo script

1. Two phones with the app installed, both through onboarding, Bluetooth on.
2. Open the app on both and bring them near each other. Within a few seconds each
   plays the arrival jingle and shows "Time to make a new friend".
3. Press "Meet them" on either phone.
4. To show the island outside the app, pass someone, then go to the home screen.

If Bluetooth misbehaves on stage, Settings, "Simulate a pass" does the same thing
with a made-up person.

The arrow comes from the Ultra Wideband chip (Apple's Nearby Interaction), not from
Bluetooth, which cannot tell direction. It needs the app open on both phones, and the
first time it asks for permission to find nearby devices, and on some iPhones for the
camera, which it uses to work out direction. Do one pass before the demo to get those
prompts out of the way. Without a direction the announcement still appears, with the
distance or just "close by".

Two phones that stay near each other count as one pass. Someone counts again only
after ten minutes out of range. If you rehearsed with the same phones, press
Settings, "Forget everyone" on both before going on, or they will not pass again.

## Spotify and Steam logins (optional)

Each link screen is either a login that fills the list in by itself or three boxes to type
in, never both at once; a small button switches. Without keys there are only the boxes. To
enable the logins,
copy `App/Secrets.example.plist` to `App/Passby/Resources/Secrets.plist` and fill in:

- `SpotifyClientID`: from an app in the Spotify developer dashboard, with the redirect
  URI `passby://spotify`. While that app is in development mode, only the few Spotify
  accounts you add to it can log in (five at the time of writing, and the app owner
  needs Premium), so judges will end up typing. Anyone else gets as far as Spotify's
  login page, then Spotify refuses to answer for them and the app says "Spotify only
  lets a few listed accounts log in to Passby for now. Type them instead."
- `SteamAPIKey`: from steamcommunity.com/dev/apikey. The person's Steam profile and
  game details must be public.

"Log in with Steam" opens Steam's own sign-in page in a sheet. Steam's sign-in only says
who someone is, so their games are still read with the key above, and still only if their
game details are public; the app says how to change that when they are not. The login is
kept in the Keychain and the three most-played games are read again each time the app is
opened, until the person logs out in Settings. Looking a profile up by its link or name
still works without logging in.

A Spotify login gives the top ten artists of roughly the last six months, each with the
cover of the album the person's most played song by that artist is on (or the artist's
photo when there is no such song). The login is kept in the Keychain, so the list is
fetched again each time the app is opened until the person logs out in Settings. People
who type instead still list three.

`Secrets.plist` is ignored by git but ships inside the app, so do not hand a build with
your Steam key to strangers. The tools pick the file up by themselves; if you build from
Xcode, run `xcodegen` once after adding it.

## Layout

```
PassbyCore/     logic with unit tests: profile format, pass rules, storage, Steam link parsing,
                and the plaza itself (who stands and walks where: PlazaScene, Crowd, PlazaCamera)
App/Passby/     the app: Draw/ (characters, plaza), UI/, Services/ (Bluetooth, audio, logins)
App/PassbyLive/ the Live Activity
tools/          sim.sh, install.sh, testflight.sh, logs.sh, watch.sh, make_music.py
docs/           the design, the plan and the approved mockup
```

The characters are 3D models built in code: a smooth egg-shaped head with a pencil-sketched
face, on a body that is one continuous surface. The head and face are in
`App/Passby/Draw/Character3D.swift`; the body's shape is in `App/Passby/Draw/BodyMesh.swift`.
Each haircut is one sculpted, glossy shape described by a few numbers in
`App/Passby/Draw/HairMesh.swift`; `tools/sim.sh hair` shows all eight from three sides.

`tools/film.py out.mp4 --name ... --look ... --artists ...` records a twelve-second clip for a
demo: a quiet plaza with no controls on screen, one person appears, walks to the front and
says hello, and their card comes up. It runs the app's film mode (`-demo film`) in a simulator,
adds the app's own sounds and tune, and needs ffmpeg. `--seed` repeats a take that came out well.
`--wide` makes it landscape, 1920 by 1080: the app turns on its side for the film, the card
becomes a panel beside the person, and the view starts wide and closes in further.
To change the tune, edit `tools/make_music.py` and run it.

Tests: `swift test --package-path PassbyCore`
