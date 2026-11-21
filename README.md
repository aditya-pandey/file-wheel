# FileWheel

A native, zero-dependency macOS drag-and-drop radial file converter built with **Swift, SwiftUI, AppKit, ImageIO, PDFKit, Vision, and AVFoundation**—100% offline, zero server uploads.

---

## How It Works

1. **Grab any file** in Finder, on your Desktop, or in your browser (`.heic`, `.png`, `.jpg`, `.webp`, `.pdf`, `.mp4`, `.mov`).
2. **Hold `Option` (`⌥`)** and start dragging — the **Donut Menu** pops up centered at your cursor.
3. **Drop onto a slice** (`WebP`, `PNG`, `JPG`, `PDF`, `Cutout (AI)`, `Extract Audio`, or `Copy`) — converts immediately right next to the original file!

---

## Built-In Engines

- **Hardware-Accelerated Image Conversion (`ImageIO`):** HEIC, WebP, PNG, JPG, TIFF with radial quality slider.
- **One-Drop AI Background Removal (`Vision`):** Uses macOS's built-in Neural Engine (`VNGenerateForegroundInstanceMaskRequest`) to isolate subjects onto transparent PNGs offline.
- **PDF Conversion (`PDFKit`):** Convert images to PDF or export PDF pages to crisp images.
- **Instant Audio Extraction (`AVFoundation`):** Strip `.mp4`/`.mov` audio directly into `.m4a`.
- **Direct-to-Clipboard Mode:** Convert and copy straight to clipboard without cluttering disk.

---

## Download & Install (No Xcode Required)

Download the pre-built **Universal app** (`Apple Silicon + Intel`, macOS 14.0+) from **[GitHub Releases](https://github.com/aditya-pandey/file-wheel/releases/latest)**:

1. Open **`FileWheel-macOS-Universal.dmg`** and drag **`FileWheel.app`** into **`Applications`**.
2. Open **FileWheel** once. If macOS Sequoia Gatekeeper prompts:
   - Click **Done** → **System Settings → Privacy & Security → Open Anyway**, **or** run:
     ```bash
     xattr -cr /Applications/FileWheel.app && open /Applications/FileWheel.app
     ```

---

## Build From Source

```bash
git clone https://github.com/aditya-pandey/file-wheel.git
cd file-wheel
chmod +x build_app.sh
./build_app.sh
open /Applications/FileWheel.app
```

---

## Companion Apps (Pick & Choose)

- **[Seek](https://github.com/aditya-pandey/seek)** — Zero-lag frosted glass `⌥ F` file, app, content & command launcher
- **[Glance](https://github.com/aditya-pandey/glance)** — Visual `⌥ Tab` live window & browser tab switcher + Dock hover previews
- **[WeaponWheel](https://github.com/aditya-pandey/weapon-wheel)** — `⌥ Space` radial quick-action wheel (Clipboard, OCR, Window Snapping, Notes, Calculator, Media/Volume)
