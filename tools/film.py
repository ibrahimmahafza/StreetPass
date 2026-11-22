#!/usr/bin/env python3
"""Record a clip of the plaza with no controls on screen: someone appears, walks up and says hello.

usage: tools/film.py out.mp4 --name Achraf --look 2,4,0,3,2,4,0 [--artists "A, B"] [--games "X, Y"] [--holds "A"]
                     [--insta handle] [--greeting "Hi!"] [--picture <Spotify picture id>] [--seed 3] [--wide]

--look is skin, hair, hair colour, eyes, mouth, hoodie, extra, each counted from 0 (the app's
character screen counts from 1). The person holds up their first artist, or whoever --holds
names (who is then not listed on the card); --picture is the cover, without which it is a plain
card with the name.

It runs the app's film mode (`-demo film`) in a simulator without a Dynamic Island, records the
screen, collects the sounds the app made (the app keeps the speaker silent and writes them to a
file), lays the plaza tune under them and cuts the clip. Build first: tools/sim.sh plaza.
Needs ffmpeg.
"""
import argparse
import os
import signal
import subprocess
import sys
import time

BUNDLE = "com.passbyplaza.app"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRODUCT = os.path.expanduser("~/Library/Developer/Xcode/DerivedData/Passby-cli/Build/Products/Debug-iphonesimulator/Passby.app")
TUNE = os.path.join(ROOT, "App/Passby/Resources/theme.wav")

# The clip starts this long after the app's film does, and runs this long. The app's own timings
# are in PlazaView.film().
LEAD, LENGTH = 1.4, 12.0


def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True).stdout.strip()


def simulator():
    """The newest simulator of an iPhone without a Dynamic Island, so nothing black sits at the top."""
    best = None
    for line in run("xcrun", "simctl", "list", "devices", "available").splitlines():
        if "iPhone 17e (" in line or "iPhone 16e (" in line:
            best = line.split("(")[1].split(")")[0]
    if not best:
        sys.exit("No iPhone 17e or 16e simulator found.")
    return best


