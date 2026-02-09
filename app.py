"""
URBAN 文案機器人 - REST API 後端
供 iOS App 呼叫的 API 服務。

啟動方式:
    cp .env.example .env  (填入 GEMINI_API_KEY)
    source venv/bin/activate
    python app.py
"""

import base64
import logging
import os

from flask import Flask, request, jsonify

import config
import ai_service
import image_utils

# ============================================================
# 初始化
# ============================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)


# ============================================================
# Health Check
# ============================================================

@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "URBAN 文案機器人"})


# ============================================================
# Mode 1: 圖片 → 文案 (結構化 JSON)
# ============================================================

@app.route("/api/v1/caption-from-image", methods=["POST"])
def api_caption_from_image():
    data = request.get_json()
    if not data or "image_base64" not in data:
        return jsonify({"error": "缺少 image_base64 欄位"}), 400

    try:
        mime_type = data.get("mime_type", "image/jpeg")
        result = ai_service.generate_caption_from_image_base64(
            data["image_base64"], mime_type
        )

        if "raw_text" in result:
            return jsonify({
                "options": [{
                    "label": "AI 生成文案",
                    "emoji": "📝",
                    "description": "完整文案",
                    "content": result["raw_text"]
                }]
            })

        return jsonify(result)
    except Exception as e:
        logger.error("caption-from-image 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# Mode 2: 文字 → 圖片
# ============================================================

@app.route("/api/v1/generate-image", methods=["POST"])
def api_generate_image():
    data = request.get_json()
    if not data or "concept" not in data:
        return jsonify({"error": "缺少 concept 欄位"}), 400

    try:
        image_bytes, description = ai_service.generate_image(data["concept"])
        image_base64 = base64.b64encode(image_bytes).decode("utf-8")
        return jsonify({
            "image_base64": image_base64,
            "description": description,
        })
    except Exception as e:
        logger.error("generate-image 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# Mode 2B: 人物照 + 背景替換
# ============================================================

@app.route("/api/v1/replace-background", methods=["POST"])
def api_replace_background():
    data = request.get_json()
    if not data or "image_base64" not in data or "scene" not in data:
        return jsonify({"error": "缺少 image_base64 或 scene 欄位"}), 400

    try:
        mime_type = data.get("mime_type", "image/jpeg")
        image_bytes, description = ai_service.replace_background(
            data["image_base64"], data["scene"], mime_type
        )
        image_base64 = base64.b64encode(image_bytes).decode("utf-8")
        return jsonify({
            "image_base64": image_base64,
            "description": description,
        })
    except Exception as e:
        logger.error("replace-background 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# Mode 3: 圖片 + 文字 → 排版合成
# ============================================================

@app.route("/api/v1/design", methods=["POST"])
def api_design():
    data = request.get_json()
    if not data or "image_base64" not in data or "text" not in data:
        return jsonify({"error": "缺少 image_base64 或 text 欄位"}), 400

    try:
        caption_text = data["text"]

        # 太長的文案先精煉
        if len(caption_text) > 30:
            caption_text = ai_service.generate_short_caption(caption_text)

        # 用 Gemini 圖片模型直接做時尚雜誌風排版
        mime_type = data.get("mime_type", "image/jpeg")
        result_bytes, description = ai_service.design_with_ai(
            data["image_base64"], caption_text, mime_type
        )

        result_base64 = base64.b64encode(result_bytes).decode("utf-8")
        return jsonify({
            "image_base64": result_base64,
            "text_used": caption_text,
            "font_used": "AI 時尚排版",
            "font_key": "ai_design",
        })
    except Exception as e:
        logger.error("design 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# Mode 4: 熱門風格文案 (結構化 JSON)
# ============================================================

@app.route("/api/v1/trending", methods=["POST"])
def api_trending():
    data = request.get_json()
    if not data or "topic" not in data:
        return jsonify({"error": "缺少 topic 欄位"}), 400

    try:
        result = ai_service.generate_trending_caption(data["topic"])

        if "raw_text" in result:
            return jsonify({
                "options": [{
                    "label": "熱門文案",
                    "emoji": "🔥",
                    "description": "完整文案",
                    "content": result["raw_text"]
                }]
            })

        return jsonify(result)
    except Exception as e:
        logger.error("trending 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# Mode 5: 演算法分析 (結構化 JSON)
# ============================================================

@app.route("/api/v1/algorithm", methods=["POST"])
def api_algorithm():
    data = request.get_json()
    if not data or "caption" not in data:
        return jsonify({"error": "缺少 caption 欄位"}), 400

    try:
        result = ai_service.analyze_algorithm_score(data["caption"])

        if "raw_text" in result:
            return jsonify({
                "score": 0,
                "sections": [{
                    "label": "分析結果",
                    "emoji": "📊",
                    "content": result["raw_text"]
                }]
            })

        return jsonify(result)
    except Exception as e:
        logger.error("algorithm 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# 字型推薦
# ============================================================

@app.route("/api/v1/recommend-font", methods=["POST"])
def api_recommend_font():
    data = request.get_json()
    if not data or "text" not in data:
        return jsonify({"error": "缺少 text 欄位"}), 400

    try:
        scene = data.get("scene", "社群貼文")
        font_key = ai_service.recommend_font(data["text"], scene)
        font_info = config.AVAILABLE_FONTS.get(font_key, {})
        return jsonify({
            "font_key": font_key,
            "font_name": font_info.get("name", "未知"),
            "font_style": font_info.get("style", ""),
            "best_for": font_info.get("best_for", ""),
        })
    except Exception as e:
        logger.error("recommend-font 錯誤: %s", e, exc_info=True)
        return jsonify({"error": str(e)}), 500


# ============================================================
# 啟動
# ============================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info("URBAN 文案機器人 API 啟動 - port %d", port)
    app.run(host="0.0.0.0", port=port, debug=True)
