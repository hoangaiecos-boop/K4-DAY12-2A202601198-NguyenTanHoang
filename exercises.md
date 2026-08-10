# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Tấn Hoàng  Mã học viên: 2A202601198

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: tôi deploy service lên Railway, vào dashboard set `REDIS_URL` và
`PORT` nhưng quên mất `API_TOKEN`.

Với `api_token: str` (không mặc định): container khởi động, pydantic không tìm
thấy biến nên ném `ValidationError` ngay giây đầu tiên, deploy fail, log đỏ trên
dashboard. Tôi đang nhìn màn hình nên sửa trong một phút. Không ai gọi được
service vì service chưa từng chạy.

Với `api_token: str = "changeme"`: container khởi động bình thường, `/healthz`
trả 200, Railway báo deploy thành công — không có gì bất thường để tôi chú ý.
Nhưng `/chat` lúc này chấp nhận đúng token `"changeme"`, mà giá trị đó nằm trong
`app/config.py` của một repo public. Bất kỳ ai đọc repo cũng gọi được API của
tôi, và cost guard chỉ chặn theo từng `client_id` nên họ đổi header
`X-Client-Id` là có ngân sách mới. Tôi chỉ phát hiện khi nhìn hoá đơn hoặc thấy
log đầy `client_id` lạ — lúc đó thiệt hại đã xảy ra rồi.

Khác biệt không nằm ở chỗ lỗi nặng hay nhẹ, mà ở chỗ **lỗi có ồn ào hay không**.
Mặc định biến một sai sót cấu hình thành lỗ hổng im lặng. Test
`test_thieu_api_token_thi_fail_fast` kiểm tra đúng điều này: xoá `API_TOKEN`
khỏi môi trường thì `Settings()` bắt buộc phải ném `ValidationError`.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Ở CP1 tôi chưa gọi được `/chat` (endpoint đó thuộc CP3) và service cũng chưa
khởi động được vì `lifespan` gọi `shutdown_guard.arm()` — hàm còn
`NotImplementedError` tới CP4. Nên tôi lấy log bằng cách gọi thẳng `emit()`:

```
{"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T07:55:58.659534+00:00", "client_id": "sv01", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 2.26e-05}
```

**Việc 1 — cộng dồn theo trường.** `usd_cost` và `client_id` là hai trường
riêng biệt có kiểu rõ ràng, nên tôi hỏi được "client nào tốn nhiều tiền nhất
hôm nay" bằng một câu group-by trên log platform, không phải viết code mới.
Với `print("đã trả lời xong")` thì chi phí không có trong log; kể cả có in ra
dạng chữ thì vẫn phải viết regex bóc số từ câu tiếng Việt, và regex đó vỡ ngay
lần đầu ai đó sửa lời nhắn.

**Việc 2 — cảnh báo theo mức độ.** `severity` là khoá mà Google Cloud Logging
(và các platform khác) tự nhận diện, nên tôi lọc được `severity=ERROR`, đếm số
lần trong 5 phút và bắn cảnh báo khi vượt ngưỡng. `print()` không có khái niệm
mức độ — mọi dòng đều như nhau, muốn biết có sự cố hay không thì phải ngồi đọc.

Một điểm nữa tôi để ý khi làm: `ts` theo ISO-8601 kèm múi giờ UTC
(`+00:00`). Chạy nhiều container ở nhiều vùng thì đây là thứ duy nhất cho phép
xếp các sự kiện của chúng lên cùng một trục thời gian.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ... MB |
| Multi-stage | ... MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> *Câu trả lời của bạn*

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> *Câu trả lời của bạn*

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> *Câu trả lời của bạn*

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> *Câu trả lời của bạn*

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> *Câu trả lời của bạn*

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> *Câu trả lời của bạn*

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> *Câu trả lời của bạn*

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> *Câu trả lời của bạn*
