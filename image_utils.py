"""
URBAN 文案機器人 - 圖片處理工具 (Premium Edition v2)
使用 Pillow 在圖片上疊加高級感排版設計。
動態字體大小 — 根據圖片尺寸自動調整，確保大圖小圖都清晰。
"""

import io
import logging
import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

import config

logger = logging.getLogger(__name__)


def _load_font(font_key: str | None, size: int) -> ImageFont.FreeTypeFont:
    """根據字型 key 載入對應字型檔。"""
    if font_key and font_key in config.AVAILABLE_FONTS:
        font_info = config.AVAILABLE_FONTS[font_key]
        font_path = os.path.join(config.FONTS_DIR, font_info["file"])
        try:
            font = ImageFont.truetype(font_path, size)
            logger.info("載入 AI 推薦字型: %s (size=%d)", font_info["name"], size)
            return font
        except (OSError, IOError):
            logger.warning("找不到字型檔: %s，嘗試備用字型", font_path)

    for path in config.SYSTEM_FONT_FALLBACKS:
        try:
            font = ImageFont.truetype(path, size)
            logger.info("使用系統備用字型: %s (size=%d)", path, size)
            return font
        except (OSError, IOError):
            continue

    logger.warning("找不到任何中文字型，使用預設字型")
    return ImageFont.load_default()


def _calc_dynamic_font_size(img_width: int, img_height: int, text_len: int) -> int:
    """
    根據圖片尺寸和文字長度，動態計算最適合的字體大小。

    iPhone 照片通常 3000-4000px，IG 用圖通常 1080px。
    - 寬度 1080px → 字體 ~60px
    - 寬度 3000px → 字體 ~140px
    - 寬度 4000px → 字體 ~180px
    """
    # 基準：圖片寬度的 4.5%，確保視覺衝擊力
    base_size = int(img_width * 0.045)

    # 如果文字很短（< 8字），字體可以更大
    if text_len <= 6:
        base_size = int(img_width * 0.07)
    elif text_len <= 12:
        base_size = int(img_width * 0.055)

    # 限制範圍
    return max(48, min(base_size, 250))


def _wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """將文字依照字型實際渲染寬度自動換行。"""
    lines = []
    for paragraph in text.split("\n"):
        if not paragraph.strip():
            lines.append("")
            continue

        current_line = ""
        for char in paragraph:
            test_line = current_line + char
            bbox = font.getbbox(test_line)
            line_width = bbox[2] - bbox[0]
            if line_width <= max_width:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = char
        if current_line:
            lines.append(current_line)

    return lines


