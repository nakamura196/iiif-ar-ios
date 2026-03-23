#!/usr/bin/env python3
"""
Generate marketing screenshots for IIIF AR App Store listing.
Creates promotional images with gradient backgrounds, device frames,
and headline text from raw device screenshots.

Since IIIF AR is an AR app, screenshots must be captured on a real device
(the iOS Simulator does not support ARKit). This script takes those raw
screenshots and composites them into App Store-ready marketing images.

Usage:
    python3 scripts/generate_marketing_screenshots.py --input-dir raw_screenshots --output-dir marketing
    python3 scripts/generate_marketing_screenshots.py --input-dir raw_screenshots --lang ja
    python3 scripts/generate_marketing_screenshots.py --help

Requirements:
    pip install Pillow
"""

import argparse
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# --- Constants ---

IPHONE_SIZE = (1290, 2796)  # iPhone 6.7"
IPAD_SIZE = (2048, 2732)    # iPad 12.9"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

# Font paths (macOS)
FONT_BOLD_JA = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_REGULAR_JA = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
FONT_BOLD_EN = "/System/Library/Fonts/Helvetica.ttc"
FONT_REGULAR_EN = "/System/Library/Fonts/Helvetica.ttc"

# Warm cream-to-gold gradient matching the app's historical map theme
BG_CREAM = (245, 235, 218)   # warm cream (top)
BG_GOLD = (191, 155, 84)     # antique gold (bottom)

# Themes per language — each theme is paired with one screenshot
THEMES_JA = [
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "歴史的絵図をARで実寸体験",
    },
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "近づくと細部が見える",
    },
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "IIIFで世界の資料にアクセス",
    },
]

THEMES_EN = [
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "Experience Historical Maps at Real Scale",
    },
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "Zoom in for Fine Detail",
    },
    {
        "bg_top": BG_CREAM,
        "bg_bottom": BG_GOLD,
        "headline": "Access Collections via IIIF",
    },
]

# Text color: dark brown for legibility on the warm background
TEXT_COLOR = (62, 39, 12)
TEXT_COLOR_FADED = (62, 39, 12, 200)


# --- Helper functions ---

def create_gradient(size, color_top, color_bottom):
    """Create a vertical gradient image."""
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    w, h = size
    for y in range(h):
        ratio = y / h
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * ratio)
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * ratio)
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * ratio)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def add_rounded_corners(img, radius):
    """Add rounded corners to an image."""
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result


def add_device_frame(screenshot, corner_radius, is_ipad=False):
    """Add a dark device frame (bezel) around the screenshot."""
    bezel = int(corner_radius * 0.35)
    frame_radius = corner_radius + bezel

    frame_w = screenshot.width + bezel * 2
    frame_h = screenshot.height + bezel * 2

    # Create frame with dark bezel
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)

    # Outer bezel (dark)
    frame_draw.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=frame_radius,
        fill=(30, 30, 30, 255),
    )

    # Subtle inner-edge highlight
    frame_draw.rounded_rectangle(
        [(bezel - 1, bezel - 1), (frame_w - bezel, frame_h - bezel)],
        radius=corner_radius + 1,
        fill=(50, 50, 50, 255),
    )

    # Paste screenshot inside
    frame.paste(screenshot, (bezel, bezel), screenshot)
    return frame


def add_shadow(img, offset=(0, 20), blur_radius=40, shadow_color=(0, 0, 0, 80)):
    """Add a drop shadow to an image with alpha channel."""
    total_w = img.width + abs(offset[0]) + blur_radius * 2
    total_h = img.height + abs(offset[1]) + blur_radius * 2

    shadow = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    shadow_base = Image.new("RGBA", img.size, shadow_color)
    if img.mode == "RGBA":
        shadow_base.putalpha(img.split()[3])
    shadow.paste(
        shadow_base,
        (blur_radius + max(offset[0], 0), blur_radius + max(offset[1], 0)),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))
    shadow.paste(
        img,
        (blur_radius + max(-offset[0], 0), blur_radius + max(-offset[1], 0)),
        img if img.mode == "RGBA" else None,
    )
    return shadow


# --- Main compositing ---

