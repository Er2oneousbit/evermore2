# =============================================================================
# enemy_data.gd  -  One kind of enemy (a .tres in data/enemies/)
# -----------------------------------------------------------------------------
# WHAT:  The sprite layout, the stats (before difficulty: Difficulty scales
#        HP, armor and damage on Hard) and the attack's timing. Enemy (the
#        actor) reads one of these; a new enemy is a new .tres, not new code.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name EnemyData
extends Resource

@export var name_key := ""

@export_group("Sprite")
## A 4-direction sheet: rows down, left, right, up (LPC animal layout).
@export var sheet: Texture2D
@export var shadow_sheet: Texture2D
@export var frame_px := Vector2i(64, 64)
## Where the feet touch the ground inside a frame.
@export var paws_y := 56
## name -> {"row": 0, "frames": [..], "fps": 8.0, "loop": true}. Needs idle,
## walk, attack and die.
@export var anims: Dictionary = {}
## Which frame of the attack animation the bite/blow lands on (index).
@export var attack_hit_frame := 2

@export_group("Sounds")
## Audio names (autoload/audio.gd SOUNDS). Empty = silent.
## The warning before it attacks (players learn to listen for it).
@export var sound_windup := ""
## Its attack landing.
@export var sound_attack := ""
@export var sound_hurt := ""
@export var sound_death := ""

@export_group("Stats (Normal)")
@export var hp := 18
@export var armor := 0.0
@export var damage := 5.0
@export var walk_speed := 40.0
@export var chase_speed := 85.0
## How much of a hit's knockback it takes (heavier enemies take less).
@export_range(0.0, 2.0) var knockback_taken := 1.0

@export_group("Behavior")
## Wakes up when a party member comes this close (px). Distance, never "on
## screen": ultrawide players must not wake more enemies (art-spec rule).
@export var aggro_radius := 140.0
## Gives up and walks home when its target gets this far from home (px).
@export var leash_radius := 320.0
## Starts its attack from this far (px).
@export var attack_range := 28.0
## The attack reaches this far from its feet (px) in an arc this wide.
@export var attack_reach := 30.0
@export var attack_arc := 100.0
## Telegraph: it stops and flashes this long before attacking.
@export var windup_seconds := 0.4
## Rest after an attack before it can attack again.
@export var attack_cooldown := 1.1
## How hard its hits push (px/s) and how long they stagger (s).
@export var knockback_dealt := 140.0
@export var stagger_dealt := 0.2

@export_group("Body")
## Hittable circle radius and body (collision) size.
@export var hurt_radius := 11.0
@export var body_size := Vector2(18, 8)
