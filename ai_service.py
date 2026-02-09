"""
URBAN 文案機器人 - AI 服務層 (Gemini 版)
封裝所有 Google Gemini API 呼叫：文案生成、Vision、圖片生成、字型推薦、演算法分析。
"""

import base64
import io
import json
import logging
import re
import time

from google import genai
from google.genai import types

import config

logger = logging.getLogger(__name__)

client = genai.Client(api_key=config.GEMINI_API_KEY)

# 圖片生成模型優先順序（第一個 503 就試下一個）
IMAGE_MODELS = [
    config.GEMINI_IMAGE_MODEL,                # gemini-2.5-flash-image (banana)
    "gemini-2.0-flash-exp-image-generation",  # 備用
]


def _call_image_model_with_retry(contents, response_modalities=None, max_retries=3):
    """
    帶自動重試 + 備用模型的圖片生成呼叫。
    503 overloaded 時會等待後重試，全部失敗再換模型。
    """
    modalities = response_modalities or ["IMAGE", "TEXT"]

    for model_name in IMAGE_MODELS:
        for attempt in range(max_retries):
            try:
                logger.info("圖片模型呼叫: %s (嘗試 %d/%d)", model_name, attempt + 1, max_retries)
                response = client.models.generate_content(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        response_modalities=modalities,
                    ),
                )
                return response
            except Exception as e:
                error_str = str(e)
                if "503" in error_str or "overloaded" in error_str.lower() or "unavailable" in error_str.lower():
                    wait_time = (attempt + 1) * 3  # 3s, 6s, 9s
                    logger.warning("模型 %s 過載 (503)，等待 %ds 後重試...", model_name, wait_time)
                    time.sleep(wait_time)
                    continue
                else:
                    # 非 503 錯誤直接拋出
                    raise

        logger.warning("模型 %s 重試 %d 次全部失敗，嘗試備用模型...", model_name, max_retries)

    raise ValueError("所有圖片生成模型都暫時過載，請稍後再試")

# ============================================================
# System Prompts — URBAN 品牌風格的靈魂
# ============================================================

VISION_SYSTEM_PROMPT = """你是 URBAN 團隊的資深社群行銷顧問。
你的專長是將日常生活照片轉化為有深度的財商觀點或吸引人的生活風格貼文。

【任務】
使用者會上傳一張照片。請分析照片內容，並撰寫四則社群內容（三則貼文 + 一則限時動態）。

【風格守則】
- 禁止推銷感：不要直接說「快來買保險」或「加入我們」。
- 吸引力法則：強調「選擇權」、「自律」、「長期主義」、「資產累積」。
- 口吻：像是朋友間的分享，帶點專業與溫暖。

【演算法優化 — 必須遵守】
- 每個文案結尾必須有一個「互動問句」（提高互動率 2-3 倍）
- 每個文案必須附上 5-8 個精準 Hashtag（混合大標籤和小標籤）
- 使用短句斷行，每句獨立一行（提高停留時間）
- 開頭第一句必須是金句或鉤子（降低滑走率）
- 文案長度控制在 150-300 字（IG 演算法最佳甜蜜點）

【輸出格式 — 嚴格 JSON】
你必須回傳純 JSON，不要包含 markdown code block，不要加任何前言或解釋。
格式如下：
{
  "options": [
    {
      "label": "A — 心情小語",
      "emoji": "📌",
      "description": "簡短有力，適合 IG/Threads 圖文配文",
      "content": "（在這裡寫文案，包含 Emoji，可直接貼上使用）"
    },
    {
      "label": "B — 財商觀點",
      "emoji": "📌",
      "description": "結合投資/理財觀念，適合專業形象",
      "content": "（3-5 句話的文案）"
    },
    {
      "label": "C — 幽默/生活",
      "emoji": "📌",
      "description": "輕鬆有趣，如果是貓或食物就強調努力工作就是為了這個",
      "content": "（文案內容）"
    },
    {
      "label": "D — 限時動態 Story",
      "emoji": "📱",
      "description": "IG Story 專用",
      "content": "主標語：（15字以內）\\n\\n互動設計：（投票/問答建議）\\n\\n建議功能：（Story貼紙/音樂推薦）"
    }
  ]
}

確保每個 content 欄位都是可以直接複製貼上到 IG / Threads 使用的完整文案。"""

