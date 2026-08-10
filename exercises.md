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

Chạy `uvicorn app.main:app --port 8012` rồi gọi `/chat` vài lần, đây là log thu
được trên stdout:

```
{"event": "service_started", "severity": "INFO", "ts": "2026-08-10T08:28:52.991311+00:00", "service": "day12-chat-service", "version": "1.0.0"}
{"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T08:28:53.246557+00:00", "client_id": "sv01", "prompt_tokens": 3, "completion_tokens": 41, "usd_cost": 2.505e-05}
{"event": "service_stopped", "severity": "INFO", "ts": "2026-08-10T08:28:53.398494+00:00", "service": "day12-chat-service"}
```

(Lưu ý: phải làm xong CP4 mới chạy được lệnh này. Ở CP1 service chết ngay lúc
khởi động vì `lifespan` gọi `shutdown_guard.arm()` khi hàm đó còn
`NotImplementedError`.)

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
| 1 stage (bản đầu) | 1730 MB (1.73 GB) |
| Multi-stage | 296 MB |

Chênh lệch ~1430 MB. Tôi tra bằng `docker history` xem nó nằm ở đâu:

**Phần lớn nhất là base image (~1400 MB).** `python:3.11` bản đầy đủ khoảng
1.63 GB vì nó mang theo cả một môi trường build: gcc, g++, make, header của
nhiều thư viện hệ thống, git, curl, tài liệu và man page. `python:3.11-slim`
chỉ khoảng 230 MB — vẫn đủ chạy Python, chỉ bỏ những thứ để *biên dịch*. Sau khi
`pip install` xong thì không còn cần compiler nữa, nên mang nó theo suốt đời
image là vô ích.

**Phần còn lại là cache của pip (~29 MB).** Layer `pip install` ở bản 1 stage
nặng 94.5 MB, còn bản multi-stage chỉ 65.3 MB. Chênh lệch là thư mục
`~/.cache/pip` — các file `.whl` đã tải về. Bản multi-stage không dính vì
`--no-cache-dir` và vì stage runtime chỉ `COPY --from=builder /install`, tức là
chỉ lấy *kết quả cài đặt*, không lấy nguyên thư mục nhà của builder.

Điểm mấu chốt tôi rút ra: mọi thứ chỉ cần **lúc build** đều là rác **lúc chạy**.
Multi-stage tồn tại để vẽ ranh giới giữa hai thời điểm đó.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Tôi thêm một dòng comment vào cuối `app/main.py` rồi build lại với
`--progress=plain`:

```
#6  [runtime 2/6] RUN useradd --create-home --uid 10001 appuser   CACHED
#7  [builder 2/4] WORKDIR /build                                  CACHED
#8  [builder 4/4] RUN pip install --no-cache-dir ...              CACHED
#9  [runtime 3/6] WORKDIR /app                                    CACHED
#10 [builder 3/4] COPY requirements.txt .                         CACHED
#11 [runtime 4/6] COPY --from=builder /install /usr/local         CACHED
#12 [runtime 5/6] COPY app ./app                                  ← chạy lại
#13 [runtime 6/6] COPY utils ./utils                              ← chạy lại
```

Toàn bộ stage `builder` được dùng lại, kể cả layer đắt nhất là `pip install`.
Chỉ hai layer cuối phải chạy lại, và cả hai đều chỉ tốn vài trăm kB. Build lần
hai xong trong khoảng 1.5 giây.

Điều tôi không ngờ: `COPY utils ./utils` cũng chạy lại dù `utils/` không hề đổi.
Lý do là cache của Docker mang tính dây chuyền — một layer bị huỷ thì **mọi
layer sau nó** đều bị huỷ theo, vì layer sau được xây trên hệ thống file mà
layer trước để lại. Nên thứ tự trong Dockerfile chính là thứ tự ưu tiên: cái gì
ít thay đổi đặt lên trên, cái gì thay đổi mỗi lần commit đặt xuống dưới cùng.

Nếu đặt `COPY . .` lên trước `RUN pip install`: mỗi lần sửa một dấu phẩy trong
code là layer `COPY` đổi, kéo theo `pip install` bị huỷ cache và cài lại toàn
bộ 13 thư viện trong `requirements.txt`. Build từ ~1.5 giây thành hàng chục
giây tới vài phút — mỗi lần, cả ngày, và trên cả CI. Đó chính là lỗi của
Dockerfile bản đầu.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:

