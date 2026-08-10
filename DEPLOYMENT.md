# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Tấn Hoàng |
| Mã học viên | 2A202601198 |
| Repo | https://github.com/hoangaiecos-boop/K4-DAY12-2A202601198-NguyenTanHoang |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-chat-5hec.onrender.com |
| Platform | Render (Blueprint từ `render.yaml`) |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `API_TOKEN` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Render Key Value `day12-chat-redis`, Render tự inject qua `fromService` |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/healthz

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/readyz

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Client-Id: sv-test" \
  -d '{"message":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" \
    -d '{"message":"test"}'
done; echo
```

## Kết Quả Chạy Thật

```
$ curl -i https://day12-chat-5hec.onrender.com/healthz
HTTP/2 200
{"status":"ok","service":"day12-chat-service","version":"1.0.0"}

$ curl -i https://day12-chat-5hec.onrender.com/readyz
HTTP/2 200
{"status":"ready","redis":true}

$ curl -i -X POST .../chat            # không có token
HTTP/2 401
www-authenticate: Bearer

$ curl -i -X POST .../chat            # có token, gọi lần thứ hai cùng client
HTTP/2 200
content-type: application/json
{"reply":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi
trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.
(Mình đang nhớ 2 lượt trao đổi trước đó.)","client_id":"sv-doc","turns_before":2,
"usd_cost":3.465e-05,"usage":{"prompt":43,"completion":47}}

$ for i in $(seq 1 15); do ... done   # rate limit, client sv-burst
200 200 200 200 200 200 200 200 200 200 429 200 429 429 200
```

Hai điều đọc được từ output này:

**`turns_before: 2`** — lượt gọi thứ hai của cùng một `client_id` thấy được 2
message của lượt trước. State nằm trong Render Key Value chứ không trong RAM của
container, đúng mục tiêu stateless của CP4.

**Chuỗi rate limit không cắt gọn** — 10 request đầu qua (đúng `BUCKET_CAPACITY`),
rồi xen kẽ `429` và `200`. Lúc đầu tôi tưởng sai, nhưng đó chính là token bucket
hoạt động đúng: `REFILL_PER_MINUTE=10` nghĩa là cứ 6 giây có thêm 1 token, mà 15
lượt curl qua Internet mất hơn 15 giây, nên vài token kịp nhỏ vào xô giữa chừng.
Chạy ở máy (nhanh hơn nhiều) thì cắt gọn thành 10 lần `200` rồi `429` liên tục.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/healthz.png` — kết quả gọi `/healthz` từ trình duyệt hoặc curl
