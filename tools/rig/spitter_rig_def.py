SOURCE = "spitter_side"
BONES = {
    "root":       (None, (178, 218), (182, 180)),
    "spine":      ("root", (182, 180), (196, 110)),
    "neck":       ("spine", (200, 100), (228, 62)),
    "head":       ("neck", (228, 62), (252, 30)),
    "shoulder_b": ("spine", (166, 96), (150, 160)),
    "forearm_b":  ("shoulder_b", (150, 160), (166, 228)),
    "thigh_b": ("root", (150, 240), (112, 274)),
    "shin_b":  ("thigh_b", (112, 274), (56, 300)),
    "thigh_f": ("root", (208, 240), (228, 274)),
    "shin_f":  ("thigh_f", (228, 274), (246, 302)),
}
PARTS = [
    ("arm_b", 4, [(150, 80), (188, 86), (188, 160), (184, 238), (148, 242), (134, 160)], ["shoulder_b", "forearm_b"]),
    ("leg_b", 2, [(36, 256), (132, 250), (126, 310), (36, 312)], ["thigh_b", "shin_b"]),
    ("leg_f", 2, [(194, 256), (258, 256), (270, 310), (204, 310)], ["thigh_f", "shin_f"]),
]
EXTEND = {"leg_b": [(110, 226), (166, 226), (150, 262), (100, 262)], "leg_f": [(190, 226), (236, 226), (240, 262), (196, 262)]}
BODY_Z = 3
BODY_BONES = ["root", "spine", "neck", "head", "thigh_b", "thigh_f"]
FILL_UNDER = ("arm_b",)
SPLIT_X = 182.0
SKIRT_Y = 222
SKIRT_FOLLOW = 0.4
WEIGHT_SHARPNESS = {"leg_b": (1.5, 7), "leg_f": (1.5, 7), "arm_b": (2.0, 6)}