1. Service có một lỗ hổng cho phép chạy lệnh tuỳ ý — ví dụ một chỗ nào đó ghép
   chuỗi từ input người dùng vào `subprocess` hoặc `eval`. Kẻ tấn công gửi một
   request khai thác chỗ đó.
2. Lệnh của họ chạy **với quyền của tiến trình uvicorn**. Nếu Dockerfile không
   có `USER`, tiến trình đó là root, nên họ có root *bên trong container*.
3. Là root trong container, họ làm được những việc mà user thường không làm
   được: cài thêm công cụ, đọc mọi file trong image, ghi vào mọi thư mục, và
   quan trọng nhất là đọc/ghi được các volume mount từ host với quyền root.
4. Từ đó họ tìm đường ra host: một volume mount hớ hênh (kinh điển là
   `/var/run/docker.sock`), một container chạy `--privileged`, hoặc một lỗ hổng
   thoát container của nhân. Với các đường này, root-trong-container thường
   thành root-trên-host, vì UID 0 trong container và UID 0 trên host là **cùng
   một UID** khi không bật user namespace.

`USER appuser` cắt chuỗi ở **bước 2**. Lệnh của kẻ tấn công vẫn chạy — lỗ hổng
ở tầng ứng dụng không biến mất — nhưng chạy với UID 10001, một user không có
quyền gì đặc biệt: không ghi được ngoài thư mục nhà, không cài được package,
không đọc được file chỉ dành cho root, và nếu có mount thì cũng chỉ đọc/ghi
được đúng những gì UID 10001 được phép. Bước 3 và 4 mất hết nhiên liệu.

Đây là nguyên tắc *least privilege*: không ngăn được sự cố thứ nhất, nhưng chặn
nó leo thang thành sự cố thứ hai. Đổi lại chỉ tốn đúng hai dòng trong
Dockerfile.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

**Vì sao 401 phải kèm `WWW-Authenticate: Bearer`.** 401 chỉ nói "bạn chưa được
xác thực", nó không nói *xác thực bằng cách nào*. Header này là phần trả lời
câu đó: nó khai báo scheme mà server chấp nhận. Nhờ vậy client tự động — trình
duyệt, thư viện HTTP, `curl --oauth2-bearer` — biết phải gửi lại request kèm
loại credential nào thay vì đoán mò. Chuẩn HTTP (RFC 7235) bắt buộc header này
với mọi response 401, và RFC 6750 quy định giá trị `Bearer` cho token dạng này.
Thiếu nó thì response vẫn "chạy được" với client viết tay, nhưng sai chuẩn và
mọi công cụ tự động đều mù.

**Vì sao dùng chung một thông báo.** Vì thông báo chi tiết là thông tin miễn phí
cho người đang dò. "Sai scheme" xác nhận token họ có là đúng, chỉ gửi sai cách —
họ sửa header rồi vào được. "Token không đúng" thì ngược lại, xác nhận cách gửi
đã chuẩn và chỉ còn phải dò giá trị token. Mỗi lần phân biệt là một lần thu hẹp
không gian tìm kiếm giúp họ.

Người dùng hợp lệ không cần thông báo chi tiết: họ có token đúng và tài liệu API
ghi rõ format. Người cần thông báo chi tiết chủ yếu là người không nên vào được.
Trong code tôi gom cả ba nhánh về cùng một hàm `_unauthorized()` để không thể vô
tình phân biệt.

Cùng một logic là lý do tôi so sánh token bằng `secrets.compare_digest` thay vì
`==`: `==` dừng ngay tại ký tự đầu tiên khác nhau, nên thời gian trả lời rò rỉ
độ dài phần đã đoán đúng. Đó cũng là một dạng "thông báo chi tiết", chỉ là đo
bằng đồng hồ thay vì đọc bằng mắt.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

Tôi chạy thử bằng `fakeredis`: tiêu cạn xô ở `t=1000`, để yên 600 giây rồi bắn
liên tục cho tới khi bị chặn.

| | Số request trước khi 429 |
|---|---|
| Có `min(capacity, ...)` | **10** |
| Bỏ `min(capacity, ...)` | **100** |

**Có `min()`:** 10 phút im lặng nạp được 10 phút × 10 token/phút = 100 token,
nhưng xô chỉ chứa được 10. Phần dư tràn ra ngoài và mất. Client bắn được đúng
`capacity` = 10 request, tới request thứ 11 thì xô cạn → 429.

