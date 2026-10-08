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
  Evermore2.exe              The prologue: dinner with Dad, then the dare
                             at the Ruffleberg place
  Combat arena.bat           The combat arena: five giant rats
  Combat arena (Hard).bat    The same on Hard
  Test yard.bat              The test yard: press F2 for day, golden hour
                             and night

  The game isn't code-signed, so Windows may say "Windows protected your
  PC". Click "More info", then "Run anyway".

Linux
  ./Evermore2.x86_64         The prologue
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
Move                  WASD / arrows       Left stick / D-pad
Run (hold)            Shift               LB
Attack                J / Space           A
Talk / interact       E / Enter           A
Ring menu             I                   Y
Phone flashlight      F                   L3 (click left stick)
Switch kid / dog      Tab                 Back (View)
Partner: Stay put     Q                   X
  (press again to call him back)
Partner's stance      R                   RB
Sniff (the dog)       C                   B
Time of day           F2
Debug overlay         F3
Classic 2D view       F6

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
  The dog:  Offensive (bites enemies near you) or Search (keeps out of
            fights, sniffs out hidden items, bites back if something's
            after him)

The ring menu (I / Y) pauses and shows the gear of whoever you drive:
left/right picks a slot, up/down changes what's in it, Tab shows the other
one's gear. The test yard and the arena give you a kit of gear to try.

Hidden items: the test yard hides five. The dog on Search finds buried
ones and digs them up; drive him and press Sniff to see scent trails, then
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