TRENDING_CAPTION_SYSTEM_PROMPT = """你是一位精通 Instagram 和 Threads 的社群操盤手，同時也是 URBAN 團隊的內容顧問。
你必須隨時掌握社群最新動態和趨勢。

【任務】
使用者會給你一個主題。你需要模仿「此刻」Threads / Instagram 上最容易獲得高互動的貼文風格，
為這個主題撰寫三種不同風格的爆款文案，加上一套限動腳本。

【即時趨勢要求】
- 文案必須結合當下的時事、節日、季節感（現在是什麼季節就融入什麼元素）
- 參考近期 IG/Threads 上最火的話題格式和語感
- Hashtag 必須包含至少 1-2 個「當下正在流行」的趨勢標籤
- 如果主題可以和時下熱門話題掛鉤，一定要掛鉤（提高觸及率）

【演算法必勝技巧 — 全部文案必須遵守】
- 第一句就是金句鉤子（3秒內讓人停下來）
- 文案長度 150-300 字（IG 演算法甜蜜點）
- 結尾必須有互動問句（留言率 +200%）
- Hashtag 5-8 個，混合大標籤（>10萬）和精準小標籤（<1萬）
- 每句話獨立一行，製造「呼吸感」（提高停留時間）
- 善用分隔線：用「—」或「.」或空行來分段
- 包含至少一句「值得截圖分享」的金句（提高分享率）

【輸出格式 — 嚴格 JSON】
你必須回傳純 JSON，不要包含 markdown code block，不要加任何前言或解釋。
格式如下：
{
  "options": [
    {
      "label": "A — 金句體",
      "emoji": "🔥",
      "description": "適合 Threads 短文",
      "content": "（2-4 句金句組成，每句斷行，結尾帶反問，附上 Hashtag，可直接貼上使用）"
    },
    {
      "label": "B — 故事體",
      "emoji": "📖",
      "description": "適合 IG 圖文",
      "content": "（用「我曾經...」開頭的微故事，150字以內，結尾帶觀點，附 Hashtag，可直接貼上使用）"
    },
    {
      "label": "C — 清單體",
      "emoji": "📊",
      "description": "適合知識型帳號",
      "content": "（用「關於XX的3件事」格式，條列式呈現，附 Hashtag，可直接貼上使用）"
    },
    {
      "label": "D — Story 限動腳本",
      "emoji": "📱",
      "description": "IG Story 三頁腳本",
      "content": "第 1 頁：（主標語15字以內）\\n\\n第 2 頁：（互動設計建議文字）\\n\\n第 3 頁：（CTA引導語）\\n\\n建議搭配功能：（音樂/GIF/倒數計時器）"
    }
  ]
}

保持 URBAN 品牌調性：專業、溫暖、有選擇權的感覺。禁止推銷感。
確保每個 content 欄位都是可以直接複製貼上使用的完整文案。"""

IMAGE_GEN_SYSTEM_PROMPT = """你是一位極簡主義平面設計師。
使用者會提供一段文字概念。請根據這段文字的意境，直接生成一張圖片。

【視覺方向】
- 風格：Cinematic lighting, Minimalist, High-tech meets Warmth, Abstract geometry.
- 色調：深藍、黑、金、暖灰為主。
- 絕對避免：圖片中出現任何文字或字母、過於具象的人物臉部特寫、廉價的 3D 卡通感。
- 畫面要乾淨，適合作為社群貼文的背景圖。"""

BACKGROUND_REPLACE_SYSTEM_PROMPT = """你是一位頂尖的圖片合成大師，擅長將人物自然地融入新場景。

【核心任務】
使用者會上傳一張人物照片，並告訴你想要的新背景場景。
你需要將人物放入該場景中，生成一張看起來真實自然的照片。

【絕對禁止 — 最高優先級】
- 絕對不可以改變人物的臉部特徵、五官、膚色、表情
- 人臉必須與原照片100%一致，不可做任何美化、變形、風格化
- 不可改變人物的髮型、髮色

【人物比例規則 — 非常重要】
- 人物在新場景中的大小比例必須符合真實世界的透視關係
- 如果背景是寬闊的場景（如廣場、海灘、建築前），人物應該是「全身入鏡」，佔畫面約 30-50%
- 如果背景是近距離場景（如咖啡廳、室內），人物可以佔畫面 50-70%
- 絕對不要讓人物大到不合比例，像是巨人站在建築旁邊
- 請想像「如果真的有人站在這個場景拍照，攝影師會怎麼構圖」

【視覺品質規則】
- 人物的衣著、姿勢必須完整保留
- 新背景的光線方向要與人物身上的光影一致
- 畫質要高，至少像 iPhone 拍攝的品質
- 風格偏向 Cinematic、自然、有質感
- 要看起來像是真的在那個地方拍的照片"""

