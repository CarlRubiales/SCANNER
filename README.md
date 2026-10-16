# 📦 Lumora Logistics Barcode Scanner App

Dedicated optical camera barcode scanning mobile application built with **Flutter 3** for **Lumora Logistics**. Designed for warehouse operators and intake personnel to scan incoming parcels with zero manual barcode typing, instantly pushing parcels into the Web Sorting Center queue (`/sorting-center`) for admin bin sorting and rider assignment.

---

## 🚀 Key Features

- **Autonomous Offline-First Scanning**: The app opens and scans immediately even when the phone is **NOT connected to the laptop or network**. Barcodes are instantly recognized, saved locally on the device with status **`Scanned`**, and automatically synced to the web sorting center when connected.
- **Hidden Server Technicals**: No raw server URLs or IP addresses are displayed on screen. The interface looks like a clean, official production warehouse terminal.
- **Zero-Typing Camera Scanner**: Full-screen optical scanning using device camera (`mobile_scanner`), featuring animated targeting reticle, corner brackets, and laser scan line.
- **One-Tap / Background Sync**: Includes a **"Sync to Logistics Sorting Desk"** button in Activity and Settings to push all stored offline scans to the Laravel backend at once (`POST /api/v1/scanner/batch-sync`).
- **Live Status Scanned on Web**: When scanned or synced, the parcel automatically appears on the web **Sorting Center** page with status badge **`Scanned`** and the **`Sort`** button ready for the admin.
- **Continuous Rapid Scanning**: Supports warehouse rapid-flow mode (auto-resumes camera scanning after 3 seconds) or single-scan mode.
- **Smart Debounce & Haptics**: Prevents duplicate multi-reads within 3 seconds; provides heavy haptic feedback on detection.

---

## 📱 How to Run the App

### 1. Ensure Laravel Backend is Running
In your Laravel root directory (`shopee-tracker`):
```bash
php artisan serve --host=0.0.0.0 --port=8000
```
> Serving on `0.0.0.0` allows physical phones on the same Wi-Fi network (`192.168.86.23:8000`) or emulators (`10.0.2.2:8000`) to connect seamlessly.

### 2. Run on Android Emulator or Physical Device
Navigate to the scanner app folder:
```bash
cd C:\Users\Rubiales\Logistics\scanner_app
flutter run
```

### 3. Demonstrating Offline to Professor
1. You can open and scan parcels on the phone **completely offline with NO laptop connected**.
2. Scans will immediately pop up with a green confirmation card showing status: **`Scanned`**!
3. When you reconnect to your laptop's Wi-Fi or launch `artisan serve`, tap **"Sync Now"** (or let it auto-sync). All scanned packages will instantly appear live on the web at `http://127.0.0.1:8000/sorting-center` with status **`Scanned`**!

---

## 🔄 End-to-End Workflow

```text
[ Warehouse Staff with Scanner App ]
               │
      📷 Optical Barcode Scan (Offline or Online)
               │
               ▼
[ Local Device Queue + Auto-Sync ]
    Status: 'Scanned' (Saved on Phone)
               │
               ▼
[ Laravel API: POST /api/v1/scanner/scan or batch-sync ]
               │
               ▼
[ Web Sorting Center: /sorting-center ]
    Table shows parcel with badge: [ Scanned ]
               │
    Admin clicks "Sort" ➔ Assigns Bin & Area
               │
    Admin clicks "Assign" ➔ Assigns Rider
               │
               ▼
[ Rider App: "RiderGo" ]
    Rider receives parcel, delivers to customer!
```
