# Spec of the 12 photo/plate fixtures (read by build.py).  Coordinates are SOURCE pixels of the
# generated photo (1536x1024).  plate dicts are documented in page.py (plate_html).

W, H = 1536, 1024

BLUE = 140 / 440.0     # plate aspect (height/width)
GREEN = 140 / 480.0

def plate(text, cx, cy, width, color='blue', prov_len=2, **kw):
    """plate centred on (cx, cy) with the given width; height follows the plate aspect"""
    h = width * (GREEN if color == 'green' else BLUE)
    d = dict(text=text, x=cx - width / 2.0, y=cy - h / 2.0, w=width, h=h, color=color, prov_len=prov_len)
    d.update(kw)
    return d

PLATES = {
    'plate_01_clear': dict(img='plate_01_a.png', plate=plate('粤B8S6Q0', 787.5, 522.3, 398),
                           notes='Frontal plate, ≈398 px wide, daylight, no occlusion.'),
    'plate_02_angle': dict(img='plate_02_b.png', plate=plate('沪A23745', 1070, 580, 468, yaw=38, persp=1400, rot=-7.5, h=147),
                           notes='Plate seen at an angle: ≈38° yaw (left end nearer the camera, so taller) and ≈7.5° roll, '
                                 'as the generated car\'s plate recess demanded more yaw than the brief\'s ~25°. The generated photo '
                                 'carries a blank blue plate in its recess; the rendered plate is placed to cover it.'),
    'plate_03_small': dict(img='plate_03_a.png', plate=plate('京AF0K2L', 763.4, 471, 116),
                           notes='Small plate: far car, plate ≈116 px wide (characters ≈22 px tall).'),
    'plate_04_glare': dict(img='plate_04_a.png', plate=plate('浙AG5T91', 785, 530.7, 305, h=101, blur=1.2,
                           glare=dict(inset='0', bg='linear-gradient(100deg, rgba(255,255,255,0) 22%, rgba(255,255,255,.88) 46%, rgba(255,255,255,0) 70%)')),
                           notes='Glare: a soft white reflection streak runs across the middle of the plate (characters ·G5 partly washed out), '
                                 'slight defocus (≈1.2 px).'),
    'plate_05_green': dict(img='plate_05_a.png', plate=plate('粤AD12345', 623.7, 572.1, 390, color='green', prov_len=3),
                           notes='New-energy plate: green background, black characters, 8 characters (粤A D12345).'),
    'plate_06_night': dict(img='plate_06_c.png', plate=plate('苏E7H3M6', 768.7, 563.1, 300, h=102,
                           css='filter:brightness(1.08)',
                           pool=dict(inset='-70 -70 -70 -50',
                                     bg='radial-gradient(ellipse 45% 55% at 10% 22%, rgba(255,255,240,.55), rgba(255,255,240,0) 100%), radial-gradient(ellipse 45% 55% at 90% 22%, rgba(255,255,240,.55), rgba(255,255,240,0) 100%), radial-gradient(ellipse 60% 60% at 50% 45%, rgba(255,250,235,.18), rgba(255,250,235,0) 100%)')),
                           notes='Night: plate lit by two lamps (brighter at both upper corners), dark surroundings; the plate is slightly '
                                 'smaller than a standard 440 mm plate would appear at this distance (≈300 px).'),
}

PHOTOS = {
    # Face box = hairline / top of the forehead to the chin, ear to ear (source px, measured on the source image).
    # A fringe that hides the hairline: the box starts where the forehead becomes visible.
    # A face mask: the box ends at the bottom edge of the mask (the chin is under it).
    'photo_01_friends': dict(img='photo_01_a.png', notes='', faces=[
        (100, 196, 326, 356),    # 0 man, green jacket (left, tilted head, stubble)
        (460, 390, 170, 250),    # 1 woman, long black hair
        (723, 262, 215, 246),    # 2 man, grey hair, beard
        (978, 376, 185, 209),    # 3 woman, curly hair
        (1195, 466, 231, 226),   # 4 woman (right)
    ]),
    'photo_02_couple': dict(img='photo_02_a.png', notes='Face 0 is turned towards face 1: his far ear is hidden, the box ends at the far '
                                                     'cheek edge; his beard is included.', faces=[
        (383, 150, 439, 474),  # 0 man
        (830, 348, 374, 398),  # 1 woman
    ]),
    'photo_03_crowd': dict(img='photo_03_a.png', notes='Faces 6-9 are small (23-46 px wide). Face 9 (23 px) stands behind the woman with '
                                                  'the phone: its right half is hidden by her hair, the box ends where her hair starts. Face 5\'s fringe hides the hairline, '
                                                  'the box starts where the forehead becomes visible. '
                                                  'Excluded: ≈15 far pedestrians in the background (faces ≈8-20 px, x 650-1010 / '
                                                  'y 380-440), people seen from behind and the figures on the shop poster.', faces=[
        (114, 270, 95, 74),     # 0 man, black tee (left edge)
        (290, 300, 137, 120),   # 1 woman, white top / cardigan
        (680, 383, 85, 79),     # 2 woman, black dress
        (846, 324, 66, 70),     # 3 man, blue polo
        (1083, 374, 102, 97),   # 4 woman, floral dress (3/4 view)
        (1348, 331, 131, 87),   # 5 man, grey tee + glasses (right); fringe hides the hairline
        (557, 356, 46, 43),     # 6 woman with phone, head tilted down
        (980, 365, 31, 35),     # 7 woman, black top, white bag strap
        (627, 320, 45, 39),     # 8 boy, white tee + glasses
        (543, 336, 23, 27),     # 9 man, white tee, behind the woman with the phone (right half hidden by her hair)
    ]),
    'photo_04_profile': dict(img='photo_04_a.png', notes='Face 0 is a profile: the box spans the back of the ear to the front of the lips. '
                                                    'Face 1 is seen 3/4: his far ear is hidden. Face 2 wears a cap: the hairline is under '
                                                    'the brim, the box starts where the forehead shows.', faces=[
        (275, 206, 271, 342),   # 0 woman, profile
        (600, 300, 248, 205),   # 1 man, sunglasses
        (1262, 464, 196, 154),  # 2 adult, cap, looking down
    ]),
    'photo_05_dinner': dict(img='photo_05_a.png', notes='Face 1 wears a face mask (box includes the mask). Face 0 is cut by the left frame '
                                                  'edge, face 4 by the right one; fringes hide the hairline of faces 0 and 3. '
                                                  'Excluded: the wedding photo in the frame on the sideboard '
                                                  '(x 905-955 / y 265-320, faces ≈8 px) and the landscape painting in the mirror.', faces=[
        (0, 320, 301, 413),     # 0 girl (left edge, close to the camera, fringe)
        (302, 293, 211, 241),   # 1 woman, face mask
        (602, 192, 153, 147),   # 2 man, glasses
        (1036, 310, 158, 131),  # 3 boy, fringe
        (1354, 298, 182, 249),  # 4 woman, older, hair swept back (right edge)
    ]),
    'photo_06_backlit': dict(img='photo_06_a.png', notes='Face 1 wears a face mask (box includes the mask). Fringes hide the hairline of '
                                                  'faces 0 and 3. Excluded: the two tiny figures on the far beach, seen from '
                                                  'behind (x 1430-1500 / y 360-420, heads ≈8 px).', faces=[
        (169, 246, 339, 262),   # 0 man (left), fringe
        (497, 382, 214, 261),   # 1 woman, face mask
        (857, 402, 145, 175),   # 2 woman (centre-right), 3/4 view
        (1083, 274, 243, 170),  # 3 man (right), head tilted
    ]),
}
