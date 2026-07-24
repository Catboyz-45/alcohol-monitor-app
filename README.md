# Alcohol Monitor

แอปพลิเคชันติดตามและบันทึกผลการตรวจแอลกอฮอล์จากอุปกรณ์ IoT พัฒนาด้วย Flutter เชื่อมต่อบอร์ดและเซนเซอร์ผ่าน NETPIE โดยรองรับข้อมูลแบบ real-time ผ่าน MQTT การควบคุมอุปกรณ์ และการเก็บประวัติทั้งในเครื่องและ Cloud Firestore

โปรเจกต์นี้เป็นผลงานระหว่างเรียน รายวิชา 02739342 Application Development for Mobile Devices

## เกี่ยวกับโปรเจกต์

Alcohol Monitor ช่วยให้ผู้ใช้งานรับค่าจากเซนเซอร์ตรวจวัดแอลกอฮอล์ บันทึกข้อมูลผู้เข้ารับการตรวจและข้อมูลรถ ตรวจสอบประวัติย้อนหลัง รวมถึงตั้งค่าเกณฑ์แจ้งเตือนและควบคุม Buzzer หรือไฟ LED จากแอปเดียว

โปรเจกต์นี้แสดงการประยุกต์ใช้ Flutter ร่วมกับ Provider, MQTT, NETPIE REST API, SharedPreferences และ Cloud Firestore REST API รวมถึงการรองรับการเชื่อมต่อ MQTT ที่ต่างกันระหว่างแอป native และเว็บ

โค้ดฝั่งอุปกรณ์ IoT แยกไว้ใน repository `alcohol-monitor-firmware`

## ความสามารถหลัก

- รับค่าการตรวจแอลกอฮอล์จากอุปกรณ์แบบ real-time ผ่าน MQTT
- ดึงสถานะล่าสุดจาก NETPIE Device Shadow ผ่าน HTTP เป็นระบบสำรอง
- แสดงค่า BAC, ค่าดิบจากเซนเซอร์ และระดับแจ้งเตือน
- แบ่งสถานะผลตรวจเป็น `SAFE`, `WARNING` และ `DRUNK`
- บันทึกชื่อ เลขบัตรประชาชน อายุ ทะเบียนรถ จังหวัด และผลตรวจ
- แสดงประวัติการตรวจย้อนหลังและสรุปจำนวนรายการ
- เก็บประวัติในเครื่องด้วย SharedPreferences
- ซิงก์ประวัติกับ Cloud Firestore เมื่อกำหนดค่า Firebase
- ตั้งค่า Threshold สองระดับและส่งค่าไปยังอุปกรณ์
- สั่งเปิดหรือปิด Buzzer และไฟ LED สีแดง
- รองรับ Android, iOS, macOS, Linux, Windows และ Web ตามแพลตฟอร์มที่ Flutter รองรับ
- แยกค่าการเชื่อมต่อและ credentials ออกจาก source code ด้วย `--dart-define-from-file`

## เทคโนโลยีที่ใช้

| หมวด | เทคโนโลยี |
| --- | --- |
| Application | Flutter, Dart |
| UI | Material Design 3, Google Fonts |
| State management | Provider |
| IoT messaging | MQTT, NETPIE |
| Device API | NETPIE REST API และ Device Shadow |
| Cloud storage | Cloud Firestore REST API |
| Local storage | SharedPreferences |
| Networking | `http`, `mqtt_client` |

## โครงสร้างโปรเจกต์

```text
lib/
├── main.dart                     # จุดเริ่มต้นแอปและ Provider กลาง
├── app_state.dart                # State, โมเดล และการจัดเก็บประวัติ
├── home_page.dart                # Navigation และประสาน MQTT/HTTP
├── home_service.dart             # เรียก NETPIE REST API
├── mqtt_service.dart             # เชื่อมต่อและอ่าน MQTT payload
├── mqtt_client_factory.dart      # เลือก MQTT client ตามแพลตฟอร์ม
├── mqtt_client_factory_io.dart   # MQTT ผ่าน TCP สำหรับ native
├── mqtt_client_factory_web.dart  # MQTT ผ่าน WebSocket สำหรับเว็บ
├── measurement_form_page.dart    # แบบฟอร์มบันทึกผลตรวจ
├── measurement_history_page.dart # ประวัติและการลบรายการ
└── settings_page.dart            # Threshold, Buzzer และ LED
```

## การติดตั้งและรัน

### สิ่งที่ต้องมี

- Flutter SDK ที่รองรับ Dart `^3.7.2`
- Android Studio หรือ Xcode ตามแพลตฟอร์มที่ต้องการรัน
- NETPIE project พร้อม device credentials สำหรับ MQTT และ REST API
- Firebase project และ Cloud Firestore หากต้องการซิงก์ข้อมูลขึ้น Cloud