**Bỏ `min()`:** không còn cái nắp nào, `tokens` cứ cộng dồn theo thời gian trôi.
100 token tích được là 100 token tiêu được. Con số này tỉ lệ thuận với thời gian
im lặng: nghỉ 1 giờ thì 600 request, nghỉ một ngày thì 14.400 request — tất cả
trong một giây.

Điều đó phá hỏng đúng thứ mà rate limit sinh ra để bảo vệ. Ý nghĩa của
`capacity` là **mức bùng tối đa** mà hệ thống chịu được trong một khoảnh khắc;
`refill_per_minute` mới là tốc độ trung bình dài hạn. Bỏ `min()` là bỏ luôn giới
hạn thứ nhất, chỉ còn giới hạn thứ hai — mà giới hạn trung bình thì không cứu
được server khi 14.400 request ập vào cùng lúc.

Đây cũng là lý do một client "ngoan" nhưng ngủ đông lâu ngày có thể vô tình
thành nguồn tấn công, nếu ta quên cái nắp đó.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

| | Hạn mức $30/tháng | Hạn mức $1/ngày |
|---|---|---|
| Thiệt hại tối đa của sự cố | $30 | $1 |
| Client bị chặn tới khi nào | đầu tháng sau | 00:00 UTC hôm sau |
| Thời gian chặn tệ nhất | ~30 ngày | ~24 giờ |

**$30/tháng.** Sự cố bắt đầu 2h sáng ngày mùng 2. Không có gì chặn tốc độ tiêu,
nên nó đốt hết $30 trong vài giờ. 6h sáng tôi thức dậy: tiền đã mất hết, và tệ
hơn — client đó bị khoá cho tới **ngày 1 tháng sau**, tức là 29 ngày không dùng
được service dù sự cố chỉ kéo dài vài giờ. Muốn nó dùng lại thì phải có người
vào can thiệp tay: nâng hạn mức hoặc xoá key.

**$1/ngày.** Cùng sự cố đó đốt hết $1 rồi dừng. `check()` trả 402 cho mọi
request tiếp theo, nên phần còn lại của đêm không mất thêm đồng nào. Đúng
00:00 UTC, `CostGuard.today()` trả về nhãn ngày mới → `_key()` sinh ra key mới →
`spent()` đọc key chưa tồn tại → trả 0.0. Ngân sách tự đầy lại **mà không ai
phải làm gì**.

Điểm tôi thấy quan trọng nhất không phải con số $30 với $1, mà là **cửa sổ hồi
phục**. Hạn mức càng dài thì hai thứ cùng xấu đi một lúc: mất nhiều tiền hơn
*và* bị khoá lâu hơn. Hạn mức ngày cắt cả hai xuống 1/30, và biến việc hồi phục
từ "chờ người xử lý" thành "chờ đồng hồ điểm nửa đêm".

Đó cũng là lý do key trong Redis đặt theo `spend:<client_id>:<ngày>` chứ không
phải một bộ đếm duy nhất: nhãn ngày nằm ngay trong tên key, nên việc reset không
cần job dọn dẹp nào cả — chỉ cần key cũ hết hạn theo TTL.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

**Giây 0** — Redis mất kết nối. Cả 3 container vẫn khoẻ: tiến trình sống, code
không lỗi, chỉ là dependency không trả lời.

**Giây 0–10** — Endpoint gộp gọi `ping()`, thất bại, trả 503. Cả 3 container trả
503 **cùng lúc**, vì chúng cùng phụ thuộc một Redis. Đây là điểm mấu chốt: lỗi
không phân tán mà đồng loạt.

**Giây 10–20** — Load balancer thấy 503 nên rút cả 3 khỏi vòng phục vụ. Không
còn instance nào nhận traffic → 100% request lỗi. Đồng thời orchestrator đọc
chính endpoint đó như **liveness** probe: đủ số lần thất bại liên tiếp
(thường 3) là nó kết luận container hỏng.

**Giây ~20** — Orchestrator giết và restart cả 3 container. Mọi request đang xử
lý dở bị cắt. Cache trong process, kết nối đang mở, mọi thứ mất sạch.

**Giây 20–30** — Container mới khởi động, nhưng Redis vẫn chưa về. Probe lại
thất bại → restart lần hai. Nhiều orchestrator bắt đầu áp backoff luỹ tiến
(10s, 20s, 40s...), nên chúng còn bị hoãn khởi động lại.

