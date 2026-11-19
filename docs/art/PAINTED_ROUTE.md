# 五区原画与引擎接入

五张场景画、三张透明物件图集和一张腐秽毒潭均由 Codex 的内置 ImageGen 生成。运行时资源在 [painted](../../game/assets/env/painted) 下。场景画输出为 1536 × 1024，转为 WebP。各图集按透明沟槽裁切，保留抗锯齿边缘与每件物体独立的脚点。

[场景绘制](../../game/scripts/level/painted_route.gd) 将每张远景画的横移限制在本区内。路标、残车、芦苇、倒钟和墓座以更快的速度形成近景视差。可走地面在 [土层材质](../../game/shaders/painted_soil.gdshader) 中重用该区画底的矿物切面，跨区时在世界坐标上叠化。平台顶部与关卡中的原碰撞面共用坐标，毒池的图像宽度直接读取当前生效半径。

## ImageGen 场景提示

五次生成分别拼接下面的共用提示和区域描述。

> Landscape-format, wide SIDE VIEW background plate for a professional hand-painted 2D Chinese dark-fantasy action game. Image is atmosphere behind animated actors. One single full-bleed environmental painting, wide 3:2 landscape. Chinese ink and mineral pigment on toned paper, sublime cinematic haze, distinctive hand-painted dry-brush texture and lost ink edges, painterly broken shapes, sophisticated light, clear aerial perspective. Avoid repetitive graphic outlined shapes. Eye-level side scrolling theatre, horizontal horizon about 50% from top. In lower 35% a light, soft low-detail field behind the dark hero's legs: distance fog, low-contrast ochre/silver mud bank; no large black foreground objects. Bottom-most 12% a natural horizontal band of stony clay material, seen in side-on cut section with fissures and embedded rubble. Sky pale and nuanced, no sun disk. No human or monster, no foreground hero, no HUD/lettering/frame, no new city skylines.

**village.webp**

> A deserted late-imperial northern Chinese farming village after a plague. At the left third a low, distant, asymmetric row of collapsed tiled rooftops with exposed rafters and stamped-earth walls; far right a broken courtyard gate. The middle breathes with an expansive sunlit gap between huts, with a soft mountain shoulder and fog, only a thin stream of smoke. Autumn straw, pale limestone, warm ash, desaturated faded russet. Small ominous dark birds at roof edge. Devastated but beautiful.

**road.webp**

> The abandoned salt road climbs along a ravine. An ancient broken masonry aqueduct spans the far-left half; two fallen arches and eroded piers, rope tied around a leaning waypost on the right third. A distant train of tiny unoccupied broken carts. Wind-cut terracotta loess bluffs with intricate sediment and drifting pale dust. A quiet flat chalk and sandstone valley through the center, sparse weeds. Russet, sallow grey-gold and pale dry clay.

**lowland.webp**

> A drowned floodplain with distant tilted river sluices and an abandoned Chinese dyke, half-submerged willow trunks and low reeds to the outer thirds. Polluted shallow water under veils of grey-green fog, distinctive pallid reeds and salt bloom catching the diffuse light. Center opens into very light celadon marsh, pale banks, barely visible submerged village. Mineral sage, smoked teal, bleached grey; subdued and uncanny, no bright acid-green highlights anywhere.

**temple.webp**

> An abandoned Chinese Daoist mountain temple, its monumental broken dougong roof and sweeping eaves pushed to the RIGHT third, deep layers of moss, decaying vermilion wood columns, a roofless left pavilion enveloped by saffron mist. The center opens on quiet distant stairs and an empty pale courtyard. Shallow painted architectural detail in outer thirds. Muted burnt vermilion, gold ochre, weathered stone and pale peach ash. Sparse loose votive papers and bell hanging at far edge.

**burial.webp**

> A burial ground at late dusk, in Chinese hills. Distant earthen burial mounds with clustered leaning stone grave markers, a small distant funerary arch, very low tomb vaults, four or five old funerary poles located only at outermost edges, crows roosting in the distance. Large spectral pale silver-blue fog basin in the central 60% of composition and along lower half; silhouettes erode softly into fog. Blue grey-violet and cold chalk whites. The open central space is the arena for a sword fight.

## ImageGen 近景物件提示

