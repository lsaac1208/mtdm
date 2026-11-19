"""Rig definition for the hero cut-out (pixel coords in game/assets/sprites/hero_01_ready.png, 276x347 padded)."""

SOURCE = "hero_01_ready"

# name: (parent, head_xy, tail_xy)   head = pivot
BONES = {
    "root":    (None,     (120, 172), (120, 140)),
    "spine":   ("root",   (120, 140), (121, 96)),
    "neck":    ("spine",  (121, 92),  (122, 70)),
    "head":    ("neck",   (122, 70),  (122, 30)),
    "ribbon1": ("head",   (104, 44),  (95, 60)),
    "ribbon2": ("ribbon1", (95, 60),  (92, 76)),
    "shoulder_b": ("spine", (96, 96),  (74, 140)),   # back arm (screen-left, gourd hand)
    "forearm_b":  ("shoulder_b", (74, 140), (63, 180)),
    "shoulder_f": ("spine", (154, 96), (168, 142)),  # front/sword arm (screen-right)
    "forearm_f":  ("shoulder_f", (168, 142), (178, 178)),
    "sword":      ("forearm_f", (178, 180), (254, 304)),
    "thigh_b": ("root",    (104, 176), (88, 250)),
    "shin_b":  ("thigh_b", (88, 250),  (76, 318)),
    "thigh_f": ("root",    (140, 176), (160, 250)),
    "shin_f":  ("thigh_f", (160, 250), (172, 318)),
    "panel_b1": ("root",   (72, 176),  (48, 238)),
    "panel_b2": ("panel_b1", (48, 238), (30, 296)),
    "panel_f1": ("root",   (180, 186), (192, 240)),
    "panel_f2": ("panel_f1", (192, 240), (200, 296)),
}

# Part polygons (pixel coords). Pixels are assigned to the first part whose
# polygon contains them, in this order; everything else belongs to "body".
PARTS = [
    # name, z (higher draws in front), polygon, bones it is weighted to
    ("sword",   6, [(170, 172), (188, 172), (270, 304), (264, 318), (236, 304)], ["sword"]),
    ("arm_f",   5, [(150, 84), (166, 84), (192, 120), (196, 176), (186, 190), (168, 190), (160, 150), (150, 120)], ["shoulder_f", "forearm_f"]),
    ("arm_b",   4, [(98, 84), (84, 88), (46, 140), (50, 160), (56, 186), (72, 192), (80, 170), (92, 140), (104, 112)], ["shoulder_b", "forearm_b"]),
    ("ribbon",  1, [(84, 38), (112, 36), (110, 50), (100, 80), (88, 82), (86, 60)], ["ribbon1", "ribbon2"]),
    ("panel_b", 1, [(68, 150), (82, 160), (70, 240), (48, 304), (18, 304), (20, 230), (40, 190)], ["panel_b1", "panel_b2"]),
    ("panel_f", 1, [(178, 176), (198, 180), (210, 240), (212, 304), (186, 304), (182, 240), (172, 200)], ["panel_f1", "panel_f2"]),
    ("leg_b",   2, [(52, 256), (106, 256), (108, 290), (90, 330), (40, 330), (52, 300)], ["thigh_b", "shin_b"]),
    ("leg_f",   2, [(136, 256), (190, 256), (196, 300), (200, 330), (146, 330), (140, 300)], ["thigh_f", "shin_f"]),
]
BODY_Z = 3
# copy-only extensions (duplicated, not removed from body): legs continue up under the skirt
EXTEND = {
    "leg_b": [(60, 196), (112, 196), (110, 262), (54, 262)],
    "leg_f": [(128, 196), (182, 196), (190, 262), (134, 262)],
}  # body (head, torso, skirt) draws above the back leg, below arms
BODY_BONES = ["root", "spine", "neck", "head", "thigh_b", "thigh_f"]

# (offset px, power) for inverse-distance weights: limbs get crisp joints
WEIGHT_SHARPNESS = {"leg_b": (1.5, 7), "leg_f": (1.5, 7), "arm_f": (2.0, 6), "arm_b": (2.0, 6)}
