# Five-zone figure readability

Godot renders four plates without advancing simulation. Pixels with an RGB channel difference above 18 form the mask. Contrast is the mean absolute luminance difference from the background, on a 0–255 scale. The historical joint gate is 300 pixels and contrast 20 at 33%. Each figure must also contribute at least 75 changed pixels and contrast 20 independently.

| Zone | Figure | Pixels at 33% | Contrast at 33% | Result |
| --- | --- | ---: | ---: | --- |
| village | with | 1857 | 58.5 | PASS |
| village | hero | 935 | 52.5 | PASS |
| village | grunt | 922 | 64.5 | PASS |
| road | with | 1476 | 57.6 | PASS |
| road | hero | 926 | 54.8 | PASS |
| road | crawler | 550 | 62.3 | PASS |
| lowland | with | 1856 | 47.3 | PASS |
| lowland | hero | 959 | 47.1 | PASS |
| lowland | spitter | 897 | 47.6 | PASS |
| temple | with | 1818 | 58.5 | PASS |
| temple | hero | 950 | 55.2 | PASS |
| temple | husk | 868 | 62.0 | PASS |
| burial | with | 2835 | 66.3 | PASS |
| burial | hero | 969 | 50.7 | PASS |
| burial | elite | 1866 | 74.3 | PASS |