### ขั้นตอน

```bash
git clone https://github.com/Catboyz-45/alcohol-monitor-app.git
cd alcohol-monitor-app
flutter pub get
cp config.example.json config.json
```

แก้ไข `config.json` ให้เป็นค่าของ NETPIE และ Firebase ของตนเอง ห้าม commit ไฟล์นี้ขึ้น repository จากนั้นรัน:

```bash
flutter run --dart-define-from-file=config.json
```

ถ้าไม่กำหนดค่า Firebase แอปยังเก็บประวัติไว้ในเครื่องได้ หากไม่กำหนด NETPIE credentials แอปเปิดดู UI ได้ แต่จะไม่สามารถอ่านสถานะหรือควบคุมอุปกรณ์จริง

### การ Build

```bash
flutter build apk --release --dart-define-from-file=config.json
```

สำหรับเว็บ:

```bash
flutter build web --release --dart-define-from-file=config.json
```

> ค่าที่ส่งด้วย `dart-define` จะถูกฝังใน client application ตอน build จึงไม่ถือเป็น secret storage ที่ปลอดภัย สำหรับ production ควรให้แอปเรียก trusted backend ที่ตรวจสอบสิทธิ์แทนการแจก device token ให้ client โดยตรง

## การตรวจสอบคุณภาพโค้ด

```bash
flutter analyze
flutter test
flutter build apk --release
```

สถานะการตรวจล่าสุด:

- `flutter analyze` — ผ่าน ไม่พบปัญหา
- `flutter test` — ผ่าน 1 test
- `flutter build apk --release` — ผ่าน

## สิ่งที่ได้เรียนรู้

- ออกแบบแอป Flutter แบบหลายหน้าจอด้วย Material Design 3
- จัดการ state กลางและข้อมูลแบบ reactive ด้วย Provider
- รับข้อมูล IoT แบบ real-time ด้วย MQTT
- ใช้ HTTP polling เป็น fallback เมื่อ MQTT ขาดช่วง
- แยก implementation ของ MQTT สำหรับ native และเว็บ
- เก็บข้อมูลแบบ offline-first และซิงก์กับ Cloud
- ควบคุมอุปกรณ์และปรับ Threshold ผ่าน NETPIE
- แยกค่าคอนฟิกออกจาก source code

## สถานะและข้อจำกัด

โปรเจกต์นี้จัดทำขึ้นเพื่อการเรียนรู้และนำเสนอผลงาน ยังไม่ใช่อุปกรณ์ตรวจวัดที่ผ่านการรับรองทางการแพทย์หรือกฎหมาย ค่า BAC ขึ้นอยู่กับการสอบเทียบเซนเซอร์และ firmware ของอุปกรณ์ จึงไม่ควรใช้เพื่อตัดสินทางกฎหมายหรือความปลอดภัยโดยไม่มีอุปกรณ์มาตรฐานยืนยัน

ข้อมูลประวัติมีชื่อ เลขบัตรประชาชน และข้อมูลรถ การนำไปใช้จริงต้องเพิ่ม authentication, authorization, Firestore Security Rules, การปกปิดข้อมูล และนโยบายเก็บรักษาข้อมูลที่เหมาะสม แอปปัจจุบันเรียก NETPIE และ Firestore REST API จาก client โดยตรง จึงควรย้ายการดำเนินการที่สำคัญไปยัง trusted backend ก่อนใช้ใน production

## แนวทางพัฒนาต่อ

- เพิ่มระบบสมาชิกและ Role-based access control
- เพิ่ม backend สำหรับซ่อน NETPIE credentials และตรวจสิทธิ์ทุกคำสั่ง
- เพิ่ม Firestore Security Rules และจำกัดการเข้าถึงข้อมูลตามผู้ใช้
- เพิ่มการเข้ารหัสหรือ secure storage สำหรับข้อมูลสำคัญในเครื่อง
- เพิ่ม unit, widget และ integration tests สำหรับ flow สำคัญ
- เพิ่มการตรวจสอบรูปแบบเลขบัตรประชาชนและข้อมูลรถ
- เพิ่มสถานะ sync และ retry queue สำหรับข้อมูลที่ยังส่งขึ้น Cloud ไม่สำเร็จ
- เพิ่ม acknowledgment สำหรับคำสั่ง Buzzer, LED และ Threshold
- เพิ่มการสอบเทียบเซนเซอร์และแสดงหน่วยวัดที่ตรวจสอบได้
- ปรับ accessibility และรองรับหลายภาษา

## ผู้พัฒนา

พัฒนาโดย [Catboyz-45](https://github.com/Catboyz-45) เพื่อใช้เป็นผลงานระหว่างเรียนและประกอบการสัมภาษณ์
