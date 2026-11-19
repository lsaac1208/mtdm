SOURCE = "crawler_crawl"
MESH_STEP = 4
BONES = {
    "root":    (None, (80, 52), (60, 54)),
    "spine":   ("root", (80, 52), (128, 46)),
    "neck":    ("spine", (128, 46), (140, 42)),
    "head":    ("neck", (140, 42), (160, 44)),
    "hind_b":  ("root", (56, 54), (30, 66)),
    "hfoot_b": ("hind_b", (30, 66), (12, 84)),
    "hind_f":  ("root", (66, 60), (54, 74)),
    "hfoot_f": ("hind_f", (54, 74), (44, 86)),
    "fore_f":  ("spine", (124, 54), (134, 74)),
    "claw_f":  ("fore_f", (134, 74), (162, 86)),
    "fore_b":  ("spine", (104, 58), (98, 74)),
    "claw_b":  ("fore_b", (98, 74), (112, 86)),
}
PARTS = [
    ("fore_f", 5, [(116, 52), (142, 52), (172, 76), (172, 96), (128, 96), (116, 70)], ["fore_f", "claw_f"]),
    ("hind_b", 1, [(2, 52), (52, 44), (64, 66), (34, 94), (2, 94)], ["hind_b", "hfoot_b"]),
    ("fore_b", 2, [(92, 60), (114, 60), (120, 92), (90, 92)], ["fore_b", "claw_b"]),
]
ERASE_GREY = [[(38, 79), (120, 79), (120, 92), (38, 92)]]
BODY_Z = 3
BODY_BONES = ["root", "spine", "neck", "head", "hind_f", "hfoot_f"]
FILL_UNDER = ("fore_f",)
SPLIT_X = 60.0
SKIRT_Y = 999
SKIRT_FOLLOW = 0.0
WEIGHT_SHARPNESS = {"fore_f": (1.0, 6), "hind_b": (1.0, 6), "fore_b": (1.0, 6), "body": (2.0, 5)}
SCALE_MUL = 0.9
