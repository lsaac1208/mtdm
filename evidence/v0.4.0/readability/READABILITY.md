# Five-zone figure readability

Godot renders four plates without advancing simulation. Pixels with an RGB channel difference above 18 form the mask. Contrast is the mean absolute luminance difference from the background, on a 0–255 scale. The historical joint gate is 300 pixels and contrast 20 at 33%. Each figure must also contribute at least 75 changed pixels and contrast 20 independently.

| Zone | Figure | Pixels at 33% | Contrast at 33% | Result |
| --- | --- | ---: | ---: | --- |
| village | with | 1853 | 57.3 | PASS |
| village | hero | 930 | 50.8 | PASS |
| village | grunt | 923 | 63.8 | PASS |
| road | with | 1493 | 58.2 | PASS |
| road | hero | 919 | 55.0 | PASS |
| road | crawler | 574 | 63.5 | PASS |
| lowland | with | 2198 | 50.5 | PASS |
| lowland | hero | 956 | 47.1 | PASS |
| lowland | spitter | 1242 | 53.0 | PASS |
| temple | with | 1655 | 58.6 | PASS |
| temple | hero | 927 | 54.9 | PASS |
| temple | husk | 728 | 63.3 | PASS |
| burial | with | 2804 | 66.1 | PASS |
| burial | hero | 939 | 49.8 | PASS |
| burial | elite | 1865 | 74.2 | PASS |
