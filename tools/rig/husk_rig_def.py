SOURCE = "husk_walk"
MESH_STEP = 4
BONES = {
    "root":       (None, (74, 100), (76, 80)),
    "spine":      ("root", (76, 80), (80, 44)),
    "neck":       ("spine", (82, 40), (88, 28)),
    "head":       ("neck", (88, 28), (94, 8)),
    "shoulder_f": ("spine", (96, 46), (116, 54)),
    "forearm_f":  ("shoulder_f", (116, 54), (134, 54)),
    "thigh_b": ("root", (62, 112), (52, 140)),
    "shin_b":  ("thigh_b", (52, 140), (44, 162)),
    "thigh_f": ("root", (90, 112), (96, 140)),
    "shin_f":  ("thigh_f", (96, 140), (102, 164)),
}
PARTS = [
    ("arm_f", 5, [(88, 36), (142, 40), (142, 72), (104, 70), (88, 58)], ["shoulder_f", "forearm_f"]),
    ("leg_b", 2, [(22, 142), (74, 140), (74, 168), (22, 170)], ["thigh_b", "shin_b"]),
    ("leg_f", 2, [(80, 142), (122, 142), (126, 170), (80, 170)], ["thigh_f", "shin_f"]),
]
EXTEND = {"leg_b": [(40, 116), (74, 116), (74, 146), (36, 146)], "leg_f": [(80, 116), (110, 116), (114, 146), (80, 146)]}
BODY_Z = 3
BODY_BONES = ["root", "spine", "neck", "head", "thigh_b", "thigh_f"]
FILL_UNDER = ("arm_f",)
SPLIT_X = 76.0
SKIRT_Y = 112
SKIRT_FOLLOW = 0.35
WEIGHT_SHARPNESS = {"leg_b": (1.0, 7), "leg_f": (1.0, 7), "arm_f": (1.5, 6)}
