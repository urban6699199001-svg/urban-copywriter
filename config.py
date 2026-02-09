"""
URBAN 文案機器人 - 集中式設定檔
"""

import os
from dotenv import load_dotenv

load_dotenv()

# --- Google Gemini API ---
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
GEMINI_IMAGE_MODEL = os.getenv("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")

# --- 圖片處理預設 ---
OVERLAY_OPACITY = 180          # 半透明遮罩 (0-255)
OVERLAY_HEIGHT_RATIO = 0.35    # 遮罩佔圖片高度比例
TEXT_PADDING = 40              # 文字邊距 (px)
FONT_SIZE = 42                 # 預設字體大小
OUTPUT_QUALITY = 92            # JPEG 壓縮品質

# --- 中文字型設定 ---
FONTS_DIR = os.path.join(os.path.dirname(__file__), "fonts")

AVAILABLE_FONTS = {
    "noto_sans": {
        "name": "Noto Sans TC",
        "file": "NotoSansTC-Variable.ttf",
        "style": "現代、乾淨、專業",
        "best_for": "財商觀點、專業形象、清單體、長文",
    },
    "noto_serif": {
        "name": "Noto Serif TC",
        "file": "NotoSerifTC-Variable.ttf",
        "style": "典雅、文藝、有質感",
        "best_for": "金句、心靈雞湯、文青風、限動標語",
    },
}

# 系統備用字型
SYSTEM_FONT_FALLBACKS = [
    "/System/Library/Fonts/PingFang.ttc",                        # macOS
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",       # Ubuntu/Debian
    "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",           # Arch/Fedora
]
