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
Move                  WASD / arrows       Left stick / D-pad
Attack                J / Space           A
Talk / interact       E / Enter           A
Phone flashlight      F                   Y
Dog: stay / follow    Q                   X
Time of day           F2
Debug overlay         F3
Classic 2D view       F6

Attacking: you never hold a button. After a swing the charge meter under
the kid's health refills by itself; wait longer and it climbs to x2 and
x4 damage. Swinging early still hits, for less.

Talking wins over attacking when someone is in reach.


FEEDBACK AND BUGS
-----------------
https://github.com/Er2oneousbit/evermore2/issues

Credits for every artist and license: CREDITS.md (in this folder).
Code: MIT License (LICENSE). Art keeps its own licenses (see CREDITS.md).

Made with love from your friendly hacker - er2oneousbit
