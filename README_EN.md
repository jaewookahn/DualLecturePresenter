# 🎓 SSamSSami (쌤쌤이)

> **A native macOS dual-PDF lecture presenter designed for teachers ("SSam") where both screens stay strictly synchronized ("Same-Same").**  
> *[한국어 설명서 (README.md)](README.md)*

**SSamSSami** is a native macOS presentation tool engineered specifically for lecturers, teachers, and presenters. It simultaneously manages two versions of a lecture PDF:
1. **Instructor PDF** (containing personal annotations, secret teaching memos, solutions, and hints)
2. **Student PDF** (a clean, presentation-ready document)

The student presentation view operates in a **dedicated, independent window**, allowing instructors on Zoom, Google Meet, Microsoft Teams, or in-person projectors to share **only the student window**, keeping private notes and dashboards completely hidden.

---

## 💡 The Story Behind the Name ("SSamSSami")

The name **SSamSSami (쌤쌤이)** combines two playful and witty concepts:

1. **"SSam" (쌤)**: An affectionate Korean everyday term for **Teacher / Instructor** (derived from *선생님, Seon-saeng-nim*).
2. **"Same-Same" (쌤쌤)**: A popular colloquial idiom meaning **"Exactly equal / Even"** (from English *Same-Same*). Even though the instructor views private notes and students see a clean slide, page transitions, continuous scrolling, aspect ratios, laser pointer, and drawings always move in **"Same-Same" (쌤쌤)** real-time lockstep!

---

## ✨ Key Features

### 1. Independent Presentation Window (Optimized for Online Meetings)
- **Instructor Dashboard**: Controls lecture flow, displays timer, real-time mini student monitor preview, slide thumbnails, and private notes.
- **Student Presentation Window**: Clean, unencumbered slide view with zero distracting UI or secret memos.
- Automatically places the student presentation on a secondary monitor/projector if detected.

### 2. Flawless Real-Time Synchronization
- **Single Page Mode**: Arrow keys (`←`, `→`), Spacebar, and wireless presentation clickers advance or retreat slides in zero latency.
- **Continuous Scroll Mode**: 2-finger trackpad or mouse wheel gestures smoothly sync proportional document scrolling across windows.

### 3. Aspect Ratio Locking & Letterbox Elimination
- Different window aspect ratios often introduce ugly black bars (letterboxing) during Zoom screen sharing, or cause vertical visibility mismatches in continuous mode.
- **4 Presets Available**:
  - **PDF Native**: Automatically computes and locks the window aspect ratio (`NSWindow.contentAspectRatio`) to the document's first page crop box.
  - **Match Instructor Viewport**: Dynamically clones the instructor's active viewport aspect ratio to the student window.
  - **16:9 Widescreen & 4:3 Standard**: One-click standard display ratios.
  - **Free**: Unconstrained resizing.

### 4. Interactive Live Annotation Suite
- **Laser Pointer (`⌘+L` or `L`)**: Projects a high-visibility neon-red glow dot at normalized page coordinates. **Trackpad/mouse wheel 2-finger scrolling remains fully responsive even with the laser tool active.**
- **Pen Drawing (`⌘+D` or `P`)**: Live hand-drawn sketches sync instantaneously across screens.
- **Highlighter (`⌘+H` or `H`)**: A broad, semi-transparent yellow stroke with multiply blending that highlights diagrams and text without obscuring legibility.
- **Click-to-Type Text Annotations (`⌘+T` or `T`)**: Click anywhere on a slide to open an inline editor; pressing Enter places a clean note badge synchronized to students.
- **Eraser (`⌘+E` or `E`)**: Drag over any stroke or text annotation to wipe it clean.

### 5. Secret Peek Mode (Sync Pause / `⌘+S`)
- Temporarily freeze the student window on the current slide while the instructor freely navigates ahead to review upcoming slides, answers, or notes.
- Click **"Re-sync with Student"** to instantly snap the student window to the instructor's current slide.

### 6. Screen Blackout (`B`)
- Instantly blackout the student window to draw audience focus back to the speaker. The instructor view remains fully visible.

### 7. Real-Time Mini Student Preview
- An embedded mini monitor on the instructor's right dashboard displays an exact live mirror of the student presentation, giving total confidence in what is being shared.

### 8. Auto-Pairing
- Opening `lecture_instructor.pdf` automatically searches for and pairs with `lecture_student.pdf` in the same directory.
- A single PDF can also be mirrored with a single click: `[Use Same Document for Students]`.

---

## ⌨️ Keyboard Shortcuts

> [!NOTE]
> All navigation keys (`Space`, `←`, `→`, `PageUp`, `PageDown`) and single-key tool toggles (`B`, `L`, `P`, `H`, `T`, `E`) are captured via an AppKit local event monitor (`NSEvent`), guaranteeing instantaneous response without losing focus to internal PDF views. (Standard text typing automatically passes through when editing notes.)

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| **Next Slide** | `Space` or `→` (or `PageDown`) | Advance to next page synchronously (Clicker remote compatible) |
| **Previous Slide** | `Shift + Space` or `←` (or `PageUp`) | Return to previous page synchronously |
| **Screen Blackout** | `B` | Toggle black overlay on student window |
| **Default Pointer** | `⌘ + 0` | Standard mouse navigation cursor |
| **Laser Pointer** | `L` or `⌘ + L` | Project bright laser dot (scrolling enabled) |
| **Pen Tool** | `P` or `⌘ + D` | Freehand drawing on slide |
| **Highlighter** | `H` or `⌘ + H` | Broad semi-transparent yellow highlighter |
| **Text Annotation** | `T` or `⌘ + T` | Click slide to type text note (Enter to commit) |
| **Eraser Tool** | `E` or `⌘ + E` | Drag to erase strokes and text |
| **Clear Page Drawings** | `⌘ + K` | Erase all strokes & text on the current page |
| **Secret Peek (Sync Toggle)**| `⌘ + S` | Freeze student window to browse notes privately |
| **Toggle Student Window** | `⌘ + ⇧ + P` | Open or close the independent presentation window |

---

## 🚀 Download & Installation

### 1. Download Pre-built Release (Recommended)
Download the latest binaries directly from [GitHub Releases (v0.1.0)](https://github.com/jaewookahn/DualLecturePresenter/releases/latest):
- **`SSamSSami-0.1.0-macOS.dmg`**: Open the disk image and drag `쌤쌤이.app` into your `/Applications` folder.
- **`SSamSSami-0.1.0-macOS.zip`**: Extract and launch `쌤쌤이.app`.

After installation, launch it anytime from Spotlight (`⌘ + Space`) by typing **쌤쌤이** or **SSamSSami**.

### 2. Build from Source
```bash
git clone https://github.com/jaewookahn/DualLecturePresenter.git
cd DualLecturePresenter
./build_app.sh 0.1.0
./install_to_applications.sh
```

---

## 💻 Tech Stack
- **Language**: Swift 6 (Strict Concurrency compliant)
- **UI Architecture**: SwiftUI + AppKit Hybrid
- **Document Engine**: Apple PDFKit (`PDFView`, `PDFDocument`, `PDFDestination`)
- **Event Dispatch**: Combine (`PassthroughSubject`) + AppKit Local Event Monitors
- **Target OS**: macOS 13.0+ (Fully validated on macOS 15 Sequoia)

---

## 📄 License
Copyright © 2026 Jae-wook Ahn. All rights reserved.