> One production prop sprite atlas for the side scrolling Chinese ink-painted dark fantasy game Taoist Wanderer. Transparent background, NO ground plane, cast shadows, lettering or captions. Six standalone scenery clusters arranged in a perfectly regular 3 COLUMN by 2 ROW grid with generous empty gutters. All subjects are separate, centered in their cells, bottom anchored at same relative height, ample empty margins. Mild side-facing 3/4 orthographic view, little foreshortening, detailed Chinese mineral wash on parchment applied only on objects, sharp fractured ink silhouettes, muted ochre slate, cool shadow planes, light from upper left. Top left: one broken modest waist high square stone Daoist WAYMARK leaning by an extinguished bronze candle-lantern, empty black wick, tattered split faded cinnabar paper seal hanging from the fissure, no writing. Top middle: weatherbeaten broken ox-cart wheel and a few splintered planks. Top right: clump of dry ivory reed heads, a low crooked willow stump and a small pale mineral-crust boulder. Bottom left: a toppled bronze temple bell with coils of rope and one torn faded vermilion tassel. Bottom middle: a low cluster of three tiny irregular old Chinese grave markers and a fallen spent burial censer, no writing. Bottom right: one bent reed-bound low fence with broken upright stakes and fallen rope. No people; one collectible-quality meticulous prop group per slot; each cluster has a visible flat base. A true game textures atlas, no large backgrounds and no sky.

## ImageGen 篝火与路标提示

> Transparent prop atlas for the painterly 2D side-scrolling Chinese ruined village in Taoist Wanderer. FOUR distinct objects, exactly 2 columns by 2 rows. Each complete object separated by very broad transparent margins. Side on, light from upper left, visible brush marks and precise ink, late imperial rural northern China, restrained faded ochre and brown tones. TOP LEFT critical: a spent CAMPFIRE hearth, very low wide ellipse of FOUR blackened split logs with glowing vermilion coals and a rough charcoal ring of grey rocks. Deep ember-red center, absolutely no standing flame or vertical smoke, side view and compact; runtime draws the living low flame. TOP RIGHT: one short roughly hewn upright wooden waypost with a little tied faded rectangular prayer paper, slim, mysterious. BOTTOM LEFT: a single chipped slant rectangular slate waymarker, a piece of yellow prayer paper wrapped around its upper half under a hemp cord, visible carved circular outline, no letters. BOTTOM RIGHT: a small distant ritual roadside bell suspended from one thin bent bamboo pole, no bright light. Isolated true alpha background only, no scenery, no additional rocks outside the objects, no lettering or numbers or border.

## ImageGen 可走平台提示

> Transparent atlas sheet for 2D sidescrolling Taoist Wanderer. Exactly SIX individual walkable terrain platforms in REGULAR 3-column 2-row grid, isolated transparent background. Professional Chinese ink and mineral pigment videogame environment art. Every item from the side, orthographic, horizontal walkable upper face across ENTIRE width with a thin visible light top plane in slight 3/4, vertical dark broken sides, ground-level flat base. Equally wide rectangular silhouettes, each desired width about twice height, lots of transparent gutter between items. No letters/no words, figures, grass growing higher than the walk surface, floors floating alone. Top LEFT: a small section of collapsed ochre rammed-earth village wall with baked-brick footing, tactile cracked ochre plaster and embedded brick. Top MIDDLE: stony sandstone rubble piled flat and wide with timber. Top RIGHT: a collapsed Chinese wooden ox-cart turned into a wide low wood plank deck on half-submerged spoked wheels, flat walked-on platform. Bottom LEFT: a block of pale shale with level flaking top, bleached rims and damp green-black mineral veins. Bottom MIDDLE: chipped reddish Daoist altar block with horizontal slab resting on stone brackets, a fragment of faded red paper seal. Bottom RIGHT: collapsed Chinese tomb plinth in grey-violet granite, broken relief clouds on its side, worn level top slab, no tombstone above the slab. Varied realistic material, crisp light carved edges on the top and calming mid tone faces with brown ink cavities. Each object separate, beautifully legible even rendered tiny, no outer black silhouette line. Draw all six from side to make six low distinctly playable walkable blocks.

## ImageGen 毒潭提示

> One isolated ground hazard sprite, true transparent background. A shallow oblong pool of poisonous ink and mineral corruption for a side scrolling Chinese fantasy game. Single long LOW horizontal ellipse 6:1 width to height, viewed at a grazing angle. Contained within a clearly continuous dark charcoal mineralized rim with thin bright acid chartreuse salt on its inner lips; dark black-green iridescent viscous center, two or three yellow-jade eddies; bleached crystals at the two endpoints, ground-level and entirely inside the pool outline. Hand painted traditional pigments, intricate brush edge with tapered ends, enough tonal contrast to read in quarter scale, no rectangle or scenery or floor outside silhouette. No drawn smoke, sparks, vertical material, text, UI, border, symbols, or floating islands. Only the single horizontal pool silhouette on transparency. Center horizontally and vertically, natural scale close-up.
