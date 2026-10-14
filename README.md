# PRM_database

Ứng dụng Flutter lưu tin nhắn vào SQLite trên thiết bị và đồng bộ lên Cloud Firestore.

## Chạy ứng dụng

1. Cài Flutter và kết nối điện thoại Android hoặc mở Android Emulator.
2. Tạo file cấu hình cá nhân từ mẫu:

   ```sh
   cp firebase-config.example.json firebase-config.json
   ```

3. Điền API key Firebase của ứng dụng Android, iOS và Web vào `firebase-config.json`.
   File này đã được Git bỏ qua, vì vậy không bị đưa lên GitHub.
4. Chạy ứng dụng:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=firebase-config.json
   ```

Các mã project và app ID hiện được cấu hình cho Firebase project `tugo-97f64` trong
[`lib/firebase_options.dart`](lib/firebase_options.dart). Nếu dùng Firebase project
khác, hãy cập nhật các tùy chọn bằng FlutterFire CLI và kiểm tra lại API key tương ứng.

## Firebase và bảo mật

- Bật Cloud Firestore cho Firebase project và đặt Firestore Security Rules phù hợp
  trước khi dùng dữ liệu thật.
- Firebase API key dành cho ứng dụng client không phải mật khẩu bí mật; key được đóng
  gói vào ứng dụng khi build nên không thể giữ bí mật bằng cách mã hóa trong app.
  Không commit file cấu hình cá nhân. Hạn chế API key theo ứng dụng/API trong Google
  Cloud Console và bảo vệ dữ liệu bằng Firestore Security Rules.
- `firebase-config.json`, `google-services.json` và các plist cấu hình native bị bỏ
  qua bởi Git. App dùng `FirebaseOptions` trong Dart để khởi tạo Firebase.

## Lưu và đồng bộ dữ liệu

App lưu tin nhắn vào SQLite trước. Sau đó app ghi dữ liệu lên Firestore. Nếu đồng bộ
thất bại, dữ liệu vẫn được giữ ở SQLite trên thiết bị.
