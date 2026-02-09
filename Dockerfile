FROM python:3.13-slim

# 設定工作目錄
WORKDIR /app

# 安裝系統依賴（Pillow 需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

# 複製 requirements 先安裝（利用 Docker cache）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用程式碼
COPY config.py .
COPY ai_service.py .
COPY app.py .
COPY image_utils.py .

# 複製字型
COPY fonts/ fonts/

# Cloud Run 使用 PORT 環境變數
ENV PORT=8080

# 用 gunicorn 啟動（生產環境）
CMD exec gunicorn --bind :$PORT --workers 2 --threads 4 --timeout 120 app:app
