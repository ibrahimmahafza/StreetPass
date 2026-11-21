# Passby

Walk past someone who also has the app and your phones swap a small profile over
Bluetooth. Next time you open the app, they are waiting in your plaza to say hello,
and the outline of the Dynamic Island glows green until you meet them.

Built for a hackathon with the theme "undo": bringing back the passing-by experience
of early-2010s handhelds. The characters, plaza, sounds and music are original to this
app; nothing here comes from the games that inspired it.

## What is in it

- Onboarding in four steps: name, character, Instagram, Spotify or Steam.
- A full-screen 3D checkerboard plaza where everyone you have passed walks around.
- Three round buttons at the top: your character, people you passed, settings.
- "Meet them": new people walk up one at a time with a card showing their name,
  Instagram, three artists, three games and how often you have passed.
- A Live Activity that shows a green dot and count in the Dynamic Island, plus a green
  outline drawn around the island inside the app.
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

## Demo script

1. Two phones with the app installed, both through onboarding, Bluetooth on.
2. Open the app on both and bring them near each other. Within a few seconds each
   plays the arrival jingle and its island outline turns green.
3. Press "Meet them" on either phone.
4. To show the island outside the app, pass someone, then go to the home screen.

If Bluetooth misbehaves on stage, Settings, "Simulate a pass" does the same thing
with a made-up person.

Two phones that stay near each other count as one pass. Someone counts again only
after ten minutes out of range. If you rehearsed with the same phones, press
Settings, "Forget everyone" on both before going on, or they will not pass again.

## Spotify and Steam logins (optional)

Without keys, people type their three artists and three games. To enable the logins,
copy `App/Secrets.example.plist` to `App/Passby/Resources/Secrets.plist` and fill in:

- `SpotifyClientID`: from an app in the Spotify developer dashboard, with the redirect
  URI `passby://spotify`. While that app is in development mode, only the few Spotify
  accounts you add to it can log in (five at the time of writing, and the app owner
  needs Premium), so judges will end up typing.
- `SteamAPIKey`: from steamcommunity.com/dev/apikey. The person's Steam profile and
  game details must be public.

`Secrets.plist` is ignored by git but ships inside the app, so do not hand a build with
your Steam key to strangers. The tools pick the file up by themselves; if you build from
Xcode, run `xcodegen` once after adding it.

## Layout

```
PassbyCore/     logic with unit tests: profile format, pass rules, storage, Steam link parsing
App/Passby/     the app: Draw/ (characters, plaza), UI/, Services/ (Bluetooth, audio, logins)
App/PassbyLive/ the Live Activity
tools/          sim.sh, install.sh, make_music.py
docs/           the design, the plan and the approved mockup
```

The characters are 3D models built in code: a smooth egg-shaped head with a pencil-sketched
face, on a body that is one continuous surface. The head, hair and face are in
`App/Passby/Draw/Character3D.swift`; the body's shape is in `App/Passby/Draw/BodyMesh.swift`.
To change the tune, edit `tools/make_music.py` and run it.

Tests: `swift test --package-path PassbyCore`
