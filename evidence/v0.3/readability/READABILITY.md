# Five-zone figure readability

Godot renders four plates without advancing simulation. Pixels with an RGB channel difference above 18 form the mask. Contrast is the mean absolute luminance difference from the background, on a 0–255 scale. The historical joint gate is 300 pixels and contrast 20 at 33%. Each figure must also contribute at least 75 changed pixels and contrast 20 independently.

| Zone | Figure | Pixels at 33% | Contrast at 33% | Result |
| --- | --- | ---: | ---: | --- |
| village | with | 2014 | 69.7 | PASS |
| village | hero | 885 | 65.9 | PASS |
| village | grunt | 1129 | 72.6 | PASS |
| road | with | 1283 | 71.9 | PASS |
| road | hero | 863 | 67.5 | PASS |
| road | crawler | 420 | 81.0 | PASS |
| lowland | with | 1980 | 62.6 | PASS |
| lowland | hero | 884 | 59.6 | PASS |
| lowland | spitter | 1096 | 65.1 | PASS |
| temple | with | 2205 | 75.2 | PASS |
| temple | hero | 875 | 68.0 | PASS |
| temple | husk | 1330 | 79.9 | PASS |
| burial | with | 3037 | 77.3 | PASS |
| burial | hero | 901 | 61.8 | PASS |
| burial | elite | 2136 | 83.8 | PASS |