def read_number(path):
    with open(path) as f:
        return float(f.read().strip())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("out")
    p.add_argument("--name", default="Sam")
    p.add_argument("--look", default="1,1,0,0,0,5,0")
    p.add_argument("--artists", default="")
    p.add_argument("--games", default="")
    p.add_argument("--insta", default="")
    p.add_argument("--greeting", default=None)
    p.add_argument("--holds", default=None, help="the artist whose cover they hold up, when it should not be listed on the card")
    p.add_argument("--picture", default=None)
    p.add_argument("--wide", action="store_true", help="landscape, 1920x1080, instead of the phone's upright picture")
    p.add_argument("--zoom", default=None)
    p.add_argument("--seed", default=None, help="a number; the same one makes the crowd move much the same way again")
    p.add_argument("--sim", default=None)
    p.add_argument("--keep", action="store_true", help="keep the raw recording next to the clip")
    a = p.parse_args()

    sim = a.sim or simulator()
    out = os.path.abspath(a.out)
    raw = out + ".raw.mp4"
    subprocess.run(["xcrun", "simctl", "boot", sim], capture_output=True)
    run("xcrun", "simctl", "bootstatus", sim, "-b")
    subprocess.run(["xcrun", "simctl", "terminate", sim, BUNDLE], capture_output=True)
    run("xcrun", "simctl", "install", sim, PRODUCT)
    folder = os.path.join(run("xcrun", "simctl", "get_app_container", sim, BUNDLE, "data"), "Library/Application Support/Passby")
    for name in ("film-start.txt", "film-sound.txt", "film-end.txt", "film.caf"):
        try:
            os.remove(os.path.join(folder, name))
        except FileNotFoundError:
            pass

    recorder = subprocess.Popen(
        ["xcrun", "simctl", "io", sim, "recordVideo", "--codec", "h264", "--force", raw],
        stderr=subprocess.PIPE, text=True)
    for line in recorder.stderr:
        if "Recording started" in line:
            break
    recording_began = time.time()

    launch = ["xcrun", "simctl", "launch", "--terminate-running-process", sim, BUNDLE,
              "-reset", "-demo", "film", "-zoom", a.zoom or ("1.8" if a.wide else "1.2"), "-filmname", a.name, "-filmlook", a.look,
              "-filmartists", a.artists, "-filmgames", a.games, "-filminsta", a.insta]
    if a.greeting:
        launch += ["-filmgreeting", a.greeting]
    if a.holds:
        launch += ["-filmholds", a.holds]
    if a.picture:
        launch += ["-filmpicture", a.picture]
    if a.seed:
        launch += ["-filmseed", a.seed]
    if a.wide:
        launch += ["-filmwide"]
    # Straight after an install the simulator sometimes starts the app without its arguments, so
    # launch until the film is seen to have started.
    for attempt in range(4):
        run(*launch)
        waited = time.time() + 15
        while not os.path.exists(os.path.join(folder, "film-start.txt")) and time.time() < waited:
            time.sleep(0.2)
        if os.path.exists(os.path.join(folder, "film-start.txt")):
            break
    else:
        recorder.send_signal(signal.SIGINT)
        sys.exit("The app never started its film. Was it built with the film mode? Run tools/sim.sh plaza first.")

    deadline = time.time() + 60
    while not os.path.exists(os.path.join(folder, "film-end.txt")):
        if time.time() > deadline:
            recorder.send_signal(signal.SIGINT)
            sys.exit("The app started its film but never finished it.")
        time.sleep(0.2)
    time.sleep(0.6)
    recorder.send_signal(signal.SIGINT)
    recorder.wait()
    subprocess.run(["xcrun", "simctl", "terminate", sim, BUNDLE], capture_output=True)

    film_began = read_number(os.path.join(folder, "film-start.txt"))
    picture_from = film_began + LEAD - recording_began
    sound = os.path.join(folder, "film.caf")
    inputs = ["-ss", f"{picture_from:.3f}", "-i", raw]
    # On its side the app draws sideways on the upright screen: turn the picture, then keep the
    # middle 16:9 of it, which is what the app laid its card out for.
    shape = "transpose=2,crop=ih*16/9:ih,scale=1920:1080:flags=lanczos," if a.wide else ""
    fade = f"fade=t=in:st=0:d=0.5:color=white,fade=t=out:st={LENGTH - 0.6}:d=0.6:color=white"
    bed = f"volume=0.4,afade=t=in:st=0:d=0.8,afade=t=out:st={LENGTH - 1.0}:d=1.0"
    if os.path.exists(sound) and os.path.exists(os.path.join(folder, "film-sound.txt")):
        sound_from = film_began + LEAD - read_number(os.path.join(folder, "film-sound.txt"))
        # The sound file normally begins before the clip does; if not, hold it back instead.
        if sound_from >= 0:
            inputs += ["-ss", f"{sound_from:.3f}", "-i", sound]
            effects = "[1:a]anull[fx]"
        else:
            inputs += ["-i", sound]
            effects = f"[1:a]adelay={int(-sound_from * 1000)}:all=1[fx]"
        inputs += ["-stream_loop", "-1", "-i", TUNE]
        graph = f"[0:v]fps=60,{shape}{fade}[v];{effects};[2:a]{bed}[bed];[fx][bed]amix=inputs=2:duration=longest:normalize=0[a]"
    else:
        print("No sound was recorded; the clip gets the tune only.")
        inputs += ["-stream_loop", "-1", "-i", TUNE]
        graph = f"[0:v]fps=60,{shape}{fade}[v];[1:a]{bed}[a]"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
         "-t", str(LENGTH), "-c:v", "libx264", "-crf", "17", "-preset", "slow", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], check=True)
    if not a.keep:
        os.remove(raw)
    print(out)


if __name__ == "__main__":
    main()