**Giây 30** — Redis phục hồi. Nhưng cụm thì chưa: container đang ở giữa chu kỳ
restart hoặc đang chờ hết backoff, rồi còn phải khởi động lại từ đầu.

**Kết quả:** sự cố dependency 30 giây biến thành sự cố toàn phần vài phút, cộng
thêm toàn bộ request đang chạy bị giết oan. Bản thân việc restart không sửa được
gì cả — Redis chết thì container mới cũng không kết nối được.

**Nếu tách hai endpoint:** `/healthz` không chạm Redis nên vẫn trả 200 suốt —
orchestrator không restart ai cả, vì đúng là không có container nào hỏng.
`/readyz` trả 503, load balancer ngừng đẩy traffic vào. Giây 30 Redis về,
`ping()` thành công, `/readyz` trả 200 trở lại và traffic chảy tiếp **ngay lập
tức**, không cần khởi động lại gì.

Tôi rút ra: hai endpoint này trả lời hai câu hỏi khác nhau và có hai hậu quả
khác nhau. `/healthz` = "có nên **giết** tôi không?" — hậu quả là restart, thứ
chỉ hữu ích khi chính tiến trình hỏng. `/readyz` = "có nên **gửi traffic** cho
tôi không?" — hậu quả là rút khỏi load balancer, thứ có thể đảo ngược tức thì.
Gộp chúng lại là dùng cây búa để trả lời một câu hỏi cần cái công tắc.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Bản deploy lên Render lên xanh ngay lần đầu, nên tôi kể hai lỗi thật đã chặn
đường trước khi tới được bước đó — một lỗi làm service không khởi động nổi, một
lỗi về `$PORT` mà tôi bắt được trước khi nó kịp gây hại trên cloud.

**Lỗi 1 — service không khởi động được.** Ở CP1 tôi làm xong `/healthz`, test
xanh 13/13, nên tưởng chạy thử được. Nhưng `uvicorn app.main:app --port 8000`
chết ngay:

```
File "app/main.py", line 65, in lifespan
    shutdown_guard.arm()
File "app/lifecycle.py", line 60, in arm
    raise NotImplementedError("TODO (CP4): cài đặt arm")
ERROR:    Application startup failed. Exiting.
```

Chỗ khó hiểu là **test xanh mà app lại chết**. Đọc traceback thì thấy lỗi phát
sinh trong `lifespan`, và tra `tests/conftest.py` mới hiểu: `_build_client()` cố
tình **không** dùng `with TestClient(...)`, mà `lifespan` chỉ chạy khi dùng dạng
context manager. Nghĩa là test chưa bao giờ đi qua `arm()`. Không có cách sửa
nào ở CP1 cả — `arm()` thuộc CP4, phải làm xong CP4 thì service mới chạy được.
Bài học: **test xanh không đồng nghĩa app chạy được**; test bao đến đâu thì bảo
đảm đến đó, và ở đây nó cố tình bỏ qua vòng đời khởi động.

**Lỗi 2 — `HEALTHCHECK` gọi cứng cổng 8000.** `CMD` trong Dockerfile của tôi đọc
`${PORT:-8000}` đúng, nhưng dòng `HEALTHCHECK` thì tôi viết thẳng
`http://127.0.0.1:8000/healthz`. Render gán `PORT=10000`, nên app lắng nghe
10000 còn probe gõ cửa 8000 — mãi mãi không ai trả lời.

Tôi phát hiện bằng cách chạy thử đúng điều kiện của Render ngay ở máy:

```
docker run -e PORT=10000 -p 10000:10000 day12-chat:prod
docker inspect --format '{{.State.Health.Status}}' <container>
```

Sửa bằng cách cho probe đọc cùng một biến với `CMD`:

```dockerfile
CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/healthz').read()" || exit 1
```

Chạy lại thì `Health.Status` chuyển thành `healthy`.

Điểm đáng nói: Render dùng `healthCheckPath` trong `render.yaml` chứ không dùng
`HEALTHCHECK` của Dockerfile, nên lỗi này **sẽ không làm bản deploy fail** —
nó chỉ âm thầm sai. Đúng kiểu lỗi khó chịu nhất: không ai báo, và tới khi chạy
image đó ở chỗ có dùng Docker healthcheck (như `docker compose`) mới lộ ra.
Nguyên tắc rút ra là mọi chỗ nhắc tới cổng đều phải lấy từ cùng một nguồn —
biến `PORT` — chứ không được có hai chỗ tự khai số riêng.
