# ═══════════════════════════════════════════════════════════════════
# CP2 — Image production-ready cho chat service.
#
# Hai stage: `builder` cài dependency (được phép nặng, sẽ bị vứt đi),
# `runtime` chỉ nhận kết quả đã cài — image cuối không mang theo compiler
# và cache của pip.
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: cài dependency ────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# COPY requirements.txt riêng, TRƯỚC khi copy source: Docker huỷ cache từ
# layer đầu tiên thay đổi trở đi, nên sửa code không làm cài lại thư viện.
COPY requirements.txt .

# --prefix=/install gom toàn bộ thư viện vào một thư mục để stage sau copy sang.
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: image chạy thật ───────────────────────────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Tạo user thường sớm: layer này gần như không bao giờ đổi nên luôn được cache.
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Chỉ lấy KẾT QUẢ từ builder — không có pip cache, không có build tool.
COPY --from=builder /install /usr/local

# Copy đúng thứ cần để chạy, không copy cả repo.
COPY app ./app
COPY utils ./utils

# Từ đây trở đi container không còn quyền root.
USER appuser

EXPOSE 8000

# Đọc PORT lúc chạy chứ không cố định 8000: cloud gán cổng khác thì probe vẫn
# phải trỏ đúng chỗ app đang lắng nghe.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/healthz').read()" || exit 1

# Dạng shell để ${PORT} được giãn nở lúc chạy — Railway/Render/Cloud Run tự gán
# cổng qua biến này. Bind 0.0.0.0 chứ không phải 127.0.0.1, nếu không thì bên
# ngoài container không gọi vào được.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