FONT_RECOMMEND_SYSTEM_PROMPT = """你是一位排版設計專家。

【任務】
使用者會提供一段文案和它的用途場景。
請根據文案的「語氣」和「情境」，從以下可用字型中推薦最適合的一款。

【可用字型】
{font_list}

【輸出規則】
只回傳字型的 key（例如 noto_sans_bold），不要加任何前言或解釋。
只回傳一個 key。"""

ALGORITHM_ANALYSIS_SYSTEM_PROMPT = """你是一位精通社群媒體演算法的數據分析師，專門研究 Instagram、Threads、Facebook 的推薦機制。

【任務】
使用者會給你一段文案（或一個貼文概念）。
請從「演算法友善度」的角度分析這段文案，並給出優化建議。

【輸出格式 — 嚴格 JSON】
你必須回傳純 JSON，不要包含 markdown code block，不要加任何前言或解釋。
格式如下：
{
  "score": 75,
  "sections": [
    {
      "label": "演算法總分",
      "emoji": "📊",
      "content": "75 / 100"
    },
    {
      "label": "互動誘發力",
      "emoji": "💬",
      "score": "18/25",
      "content": "（分析說明：是否有CTA？是否會引發留言、分享、收藏？）"
    },
    {
      "label": "停留時間",
      "emoji": "⏱",
      "score": "20/25",
      "content": "（分析說明：文案長度是否適中？是否有鉤子？排版是否容易閱讀？）"
    },
    {
      "label": "分享潛力",
      "emoji": "🔄",
      "score": "17/25",
      "content": "（分析說明：是否有金句值得截圖分享？是否觸及共鳴點？）"
    },
    {
      "label": "Hashtag & 觸及",
      "emoji": "🏷",
      "score": "20/25",
      "content": "（分析說明：Hashtag數量和品質分析）"
    },
    {
      "label": "優化建議",
      "emoji": "⚡",
      "content": "1. （第一條具體建議）\\n2. （第二條具體建議）\\n3. （第三條具體建議）"
    },
    {
      "label": "優化後版本",
      "emoji": "✨",
      "content": "（直接給出修改後的完整文案，可直接複製貼上使用）"
    },
    {
      "label": "發文時機建議",
      "emoji": "🕐",
      "content": "（建議最佳發文時段和星期幾）"
    }
  ]
}"""


# ============================================================
# JSON 回應解析器
# ============================================================

def _parse_json_response(text: str) -> dict:
    """
    從 Gemini 回應中提取 JSON，容忍 markdown code block 包裹。
    """
    # 移除 markdown code block
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # 移除開頭的 ```json 或 ```
        cleaned = re.sub(r'^```(?:json)?\s*\n?', '', cleaned)
        cleaned = re.sub(r'\n?```\s*$', '', cleaned)

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # 嘗試找到第一個 { 和最後一個 }
        start = cleaned.find('{')
        end = cleaned.rfind('}')
        if start != -1 and end != -1:
            try:
                return json.loads(cleaned[start:end + 1])
            except json.JSONDecodeError:
                pass

        logger.warning("無法解析 JSON 回應，回傳原始文字")
        return {"raw_text": text}


# ============================================================
# Mode 1: 圖片 → 文案 (Vision to Text)
# ============================================================

def generate_caption_from_image_base64(base64_data: str, mime_type: str = "image/jpeg") -> dict:
    """
    接收 base64 編碼的圖片，使用 Gemini Vision 分析並產生四種風格文案。
    回傳結構化 JSON dict。
    """
    logger.info("Gemini Vision 呼叫 - 分析圖片並生成文案")

    image_bytes = base64.b64decode(base64_data)

    response = client.models.generate_content(
        model=config.GEMINI_MODEL,
        contents=[
            types.Content(
                role="user",
                parts=[
                    types.Part(text=VISION_SYSTEM_PROMPT),
                    types.Part(text="請根據這張照片，幫我撰寫社群貼文。回傳純 JSON。"),
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                ],
            )
        ],
        config=types.GenerateContentConfig(
            temperature=0.8,
            max_output_tokens=2500,
        ),
    )

    return _parse_json_response(response.text)


