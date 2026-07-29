from PIL import Image, ImageDraw

SIZE = 1024
GREEN = (0, 177, 64)
WHITE = (255, 255, 255)
STRIPE_WIDTH = 24

OUTPUT = "SeenAt/SeenAt/Resources/Assets.xcassets/AppIcon.appiconset/icon.png"
SPLASH = "SeenAt/SeenAt/Resources/Assets.xcassets/SplashBackground.imageset/splash-screen-field.jpg"

bg = Image.open(SPLASH)
w, h = bg.size
min_dim = min(w, h)
bg = bg.crop(((w - min_dim) // 2, (h - min_dim) // 2, (w + min_dim) // 2, (h + min_dim) // 2))
bg = bg.resize((SIZE, SIZE), Image.LANCZOS).convert('RGBA')

mask = Image.new('L', (SIZE, SIZE), 0)
draw = ImageDraw.Draw(mask)

draw.polygon([
    (512-70, 180),
    (512-200, 130),
    (512-350, 170),
    (512-350, 290),
    (512-280, 340),
    (512-280, 350),
    (512-280, 890),
    (512+280, 890),
    (512+280, 350),
    (512+280, 340),
    (512+350, 290),
    (512+350, 170),
    (512+200, 130),
    (512+70, 180),
], fill=255)

draw.ellipse([512-100, 50, 512+100, 220], fill=0)

shirt = Image.new('RGBA', (SIZE, SIZE), WHITE + (255,))
stripe = Image.new('RGBA', (STRIPE_WIDTH, SIZE), GREEN + (255,))
for x in range(STRIPE_WIDTH, SIZE, STRIPE_WIDTH * 2):
    shirt.paste(stripe, (x, 0))

result = Image.composite(shirt, bg, mask)
result.save(OUTPUT)