def create_marketing_image(screenshot_path, theme, output_size, lang="ja"):
    """Create a single marketing screenshot with gradient, frame, and headline."""
    w, h = output_size
    is_ipad = w / h > 0.6  # iPad ~0.75, iPhone ~0.46

    # Device-specific sizing
    if is_ipad:
        headline_font_pct = 0.055
        max_scale_w_pct = 0.82
        bleed_fraction = 0.35
    else:
        headline_font_pct = 0.065
        max_scale_w_pct = 0.88
        bleed_fraction = 0.35

    # Language-specific fonts
    if lang == "en":
        font_bold_path = FONT_BOLD_EN
    else:
        font_bold_path = FONT_BOLD_JA

    # Create gradient background
    bg = create_gradient(output_size, theme["bg_top"], theme["bg_bottom"])
    bg = bg.convert("RGBA")

    # --- Text layout ---
    try:
        font_headline = ImageFont.truetype(font_bold_path, int(w * headline_font_pct))
    except OSError:
        print(f"  Warning: Could not load font {font_bold_path}, using default")
        font_headline = ImageFont.load_default()

    draw = ImageDraw.Draw(bg)

    headline = theme["headline"]
    headline_bbox = draw.textbbox((0, 0), headline, font=font_headline)
    headline_h = headline_bbox[3] - headline_bbox[1]
    headline_w = headline_bbox[2] - headline_bbox[0]

    headline_y = int(h * 0.10)
    headline_x = (w - headline_w) // 2
    text_bottom = headline_y + headline_h

    # --- Load and scale screenshot ---
    screenshot = Image.open(screenshot_path).convert("RGBA")

    ss_y = text_bottom + int(h * 0.03)
    desired_visible_h = h - ss_y
    desired_total_h = desired_visible_h / (1.0 - bleed_fraction)
    scale_factor = desired_total_h / screenshot.height
    scale_w = int(screenshot.width * scale_factor)
    scale_h = int(screenshot.height * scale_factor)

    # Cap width
    max_w = int(w * max_scale_w_pct)
    if scale_w > max_w:
        scale_w = max_w
        scale_h = int(screenshot.height * (scale_w / screenshot.width))

    screenshot = screenshot.resize((scale_w, scale_h), Image.LANCZOS)

    corner_radius = int(scale_w * 0.05)
    screenshot = add_rounded_corners(screenshot, corner_radius)

    # Add device frame (dark bezel)
    framed = add_device_frame(screenshot, corner_radius, is_ipad=is_ipad)

    # Add drop shadow
    framed = add_shadow(framed, offset=(0, 16), blur_radius=30,
                        shadow_color=(0, 0, 0, 60))

    # Position: centered horizontally, below text with breathing room
    ss_x = (w - framed.width) // 2
    ss_y = ss_y + int(h * 0.06)

    bg.paste(framed, (ss_x, ss_y), framed)

    # --- Draw headline text ---
    draw = ImageDraw.Draw(bg)
    draw.text((headline_x, headline_y), headline, fill=TEXT_COLOR, font=font_headline)

    # Convert to RGB for saving as PNG
    final = Image.new("RGB", output_size, (0, 0, 0))
    final.paste(bg, (0, 0), bg)
    return final


def find_screenshots(input_dir, count=3):
    """Find PNG screenshots in directory, sorted alphabetically, up to count."""
    if not os.path.isdir(input_dir):
        return []
    all_files = sorted(
        f for f in os.listdir(input_dir)
        if f.lower().endswith((".png", ".jpg", ".jpeg"))
    )
    return [os.path.join(input_dir, f) for f in all_files[:count]]


def generate_for_device(screenshots, themes, output_size, device_name, output_dir, lang):
    """Generate marketing images for one device type."""
    for i, (ss_path, theme) in enumerate(zip(screenshots, themes)):
        fname = f"marketing_{i + 1:02d}_{device_name}.png"
        output_path = os.path.join(output_dir, fname)
        print(f"  Generating {fname} ...")
        img = create_marketing_image(ss_path, theme, output_size, lang=lang)
        img.save(output_path, "PNG")
        print(f"    Saved: {output_path} ({img.size[0]}x{img.size[1]})")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate App Store marketing screenshots for IIIF AR.\n\n"
            "Takes raw device screenshots (captured on a real device, since AR "
            "requires hardware) and composites them into marketing images with "
            "gradient backgrounds, device frames, and headline text."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  %(prog)s --input-dir raw_screenshots\n"
            "  %(prog)s --input-dir raw_screenshots --output-dir marketing --lang ja\n"
            "  %(prog)s --input-dir iphone_shots --input-dir-ipad ipad_shots\n"
        ),
    )
    parser.add_argument(
        "--input-dir",
        default=os.path.join(PROJECT_DIR, "screenshots", "raw"),
        help="Directory with raw iPhone screenshots (default: screenshots/raw/)",
    )
    parser.add_argument(
        "--input-dir-ipad",
        default=None,
        help="Directory with raw iPad screenshots (defaults to --input-dir)",
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(PROJECT_DIR, "screenshots", "marketing"),
        help="Output directory for marketing images (default: screenshots/marketing/)",
    )
    parser.add_argument(
        "--lang",
        default=None,
        choices=["ja", "en"],
        help="Generate for a single language (default: both ja and en)",
    )
    args = parser.parse_args()

    # Locate screenshots
    iphone_screenshots = find_screenshots(args.input_dir)
    if len(iphone_screenshots) == 0:
        print(f"Error: No screenshots found in {args.input_dir}")
        print("Capture screenshots on a real device (AR requires hardware) and place them there.")
        sys.exit(1)
    if len(iphone_screenshots) < 3:
        print(f"Warning: Found only {len(iphone_screenshots)} screenshot(s) in {args.input_dir} (3 recommended)")

    print(f"iPhone screenshots ({len(iphone_screenshots)}):")
    for s in iphone_screenshots:
        print(f"  {os.path.basename(s)}")

    ipad_dir = args.input_dir_ipad or args.input_dir
    ipad_screenshots = find_screenshots(ipad_dir)
    if ipad_screenshots:
        print(f"iPad screenshots ({len(ipad_screenshots)}):")
        for s in ipad_screenshots:
            print(f"  {os.path.basename(s)}")

    # Generate for each language
    langs = [args.lang] if args.lang else ["ja", "en"]
    for lang in langs:
        themes = THEMES_JA if lang == "ja" else THEMES_EN
        lang_output = os.path.join(args.output_dir, lang)
        os.makedirs(lang_output, exist_ok=True)
        print(f"\n=== {lang.upper()} ===")

        # iPhone 6.7"
        print(f"  iPhone 6.7\" ({IPHONE_SIZE[0]}x{IPHONE_SIZE[1]})")
        generate_for_device(iphone_screenshots, themes, IPHONE_SIZE, "iphone", lang_output, lang)

        # iPad 12.9"
        if ipad_screenshots:
            print(f"  iPad 12.9\" ({IPAD_SIZE[0]}x{IPAD_SIZE[1]})")
            generate_for_device(ipad_screenshots, themes, IPAD_SIZE, "ipad", lang_output, lang)

    print(f"\nDone! Marketing screenshots saved to {args.output_dir}")


if __name__ == "__main__":
    main()
