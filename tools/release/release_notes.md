**This is a tech demo of game mechanics, not the game.** It shows the systems
as they get built, and this release is updated in place as they're polished.
The story, the realms and the real content come later.

## New in this update

* **A start menu**: pick the prologue, the street, the test yard or the
  combat arena, the start time and Normal or Hard. Reaching the gate in the
  prologue brings you back to it
* **Walk between maps**: the prologue street's road leads to the test yard,
  and the yard to the combat arena. Health, charge and items come along
* **A running clock**: morning, day, evening and night pass on their own in
  the test yard and the combat arena, with a fade between them and music for each (F7 stops it,
  F9 speeds it up, F2 skips ahead). Story scenes can hold the clock
* **Two shops**: the corner store closes at night, the all-night stand
  doesn't. Real 3D stalls with striped awnings, goods and a lantern
* **Night changes things**: the kid misses more outside his flashlight
  beam; the dog smells enemies (they glow while you drive him); in the combat
  arena rats go home at dusk and bats drop out of the oaks, circle, and
  swoop to bite
* **The dog leaps and bites**, like the original, and points out hidden
  items by himself whenever it's calm
* **Smoother movement**: steadier turning, 10% faster walking and running,
  and the club no longer loses its tip mid-swing
* **Opens borderless fullscreen** at your screen's resolution (Settings has
  windowed sizes)

## What's in it

* **The HD-2D look**: pixel-art sprites in a lit 3D world, with sun shadows,
  light shafts, tilt-shift blur, a reflective pond and cloud shadows. Pixel
  perfect from a Steam Deck to a 32:9 ultrawide
* **The dog**: follows the kid's trail, stays when told to
* **Talking**: the prologue's opening (dinner with Dad, the dare at the
  Ruffleberg place), with a text box that fits its text and portraits
* **A big combat arena**: 100 x 56 tiles of fields, oak groves, ponds, roads
  and fenced lanes, far more than a wide screen shows. Enemies sleep far off
  and wake as you walk up. The test yard has no enemies any more
* **Combat**: a weapon swing with an **auto-filling charge meter** (no
  holding a button: wait and it climbs to x2 and x4), giant rats that wake
  as you get close, warn before they bite, stagger, and give up if you run
  far enough. Hit-stop, damage numbers, knockouts and revives
* **The duo**: switch between the kid and the dog any time (the camera
  glides over), leave the other on **Stay put** (it survives a switch, so the
  two can split up), and set how the AI plays the one you aren't driving: the
  kid Offensive or Defensive, the dog Offensive or Search. The dog bites. An
  arrow points to him when he's out of view
* **The ring menu** (I / Y): Equipment (kid: weapon, head, body, arms,
  hands, legs, boots; dog: collar), Items, Alchemy (Heal, which costs a wild
  carrot and gets stronger the more you cast it) and Party (stances, Stay
  put). Every ring is a tab you can see, and changes take effect right away
* **Quick slots** (1-4 / D-pad): use an item or cast a formula without
  opening the menu
* **Walking and running**: hold Run to run. Like the original, running
  costs your attack charge; run it to 0% and you're winded for a moment
* **Hidden items and the dog's nose** (in the test yard): items buried,
  tucked under bushes and rocks, or lying in nooks. The dog finds them by
  himself when it's calm (farther on Search), points, barks and digs; drive him and sniff to see scent
  trails. A count of how many you've found is in the pause menu
* **A real HUD**: a card for each of the duo with a health bar (a pale
  ghost shows what the last hit took), the charge bar, the partner's stance,
  and a KO countdown
* **Normal and Hard**: the Hard launcher makes the rats tougher
* **Sound and music**: swings, hits, the rat's warning squeak before it
  bites (listen for it), the dog's barks and bites, footsteps that change on
  the dirt road, menu ticks, a text blip, music for each place, and birds by
  day and crickets at night that follow the time of day
* **A pause menu with settings** (Esc / Start): rebind every key and button,
  graphics quality presets and each effect on its own, brightness, window
  mode, V-Sync, frame cap, volumes, text speed, screen shake, damage numbers,
  hold or toggle to run

## Downloads

* **Windows**: `Evermore2-tech-demo-windows.zip`. Unzip, run `Evermore2.exe`
  for the start menu, or `Test yard.bat` / `Combat arena.bat` to jump in. The exe isn't signed,
  so Windows may warn you: **More info**, then **Run anyway**
* **Linux**: `Evermore2-tech-demo-linux.tar.gz`. Run `./Evermore2.x86_64`,
  `./test-yard.sh` or `./combat-arena.sh`

Needs a graphics card with Vulkan or Direct3D 12. The README.txt inside has
the controls.

Bugs: [open an issue](https://github.com/Er2oneousbit/evermore2/issues).

*Secret of Evermore is © Square Enix. This is a non-commercial fan project,
not affiliated with or endorsed by Square Enix. It contains no material from
the original game.*
