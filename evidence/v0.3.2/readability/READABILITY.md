# Five-zone figure readability

Godot renders four plates without advancing simulation. Pixels with an RGB channel difference above 18 form the mask. Contrast is the mean absolute luminance difference from the background, on a 0–255 scale. The historical joint gate is 300 pixels and contrast 20 at 33%. Each figure must also contribute at least 75 changed pixels and contrast 20 independently.

| Zone | Figure | Pixels at 33% | Contrast at 33% | Result |
| --- | --- | ---: | ---: | --- |
| village | with | 1859 | 57.2 | PASS |
| village | hero | 937 | 50.6 | PASS |
| village | grunt | 922 | 63.9 | PASS |
| road | with | 1446 | 57.4 | PASS |
| road | hero | 921 | 54.9 | PASS |
| road | crawler | 525 | 61.9 | PASS |
| lowland | with | 1862 | 47.4 | PASS |
| lowland | hero | 956 | 47.1 | PASS |
| lowland | spitter | 906 | 47.7 | PASS |
| temple | with | 1792 | 58.5 | PASS |
| temple | hero | 927 | 54.9 | PASS |
| temple | husk | 865 | 62.3 | PASS |
| burial | with | 2802 | 66.1 | PASS |
| burial | hero | 937 | 49.9 | PASS |
| burial | elite | 1865 | 74.2 | PASS |