# ============================================================
# Mode 2: 文字 → 圖片 (Text to Image via Gemini)
# ============================================================

def generate_image(user_text: str) -> tuple[bytes, str]:
    """
    使用 Gemini 的圖片生成能力，根據使用者的中文概念生成圖片。

    Returns:
        (image_bytes, description) - 圖片二進位資料與描述
    """
    logger.info("Gemini 圖片生成 - 概念: %s", user_text)

    prompt = (
        f"{IMAGE_GEN_SYSTEM_PROMPT}\n\n"
        f"使用者的概念：{user_text}\n\n"
        f"請生成一張符合上述風格的圖片。"
    )

    response = _call_image_model_with_retry(contents=prompt)

    # 從回應中提取圖片
    image_bytes = None
    description = ""

    for part in response.candidates[0].content.parts:
        if part.inline_data is not None:
            image_bytes = part.inline_data.data
        elif part.text is not None:
            description = part.text

    if image_bytes is None:
        raise ValueError("Gemini 未回傳圖片，請稍後再試")

    return image_bytes, description


# ============================================================
# Mode 2B: 人物照 → 背景替換 (Person + New Background)
# ============================================================

def replace_background(base64_data: str, scene: str, mime_type: str = "image/jpeg") -> tuple[bytes, str]:
    """
    保留照片中的人物，替換背景為指定場景。

    Returns:
        (image_bytes, description) - 圖片二進位資料與描述
    """
    logger.info("背景替換 - 場景: %s", scene)

    image_bytes = base64.b64decode(base64_data)

    prompt_text = (
        f"{BACKGROUND_REPLACE_SYSTEM_PROMPT}\n\n"
        f"使用者想要的新背景場景：{scene}\n\n"
        f"請保留照片中的人物，將背景替換為上述場景，生成一張新圖片。"
    )

    contents = [
        types.Content(
            role="user",
            parts=[
                types.Part(text=prompt_text),
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            ],
        )
    ]

    response = _call_image_model_with_retry(contents=contents)

    result_image_bytes = None
    description = ""

    for part in response.candidates[0].content.parts:
        if part.inline_data is not None:
            result_image_bytes = part.inline_data.data
        elif part.text is not None:
            description = part.text

    if result_image_bytes is None:
        raise ValueError("Gemini 未回傳圖片，請稍後再試")

    return result_image_bytes, description


# ============================================================
# Mode 3: AI 排版設計（時尚雜誌封面風格）
# ============================================================

DESIGN_SYSTEM_PROMPT = """你是一位頂尖的時尚雜誌封面設計師和字體排版大師。

【任務】
使用者會上傳一張圖片，並提供一段要放在圖片上的文字。
請將這段文字以「時尚雜誌封面」的排版風格，設計到圖片上，生成一張全新的設計圖。

【設計風格 — 參考 Vogue、ELLE、GQ 等時尚雜誌封面】
- 文字排版要有層次感：主標題大而粗、副標題小而細
- 字體位置要有設計感：不一定要在正中間，可以在左下、右上等
- 善用留白：不要把文字塞滿，要有呼吸空間
- 使用對比色：深色底配白/金文字，淺色底配黑/深色文字
- 可以加入簡約的裝飾元素（細線、點、幾何圖形）
- 整體風格要：高級、時髦、有質感、吸引目光

【文字排版規則】
- 中文字體要清晰可讀，大小適中
- 文字必須完全融入設計，像是原本就在圖片上的
- 如果文字較長，自動拆成主標語 + 小字副標
- 右下角加上小字「URBAN」品牌標

【絕對禁止】
- 不要改變原圖中人物的臉部和外觀
- 不要生成與原圖完全不同的新圖
- 不要讓文字擋住圖片中的主要人物臉部"""


