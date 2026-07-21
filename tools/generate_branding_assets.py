from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "branding"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"


def rounded_gradient_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()

    top = (31, 85, 106)
    mid = (34, 122, 145)
    bottom = (74, 193, 207)

    for y in range(size):
        ratio = y / (size - 1)
        if ratio < 0.55:
            local = ratio / 0.55
            color = tuple(
                int(top[i] + (mid[i] - top[i]) * local) for i in range(3)
            )
        else:
            local = (ratio - 0.55) / 0.45
            color = tuple(
                int(mid[i] + (bottom[i] - mid[i]) * local) for i in range(3)
            )
        for x in range(size):
            pixels[x, y] = (*color, 255)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=int(size * 0.24),
        fill=255,
    )
    image.putalpha(mask)
    return image


def draw_symbol(
    draw: ImageDraw.ImageDraw,
    center_x: float,
    center_y: float,
    scale: float,
    color: tuple[int, int, int, int],
) -> None:
    line_width = max(8, int(scale * 0.16))

    road_width = scale * 0.34
    road_height = scale * 1.42
    road_box = (
        center_x - road_width / 2,
        center_y - road_height / 2,
        center_x + road_width / 2,
        center_y + road_height / 2,
    )
    draw.rounded_rectangle(
        road_box,
        radius=road_width * 0.44,
        outline=color,
        width=line_width,
    )

    dash_gap = scale * 0.08
    dash_height = scale * 0.16
    dash_count = 4
    first_dash_top = center_y - (dash_count / 2) * (dash_height + dash_gap) + dash_gap
    for index in range(dash_count):
        top = first_dash_top + index * (dash_height + dash_gap)
        draw.rounded_rectangle(
            (
                center_x - line_width / 2.6,
                top,
                center_x + line_width / 2.6,
                top + dash_height,
            ),
            radius=line_width / 2,
            fill=color,
        )

    for direction in (-1, 1):
        for step, arc_scale in enumerate((0.78, 1.12, 1.45), start=1):
            width = scale * arc_scale
            height = scale * (0.64 + step * 0.08)
            left = center_x + direction * (road_width * 0.26) - width / 2
            top = center_y - height / 2
            start = 112 if direction < 0 else -22
            end = 248 if direction < 0 else 114
            draw.arc(
                (left, top, left + width, top + height),
                start=start,
                end=end,
                fill=color,
                width=max(6, int(line_width * (0.82 - step * 0.06))),
            )

    node_radius = scale * 0.09
    node_positions = [
        (center_x - scale * 0.88, center_y - scale * 0.2),
        (center_x + scale * 0.92, center_y - scale * 0.02),
        (center_x - scale * 0.68, center_y + scale * 0.66),
        (center_x + scale * 0.66, center_y + scale * 0.7),
    ]
    for x, y in node_positions:
        draw.ellipse(
            (x - node_radius, y - node_radius, x + node_radius, y + node_radius),
            fill=color,
        )


def create_symbol_asset(symbol_path: Path) -> None:
    size = 512
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    draw_symbol(
        shadow_draw,
        center_x=size / 2,
        center_y=size / 2,
        scale=size * 0.16,
        color=(46, 175, 193, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=16))
    image.alpha_composite(shadow)

    draw = ImageDraw.Draw(image)
    draw_symbol(
        draw,
        center_x=size / 2,
        center_y=size / 2,
        scale=size * 0.16,
        color=(255, 255, 255, 255),
    )
    image.save(symbol_path)


def create_app_icon(icon_path: Path) -> None:
    size = 1024
    image = rounded_gradient_background(size)

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (
            size * 0.22,
            size * 0.18,
            size * 0.78,
            size * 0.74,
        ),
        fill=(141, 245, 255, 56),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=48))
    image.alpha_composite(glow)

    draw = ImageDraw.Draw(image)
    symbol_scale = size * 0.19
    draw_symbol(
        draw,
        center_x=size / 2,
        center_y=size / 2,
        scale=symbol_scale,
        color=(242, 251, 252, 255),
    )

    orbit_color = (178, 244, 249, 150)
    orbit_width = 18
    draw.arc(
        (size * 0.18, size * 0.16, size * 0.82, size * 0.8),
        start=212,
        end=322,
        fill=orbit_color,
        width=orbit_width,
    )
    draw.arc(
        (size * 0.12, size * 0.28, size * 0.88, size * 0.9),
        start=22,
        end=132,
        fill=orbit_color,
        width=orbit_width,
    )

    image.save(icon_path)


def resize_android_icons(source_path: Path) -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    source = Image.open(source_path).convert("RGBA")
    for folder_name, size in sizes.items():
        target_path = ANDROID_RES_DIR / folder_name / "ic_launcher_roadsense.png"
        round_target_path = (
            ANDROID_RES_DIR / folder_name / "ic_launcher_roadsense_round.png"
        )
        resized = source.resize((size, size), Image.LANCZOS)
        resized.save(target_path)
        resized.save(round_target_path)


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)

    symbol_path = ASSET_DIR / "roadsense_symbol.png"
    icon_path = ASSET_DIR / "roadsense_app_icon.png"

    create_symbol_asset(symbol_path)
    create_app_icon(icon_path)
    resize_android_icons(icon_path)

    print(f"Generated: {symbol_path}")
    print(f"Generated: {icon_path}")


if __name__ == "__main__":
    main()
