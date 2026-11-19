"""Rig definition for the hero cut-out (pixel coords in game/assets/sprites/hero_01_ready.png, 276x347 padded)."""

SOURCE = "hero_01_ready"

# name: (parent, head_xy, tail_xy)   head = pivot
BONES = {
    "root": (None, (121, 166), (123, 140)),
    "spine": ("root", (123, 140), (127, 93)),
    "neck": ("spine", (127, 91), (128, 72)),
    "head": ("neck", (128, 72), (123, 28)),
    "ribbon1": ("head", (111, 44), (96, 62)),
    "ribbon2": ("ribbon1", (96, 62), (74, 85)),
    "shoulder_b": ("spine", (96, 94), (79, 141)),
    "forearm_b": ("shoulder_b", (79, 141), (79, 177)),
    "shoulder_f": ("spine", (150, 95), (166, 143)),
    "forearm_f": ("shoulder_f", (166, 143), (180, 188)),
    "sword": ("forearm_f", (182, 189), (250, 277)),
    "thigh_b": ("root", (104, 170), (85, 250)),
    "shin_b": ("thigh_b", (85, 250), (72, 321)),
    "thigh_f": ("root", (142, 170), (159, 251)),
    "shin_f": ("thigh_f", (159, 251), (168, 321)),
    "panel_b1": ("root", (75, 188), (56, 213)),
    "panel_b2": ("panel_b1", (56, 213), (43, 246)),
    "panel_f1": ("root", (161, 173), (173, 222)),
    "panel_f2": ("panel_f1", (173, 222), (189, 261)),
}

# Split the painted ready pose at real overlaps (sleeve/torso, wrist/guard,
# trousers/coat) so each articulated silhouette has its own colour planes.
PARTS = [
    ("sword", 6, [(181,186),(188,188),(259,272),(258,284),(246,278),(177,195)], ["sword"]),
    ("arm_f", 5, [(147,89),(159,91),(175,116),(192,148),(181,159),(187,188),(184,197),
        (174,197),(165,183),(157,158),(150,149),(152,125)], ["shoulder_f","forearm_f"]),
    ("arm_b", 4, [(100,85),(87,89),(69,115),(43,157),(48,168),(66,160),(68,182),
        (75,191),(89,188),(100,180),(111,169),(107,156),(100,151),(98,131)], ["shoulder_b","forearm_b"]),
    ("ribbon", 1, [(105,38),(115,40),(109,54),(98,70),(82,89),(67,89),(72,68),(92,55),(76,53),(77,43)], ["ribbon1","ribbon2"]),
    ("panel_b", 1, [(73,182),(83,187),(71,212),(58,243),(34,259),(33,216),(57,197)], ["panel_b1","panel_b2"]),
    ("panel_f", 1, [(157,165),(169,175),(179,206),(197,259),(187,273),(175,258),(168,216)], ["panel_f1","panel_f2"]),
    ("leg_b", 2, [(75,221),(121,216),(121,264),(102,278),(93,330),(48,330),(65,292),(68,263)], ["thigh_b","shin_b"]),
    ("leg_f", 2, [(127,217),(167,218),(180,254),(180,283),(202,329),(148,330),(143,290),(122,274)], ["thigh_f","shin_f"]),
]
BODY_Z = 3
# copy-only extensions (duplicated, not removed from body): legs continue up under the skirt
EXTEND = {
    "leg_b": [(87, 186), (117, 185), (116, 233), (77, 234)],
    "leg_f": [(129, 186), (156, 186), (170, 233), (126, 234)],
}  # body (head, torso, skirt) draws above the back leg, below arms
BODY_BONES = ["root", "spine", "neck", "head", "thigh_b", "thigh_f"]

# (offset px, power) for inverse-distance weights: limbs get crisp joints
WEIGHT_SHARPNESS = {"leg_b": (1.5, 7), "leg_f": (1.5, 7), "arm_f": (2.0, 6), "arm_b": (2.0, 6)}