def overlay_text_on_image(
    image_bytes: bytes,
    text: str,
    font_key: str | None = None,
    font_size: int | None = None,
    overlay_opacity: int | None = None,
) -> bytes:
    """
    在圖片上疊加高級感排版設計。

    特色：
    - 動態字體大小（根據圖片解析度自動調整）
    - 底部漸層遮罩
    - 左側金色粗裝飾線
    - 文字帶陰影和描邊效果
    - 品牌浮水印
    - 右上角幾何裝飾
    """
    overlay_opacity = overlay_opacity or config.OVERLAY_OPACITY

    img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    img_width, img_height = img.size

    # === 動態計算字體大小 ===
    if font_size is None:
        font_size = _calc_dynamic_font_size(img_width, img_height, len(text))

    logger.info("圖片尺寸: %dx%d, 動態字體大小: %dpx, 文字: %s",
                img_width, img_height, font_size, text[:20])

    # === 步驟 1: 底部輕微模糊 ===
    blur_mask = Image.new("L", img.size, 0)
    blur_draw = ImageDraw.Draw(blur_mask)
    blur_start = int(img_height * 0.50)
    blur_radius = max(3, img_width // 500)
    for y in range(blur_start, img_height):
        alpha = int(((y - blur_start) / (img_height - blur_start)) * 80)
        blur_draw.line([(0, y), (img_width, y)], fill=alpha)

    blurred = img.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    img = Image.composite(blurred, img, blur_mask)

    # === 步驟 2: 漸層遮罩（從透明到深色）===
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    gradient_start = int(img_height * 0.30)
    for y in range(gradient_start, img_height):
        progress = (y - gradient_start) / (img_height - gradient_start)
        eased = progress * progress * progress
        alpha = int(eased * 220)
        draw.line([(0, y), (img_width, y)], fill=(8, 10, 25, alpha))

    img = Image.alpha_composite(img, overlay)

    # === 步驟 3: 載入字型並排版文字 ===
    main_font = _load_font(font_key, font_size)

    margin_left = int(img_width * 0.08)
    margin_right = int(img_width * 0.08)
    text_max_width = img_width - margin_left - margin_right
    wrapped_lines = _wrap_text(text, main_font, text_max_width)

    line_height = int(font_size * 1.5)
    total_text_height = line_height * len(wrapped_lines)

    # 文字位置：底部往上推
    text_bottom_margin = int(img_height * 0.07)
    y_start = img_height - text_bottom_margin - total_text_height

    # === 步驟 4: 左側金色粗裝飾線 ===
    accent_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accent_layer)

    bar_width = max(5, img_width // 200)  # 動態粗細
    line_x = margin_left - int(img_width * 0.035)
    gold_color = (215, 175, 85, 220)

    # 主豎線
    accent_draw.rectangle(
        [(line_x, y_start), (line_x + bar_width, y_start + total_text_height)],
        fill=gold_color,
    )

    # 頂部金色小方塊
    block_size = bar_width * 3
    accent_draw.rectangle(
        [(line_x - bar_width, y_start - block_size - bar_width),
         (line_x + block_size, y_start - bar_width)],
        fill=gold_color,
    )

    img = Image.alpha_composite(img, accent_layer)

    # === 步驟 5: 繪製文字（描邊 + 陰影 + 主文字）===
    text_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)

    shadow_offset = max(3, font_size // 20)
    stroke_width = max(2, font_size // 30)

    y_cursor = y_start
    for line in wrapped_lines:
        if y_cursor + line_height > img_height - 20:
            break

        # 文字陰影（偏移更大）
        text_draw.text(
            (margin_left + shadow_offset, y_cursor + shadow_offset),
            line,
            font=main_font,
            fill=(0, 0, 0, 100),
        )

        # 文字描邊（增加可讀性）
        text_draw.text(
            (margin_left, y_cursor),
            line,
            font=main_font,
            fill=(255, 255, 255, 255),
            stroke_width=stroke_width,
            stroke_fill=(0, 0, 0, 160),
        )

        y_cursor += line_height

    img = Image.alpha_composite(img, text_layer)

    # === 步驟 6: 右下角品牌標記 ===
    brand_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    brand_draw = ImageDraw.Draw(brand_layer)

    brand_font_size = max(font_size // 2, 28)
    brand_font = _load_font(None, brand_font_size)
    brand_text = "URBAN"
    brand_bbox = brand_font.getbbox(brand_text)
    brand_w = brand_bbox[2] - brand_bbox[0]

    brand_x = img_width - margin_right - brand_w
    brand_y = img_height - int(img_height * 0.035)

    brand_draw.text(
        (brand_x, brand_y),
        brand_text,
        font=brand_font,
        fill=(215, 175, 85, 150),
    )

    img = Image.alpha_composite(img, brand_layer)

    # === 步驟 7: 右上角幾何裝飾線 ===
    deco_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    deco_draw = ImageDraw.Draw(deco_layer)

    corner_margin = int(img_width * 0.05)
    line_len = int(img_width * 0.12)
    deco_line_width = max(2, img_width // 500)

    deco_draw.line(
        [(img_width - corner_margin, corner_margin),
         (img_width - corner_margin, corner_margin + line_len)],
        fill=(215, 175, 85, 100),
        width=deco_line_width,
    )
    deco_draw.line(
        [(img_width - corner_margin, corner_margin),
         (img_width - corner_margin - line_len, corner_margin)],
        fill=(215, 175, 85, 100),
        width=deco_line_width,
    )

    img = Image.alpha_composite(img, deco_layer)

    # === 輸出 ===
    result_rgb = img.convert("RGB")
    output = io.BytesIO()
    result_rgb.save(output, format="JPEG", quality=95)
    output.seek(0)

    font_name = config.AVAILABLE_FONTS.get(font_key, {}).get("name", "系統預設")
    logger.info("排版合成完成 - 尺寸: %dx%d, 字型: %s, 字體大小: %dpx, 行數: %d",
                img_width, img_height, font_name, font_size, len(wrapped_lines))
    return output.read()
