Secret of Evermore 2: Return to Evermore
TECH DEMO: game mechanics
========================================

This is NOT the game yet. It's a tech demo of the mechanics as they get
built: the HD-2D look, the dog, talking to people, and combat. It gets
updated as the mechanics are polished. The story, the realms and the
real content come later.

A non-commercial fan project. Secret of Evermore is (c) Square Enix; this
is not affiliated with or endorsed by Square Enix and contains no material
from the original game.


HOW TO START
------------
Windows
  Evermore2.exe              Opens the title screen. New Game: boy or girl,
                             name the kid and the dog, then the prologue.
                             Debug is on its menu: pick the prologue, the
                             street, the test yard or the combat arena, the
                             start time and Normal/Hard
  Combat arena.bat           The combat arena: a big countryside (100 x 56
                             tiles): giant rats by day, skeletons and bats
                             by night
  Combat arena (Hard).bat    The same on Hard
  Test yard.bat              The test yard: shops, hidden items and a
                             clock that runs (no enemies here)

  The game isn't code-signed, so Windows may say "Windows protected your
  PC". Click "More info", then "Run anyway".

Linux
  ./Evermore2.x86_64         The start menu
  ./combat-arena.sh          The combat arena (add --hard for Hard)
  ./test-yard.sh             The test yard

  If it won't start: chmod +x Evermore2.x86_64 *.sh

It needs a graphics card with Vulkan or Direct3D 12. On an older computer,
start it with:  Evermore2.exe --rendering-method gl_compatibility
(it still runs, without the light shafts, reflections and blur).


CONTROLS
--------
                      Keyboard            Gamepad
Pause menu/settings   Esc                 Start
Move                  WASD / arrows       Left stick
Run (hold)            Shift               LB
Attack                J / Space           A
Talk / interact       E / Enter           A
Ring menu             I                   Y
Quick slots           1 2 3 4             D-pad
Phone flashlight      F                   L3 (click left stick)
Switch kid / dog      Tab                 Back (View)
Partner: Stay put     Q                   X
  (press again to call him back)
Partner's stance      R                   RB
Sniff (the dog)       C                   B
Next time of day      F2
Debug overlay         F3
Classic 2D view       F6
Stop/start the clock  F7
Clock speed x1/10/60  F9

Every control except pause can be rebound: Esc > Settings > Controls.
Settings also has graphics (quality presets, each effect, brightness),
display (window mode, V-Sync, frame cap), volume and gameplay options.

Running: you walk unless you hold Run. Running costs your attack: the
charge meter drains instead of filling. Run it to 0% and you're winded
(the bar blinks orange) until it refills halfway. The dog runs on a
quarter of the cost.

Attacking: you never hold a button. After a swing the charge meter under
the kid's health refills by itself; wait longer and it climbs to x2 and
x4 damage. Swinging early still hits, for less.

Talking wins over attacking when someone is in reach.

The duo: you drive one, the AI plays the other by his stance.
  The kid:  Offensive (goes after enemies near you) or Defensive (stays
            close, swings only at what comes within reach, at full power)
  The dog:  Offensive (leaps at and bites enemies near you) or Search
            (keeps out of fights and hunts for hidden items). On either,
            when nothing's after you, he points out hidden items nearby

The ring menu (I / Y) pauses and shows four rings (Z/X or LB/RB to switch):
Equipment (up/down changes a slot), Items and Alchemy (E / A uses or casts
on whoever is shown), Party (stances, Stay put). Tab shows the other one.
Select an item or formula and press 1-4 / the D-pad to put it in a quick
slot; outside the menu the same key uses it. The quick slots sit at the
bottom centre; the sky dial at the top centre shows the time of day. The test yard and the arena
give you gear, apples, a soda, wild carrots and the Heal formula to try.

Hidden items: the test yard hides five. The dog finds buried ones and
digs them up when it's calm (on Search he looks farther); drive him and press Sniff to see scent trails, then
Talk / interact on the spot to dig. Look for a glint on bushes and rocks:
the kid can search those. Esc shows how many you've found.
Stay put leaves the partner where he is, even through a switch: leave the
kid on one side, switch to the dog, explore. An arrow at the screen edge
points to him when he's out of view (red while he's being hit).


FEEDBACK AND BUGS
-----------------
https://github.com/Er2oneousbit/evermore2/issues

Credits for every artist and license: CREDITS.md (in this folder).
Code: MIT License (LICENSE). Art keeps its own licenses (see CREDITS.md).

Made with love from your friendly hacker - er2oneousbit

Walking between maps: the street's road (east) leads to the test yard, and
the yard's shop street (north) to the combat arena. Your health, charge and
items come with you.

Day and night: in the test yard and the combat arena a day lasts 24 minutes
(F9 speeds it up). The corner store closes at night; the all-night stand
doesn't. At night the kid misses more outside his flashlight beam, the dog
smells enemies (they glow while you drive him), and in the arena rats go
home while skeletons rise out of the ground and bats fly out of the oaks.
Watch for a bat's squeak and dip before it dives: step aside.
