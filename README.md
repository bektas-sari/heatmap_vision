# Heatmap Vision

AI‑powered, on‑device **saliency heatmap** and creative insights for advertisers. Upload an image, visualize attention distribution, and get actionable guidance for **logo/CTA placement**, **color usage**, and **typography**—all offline.

---

## Table of Contents

* [Features](#features)
* [Live Demo / Screens](#live-demo--screens)
* [How It Works](#how-it-works)
* [Exported Data (JSON Schema)](#exported-data-json-schema)
* [Getting Started](#getting-started)
* [Usage](#usage)
* [Project Structure](#project-structure)
* [Tech Notes & Constraints](#tech-notes--constraints)
* [Roadmap](#roadmap)
* [License](#license)
* [Developer](#-developer)

---

## Features

* **On‑device saliency heatmap** (Sobel → Gaussian blur → center‑bias normalization). No Grad‑CAM; no internet.
* **Key Insights** tailored for ad analysts:

    * *Coverage* (share of high‑attention area)
    * *Rule of Thirds alignment*
    * *Top attention hotspots* in human‑friendly terms (e.g., “Top‑Right, near the center”).
    * *Recommended logo area* (low‑attention corner) with on‑image guide.
    * *Low‑attention zones* described in plain language.
* **Design Hints**: dominant colors and accent colors extracted from the image, plus **typeface suggestions** (Headlines → Montserrat/Poppins; Body → Inter; CTA → Roboto Condensed/Oswald).
* **Adjustable overlay opacity** for visual QA.
* **Export** composited PNG (image + heatmap) and **share**.
* **Export** machine‑readable **JSON** with normalized coordinates (0..1) for downstream tools.

---

## How It Works

1. **Preprocess**: The input image is resized to a working map (≤512 px), converted to grayscale, then filtered with **Sobel** and **Gaussian blur** to approximate visual saliency.
2. **Normalize & bias**: Values are normalized (0..1) and combined with a mild **center‑bias** (common in gaze behavior).
3. **Metrics**: We compute **coverage**, **Rule‑of‑Thirds alignment** (centroid to thirds points), **human‑readable hotspots**, and **low‑attention corners** (candidates for logo placement).
4. **Overlay**: A semi‑transparent heatmap is resized to the original image and rendered on top.
5. **Design Hints**: A small sampled palette yields **dominant** and **accent** colors; **typefaces** are suggested for clarity and stopping power.

> **Note**: This is a **saliency‑based proxy**, not true eye‑tracking. Validate critical creatives with A/B tests.

---

## Exported Data (JSON Schema)

The app exports normalized metrics so they are resolution‑agnostic:

```json
{
  "image_size": {"width": W, "height": H},
  "coverage_percent": "float%",
  "thirds_score_percent": "float%",
  "top_hotspots_norm": [
    {"x": 0..1, "y": 0..1, "value": 0..1}
  ],
  "low_attention_zones_norm": [
    {"left": 0..1, "top": 0..1, "width": 0..1, "height": 0..1}
  ],
  "recommended_logo_zone_norm": { "left": 0..1, "top": 0..1, "width": 0..1, "height": 0..1 },
  "quadrant_share_percent": ["TL%", "TR%", "BL%", "BR%"],
  "notes": "Saliency-based (non-ML) heatmap; not true eye-tracking."
}
```

---

## Getting Started

### Requirements

* **Flutter** ≥ 3.0, **Dart** ≥ 3.0
* **Android** SDK 34 (minSdk 21)
* Tested on Android via **Android Studio** / `flutter run`

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

> If you prefer Android Studio: open the project → choose a device/emulator → Run.

---

## Usage

1. **Pick an image** from your device.
2. **Adjust overlay opacity** to inspect the heat distribution.
3. Read **Key Insights** (Coverage, Rule of Thirds, hotspots, recommended logo area, low‑attention zones).
4. Check **Design Hints** for dominant/accent colors and typographic guidance.
5. **Export** PNG (composited) and **JSON**; optionally **Share** both.

---

## Project Structure

```
lib/
  models/
    app_state.dart
    heatmap_metrics.dart
  services/
    heatmap_service.dart
    export_service.dart
    color_service.dart
  screens/
    home/
      home_screen.dart
    results/
      results_screen.dart
  widgets/
    ...
```

---

## Tech Notes & Constraints

* Saliency is computed with classic CV (Sobel + Gaussian + center‑bias). It is **fast and offline**, but **not semantic** (unlike Grad‑CAM).
* PNG export uses a **RepaintBoundary** capture to ensure UI‑accurate compositing.
* JSON uses **normalized coordinates** so you can re‑project onto any resolution.
* Privacy: images are processed **locally**; no network calls.

---

## Roadmap

* Optional **server‑side Grad‑CAM** for semantic emphasis (class‑aware).
* Optional **on‑device TFLite saliency model**.
* Batch analysis & CSV export.
* Accessibility checks (contrast / text size heuristics).

---

## License

MIT License. See `LICENSE` for details.

---

## 👤 Developer

**Bektas Sari**
Email: [bektas.sari@gmail.com](mailto:bektas.sari@gmail.com)  <br>
GitHub: [https://github.com/bektas-sari](https://github.com/bektas-sari) <br>
LinkedIn: [www.linkedin.com/in/bektas-sari](http://www.linkedin.com/in/bektas-sari) <br>
Researchgate: [https://www.researchgate.net/profile/Bektas-Sari-3](https://www.researchgate.net/profile/Bektas-Sari-3) <br>
Academia: [https://independent.academia.edu/bektassari](https://independent.academia.edu/bektassari) <br>

---
