SOURCE = "grunt_walk"
BONES = {
    "root":       (None, (148, 196), (150, 160)),
    "spine":      ("root", (150, 160), (168, 100)),
    "neck":       ("spine", (172, 92), (184, 72)),
    "head":       ("neck", (184, 72), (192, 26)),
    "shoulder_f": ("spine", (196, 108), (232, 142)),
    "forearm_f":  ("shoulder_f", (232, 142), (270, 182)),
    "shoulder_b": ("spine", (104, 100), (86, 152)),
    "forearm_b":  ("shoulder_b", (86, 152), (92, 205)),
    "thigh_b": ("root", (118, 206), (68, 226)),
    "shin_b":  ("thigh_b", (68, 226), (24, 240)),
    "thigh_f": ("root", (172, 206), (184, 248)),
    "shin_f":  ("thigh_f", (184, 248), (196, 292)),
}
PARTS = [
    ("arm_f", 5, [(186, 94), (216, 98), (252, 124), (288, 164), (288, 200), (254, 200), (226, 158), (188, 132)], ["shoulder_f", "forearm_f"]),
    ("arm_b", 4, [(104, 84), (72, 94), (64, 140), (68, 212), (112, 214), (106, 152), (116, 110)], ["shoulder_b", "forearm_b"]),
    ("leg_b", 2, [(10, 212), (84, 206), (102, 236), (72, 262), (10, 264)], ["thigh_b", "shin_b"]),
    ("leg_f", 2, [(158, 232), (214, 232), (222, 302), (162, 302)], ["thigh_f", "shin_f"]),
]
EXTEND = {"leg_f": [(160, 200), (206, 200), (212, 240), (162, 240)]}
BODY_Z = 3
BODY_BONES = ["root", "spine", "neck", "head", "thigh_b", "thigh_f"]
FILL_UNDER = ("arm_f", "arm_b")
SPLIT_X = 148.0
SKIRT_Y = 196
SKIRT_FOLLOW = 0.4
WEIGHT_SHARPNESS = {"leg_b": (1.5, 7), "leg_f": (1.5, 7), "arm_f": (2.0, 6), "arm_b": (2.0, 6)}
