from PIL import Image, ImageDraw
import os
import random
import math
import numpy as np

# === НАСТРОЙКИ ===
ICONS_FOLDER = "icons"
OUTPUT_IMAGE = "final_pattern.png"
WIDTH, HEIGHT = 2000, 4000
ICON_COUNT = 160
MIN_SPACING = 15
ROTATION_RANGE = 30
SCALE_MIN, SCALE_MAX = 0.4, 1.0

# === ФУНКЦИИ ===

def rotate_and_paste(base, img, position, angle):
    rotated = img.rotate(angle, expand=True)
    x, y = position
    x -= rotated.width // 2
    y -= rotated.height // 2
    base.paste(rotated, (x, y), rotated)

def check_overlap(x, y, w, h, placed, spacing):
    for px, py, pw, ph in placed:
        dx = x - px
        dy = y - py
        dist = math.hypot(dx, dy)
        if dist < ((w + pw) / 2 + spacing):
            return True
    return False

def draw_decor(draw, kind, x, y, size):
    if kind == "circle":
        draw.ellipse([x - size//2, y - size//2, x + size//2, y + size//2], outline=(149, 149, 158,255), width = 2)
    elif kind == "square":
        draw.rectangle([x - size//2, y - size//2, x + size//2, y + size//2], outline=(149, 149, 158,255), width = 2)
    elif kind == "star":
        r = size / 2
        points = []
        for i in range(5):
            angle = math.radians(i * 144)
            sx = x + r * math.cos(angle)
            sy = y + r * math.sin(angle)
            points.append((sx, sy))
        draw.polygon(points, outline=(149, 149, 158, 255), width = 2)

# === ЗАГРУЗКА ===
canvas = Image.new("RGBA", (WIDTH, HEIGHT), (23, 23, 33, 255))
icon_paths = [os.path.join(ICONS_FOLDER, f) for f in os.listdir(ICONS_FOLDER) if f.endswith(".png")]
icons = [Image.open(p).convert("RGBA") for p in icon_paths]
placed = []

# === РАЗМЕЩЕНИЕ ИКОНКИ ===
for _ in range(ICON_COUNT):
    for attempt in range(100):
        icon = random.choice(icons)
        scale = random.uniform(SCALE_MIN, SCALE_MAX)
        new_size = (int(icon.width * scale), int(icon.height * scale))
        resized = icon.resize(new_size, Image.Resampling.LANCZOS)
        angle = random.uniform(-ROTATION_RANGE, ROTATION_RANGE)

        w, h = resized.size
        cx = random.randint(w//2, WIDTH - w//2)
        cy = random.randint(h//2, HEIGHT - h//2)

        if not check_overlap(cx, cy, w, h, placed, MIN_SPACING):
            rotate_and_paste(canvas, resized, (cx, cy), angle)
            placed.append((cx, cy, w, h))
            break

# === ДЕКОРАТИВНЫЕ ЭЛЕМЕНТЫ ===
# draw = ImageDraw.Draw(canvas)
# decor_kinds = ["circle", "square", "star"]

# for _ in range(DECOR_COUNT):
#     for attempt in range(100):
#         size = random.randint(5, 14)
#         x = random.randint(size, WIDTH - size)
#         y = random.randint(size, HEIGHT - size)
#         if not check_overlap(x, y, size, size, placed, MIN_SPACING):
#             kind = random.choice(decor_kinds)
#             draw_decor(draw, kind, x, y, size)
#             placed.append((x, y, size, size))
#             break


# Преобразуем в массив
array = np.array(canvas)

# Добавим зернистость
noise = np.random.normal(0, 15, array.shape[:2])  # стандартное отклонение регулирует силу шума
noise = np.clip(noise, -30, 30).astype(np.int16)

# Применим шум к каждому каналу (R, G, B)
for i in range(3):  # не трогаем альфа-канал
    array[..., i] = np.clip(array[..., i].astype(np.int16) + noise, 0, 255)

# Вернем в изображение
canvas = Image.fromarray(array.astype(np.uint8), "RGBA")

# === СОХРАНЕНИЕ ===
canvas.save(OUTPUT_IMAGE)
print(f"Готово: {OUTPUT_IMAGE}")
