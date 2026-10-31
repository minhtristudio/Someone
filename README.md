# Someone

## Roleplay từ bản demo

`29acde6377368455288b7247f8622f2d.txt` dùng các rig, body và KeyframeSequence được trích từ `_GameFileDEMO.rbxl.txt` cho mục Roleplay; không tải lại các pack Roleplay cũ. Model đã trích được nhúng vào script và không chứa script của place. Cần môi trường executor hỗ trợ HTTP GET, thao tác file nhị phân, `getcustomasset` (hoặc `getsynasset`) và `game:GetObjects`.

- `Meshes.zip` được tìm trong thư mục executor, hoặc tải từ `https://ro4ssets.wasmer.app/installs/Meshes.zip` rồi thử bản mirror GitHub nếu cần.
- Script thử tải thêm `Textures.zip`, `Sounds.zip`, `Musics.zip` và `Install.zip` từ `https://ro4ssets.wasmer.app/installs/`. Những tên này được suy ra từ đường dẫn tài nguyên trong place, **chưa xác nhận là tên ZIP thực tế trên máy chủ**. Có thể bổ sung tên chính xác trước khi chạy script:

  ```lua
  getgenv().DemoRoleplayArchives = { "ten-archive-thuc-te.zip" }
  ```

- Thiếu texture được báo trên giao diện; khi texture đến sau, script thử cập nhật rig đang hiện. Không có fallback sang body Roleplay cũ. Mesh có xương cần executor hỗ trợ tạo mesh đó; lỗi sẽ được báo thay vì âm thầm thay thế body.
- Playback dựng cảnh và diễn viên **cục bộ**. Đồng bộ Roleplay nhiều người, hiệu ứng và âm thanh gốc của cảnh chưa được triển khai/xác nhận.

## Kiểm thử và tái tạo model

Các kiểm thử sau là offline, không thay thế kiểm thử Roblox/runtime hoặc xác nhận các URL ZIP trên Wasmer:

```sh
# Tùy chọn: cài Luau CLI và trỏ LUAU tới executable đó.
LUAU=/path/to/luau python3 -m unittest discover -s tests -v

# Tùy chọn: kiểm tra toàn bộ entry của Meshes.zip thực tế.
LUAU=/path/to/luau DEMO_MESHES_ZIP=/path/to/Meshes.zip python3 -m unittest discover -s tests -v

# Dependencies chỉ dùng để phát triển; không cần trong executor.
npm install --no-save --no-package-lock --ignore-scripts rbxm-parser@1.1.4 rbx-reader@1.5.10 lz4js@0.2.0
node tools/build_demo_roleplay_pack.cjs --check
DEMO_MESHES_ZIP=/path/to/Meshes.zip node tests/validate_demo_pack.cjs
```

Để cập nhật model nhúng sau khi thay place, chạy `node tools/build_demo_roleplay_pack.cjs --update` rồi chạy lại các kiểm thử. Công cụ giữ các cảnh, rig và animation Player/Human; không nhúng code thực thi trong place.