def design_with_ai(base64_data: str, text: str, mime_type: str = "image/jpeg") -> tuple[bytes, str]:
    """
    用 Gemini 圖片模型直接做時尚雜誌風格排版設計。

    Returns:
        (image_bytes, description) - 設計後的圖片和描述
    """
    logger.info("AI 排版設計 - 文字: %s", text[:30])

    image_bytes = base64.b64decode(base64_data)

    prompt_text = (
        f"{DESIGN_SYSTEM_PROMPT}\n\n"
        f"要放在圖片上的文字：「{text}」\n\n"
        f"請將這段文字以時尚雜誌封面的風格排版到圖片上，生成一張設計圖。"
    )

    contents = [
        types.Content(
            role="user",
            parts=[
                types.Part(text=prompt_text),
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            ],
        )
    ]

    response = _call_image_model_with_retry(contents=contents)

    result_image_bytes = None
    description = ""

    for part in response.candidates[0].content.parts:
        if part.inline_data is not None:
            result_image_bytes = part.inline_data.data
        elif part.text is not None:
            description = part.text

    if result_image_bytes is None:
        raise ValueError("Gemini 未回傳圖片，請稍後再試")

    return result_image_bytes, description


# ============================================================
# Mode 4: 熱門風格文案 (Trending Caption Generator)
# ============================================================

def generate_trending_caption(topic: str) -> dict:
    """
    模仿 Threads/IG 熱門貼文風格，根據主題生成爆款文案 + Story 腳本。
    回傳結構化 JSON dict。
    """
    logger.info("熱門風格文案生成 - 主題: %s", topic)

    response = client.models.generate_content(
        model=config.GEMINI_MODEL,
        contents=f"{TRENDING_CAPTION_SYSTEM_PROMPT}\n\n主題：{topic}\n\n請回傳純 JSON。",
        config=types.GenerateContentConfig(
            temperature=0.9,
            max_output_tokens=2500,
        ),
    )

    return _parse_json_response(response.text)


# ============================================================
# Mode 5: 演算法分析 (Algorithm Score & Optimization)
# ============================================================

def analyze_algorithm_score(caption_text: str) -> dict:
    """
    分析一段文案的「演算法友善度」，從互動率、停留時間、分享潛力、
    Hashtag 觸及四個維度評分，並給出優化版本。
    回傳結構化 JSON dict。
    """
    logger.info("演算法分析 - 文案長度: %d", len(caption_text))

    response = client.models.generate_content(
        model=config.GEMINI_MODEL,
        contents=f"{ALGORITHM_ANALYSIS_SYSTEM_PROMPT}\n\n請分析以下文案：\n\n{caption_text}\n\n請回傳純 JSON。",
        config=types.GenerateContentConfig(
            temperature=0.5,
            max_output_tokens=2500,
        ),
    )

    return _parse_json_response(response.text)


# ============================================================
# 字型推薦 (AI Font Recommendation)
# ============================================================

def recommend_font(caption_text: str, scene: str = "社群貼文") -> str:
    """
    根據文案內容和使用場景，AI 推薦最適合的字型。
    """
    font_list = "\n".join(
        f"- {key}: {info['name']}（風格：{info['style']}，適合：{info['best_for']}）"
        for key, info in config.AVAILABLE_FONTS.items()
    )

    system_prompt = FONT_RECOMMEND_SYSTEM_PROMPT.format(font_list=font_list)

    response = client.models.generate_content(
        model=config.GEMINI_MODEL,
        contents=f"{system_prompt}\n\n文案：{caption_text}\n場景：{scene}",
        config=types.GenerateContentConfig(
            temperature=0.2,
            max_output_tokens=50,
        ),
    )

    recommended_key = response.text.strip().lower()

    if recommended_key not in config.AVAILABLE_FONTS:
        logger.warning("AI 推薦了無效的字型 key: %s，使用預設", recommended_key)
        return "noto_sans_bold"

    logger.info("AI 推薦字型: %s (%s)", recommended_key, config.AVAILABLE_FONTS[recommended_key]["name"])
    return recommended_key


# ============================================================
# Mode 3 輔助: 為合成圖片生成短文案
# ============================================================

def generate_short_caption(user_text: str) -> str:
    """
    將長文案精煉為適合放在圖片上的短標語（不超過 30 字）。
    """
    response = client.models.generate_content(
        model=config.GEMINI_MODEL,
        contents=(
            "你是文案精煉大師。請將使用者的文字濃縮為一句適合放在圖片上的標語，"
            "不超過 30 個中文字。保持 URBAN 品牌的專業、溫暖、有深度的風格。"
            "只回傳精煉後的文字，不要加任何前言。\n\n"
            f"{user_text}"
        ),
        config=types.GenerateContentConfig(
            temperature=0.6,
            max_output_tokens=100,
        ),
    )

    return response.text.strip()
