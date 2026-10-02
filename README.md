# Polaroid Studio

A cross-platform Polaroid photo creation application built with Flutter.

Turn any photo into a vintage Polaroid print: pick a frame, write a caption,
dial in a film look, stamp the date, watch the print develop, then export the
**whole composition** (photo + frame + caption + date + filter + shadow) as a
high-resolution image. Everything runs on-device — nothing is uploaded
anywhere.

## Features

* Camera capture
* Gallery import
* Polaroid frames
* Vintage filters
* Caption editor
* Date stamps
* Developing animation
* High-resolution export
* Gallery saving
* Native sharing
* Responsive interface

Details:

* **6 Polaroid frames** — classic, warm white, vintage cream, kraft, midnight
  and instant black, each with its own paper colour, border geometry and drop
  shadow.
* **8 film looks** — original, black & white, sepia, warm, cool, faded,
  vintage and instant, rendered from colour matrices so they match exactly in
  the editor, the preview and the exported file.
* **Caption typography** — 5 bundled handwriting/typewriter fonts with size,
  alignment, letter spacing and ink colour, inside a live counter.
* **High-resolution export** — rendered at `720 logical px × 3.0 pixel ratio`
  (2160 px wide) off-screen so the live preview and the exported file agree
  pixel for pixel.
* **Interactive editor** — pinch to zoom, drag to reposition, two-finger
  rotate; double tap or slider to reset. The photo always stays inside the
  square window — no empty corners are ever exported.

## Tech Stack

* Flutter
* Dart
* Material 3
* Flutter Web
* Android
* iOS

Key packages: `camera` (+ endorsed `camera_web`), `image_picker`,
`image_gallery_saver`, `share_plus`, `gal`, `flutter_colorfilters`,
`shared_preferences`, `path_provider`, `screenshot`, `http`.

## Run Locally

```bash
flutter pub get
flutter run
```

Requirements: Flutter 3.47.x (Dart 3.13+). For Android builds: Android SDK
(platforms 36/37, build-tools 36.0.0, NDK 28.2.13676358) with JDK 17+; for
iOS: Xcode.

## Run Web

```bash
flutter run -d chrome
```

Notes for the web build:

* The browser's `getUserMedia` powers the viewfinder (through `camera_web`);
  Chrome/Firefox/Edge shows its own camera permission prompt on first open.
* `getUserMedia` requires a secure context: `https://` or
  `http://localhost` / `127.0.0.1`.
* To test without a physical webcam:

```bash
flutter run -d chrome --web-browser-flag=--use-fake-ui-for-media-stream \
  --web-browser-flag=--use-fake-device-for-media-stream
```

## Build Web

```bash
flutter build web --release
```

The production bundle is generated in `build/web/`.

## Deployment

The Web version is deployed through Vercel.

```text
Mobile:
Android / iOS

Web:
Vercel
```

* `vercel.json` builds the project with Flutter in CI and serves the
  contents of `build/web` as the production website.
* SPA routing is configured with a rewrite of all paths to `index.html`, so
  refreshing a route never returns a 404.
* Workflow: push to `main` on GitHub → Vercel → automatic production
  deployment.

```bash
# local production deploy with the Vercel CLI
vercel --prod
```

## Platform notes

### Web

* **Camera** — browser `getUserMedia` via `camera_web` (photo capture only).
* **Gallery import** — browser file picker.
* **Save to gallery** — the exported PNG is downloaded to the browser's
  download folder (there is no device gallery on web).
* **Sharing** — Web Share API when available, with an automatic download
  fallback.
* **Recent Creations** — stays empty on web (`path_provider` is not
  available in the browser); exports still download successfully.

### Android / iOS

* Native camera and permission flows (`camera` plugin).
* Saved to the device gallery (`gal` / `image_gallery_saver`).
* Native share sheet (`share_plus`).
* Recent creations persist in the app documents folder.

## Project Structure

```text
lib/
  app/            app entry, theme (Material 3 light/dark), settings scope
  models/         PolaroidConfig, frame styles, filter presets, caption styles
  services/       picking, camera, permissions, colour filters,
                  high-resolution export, history repository, settings,
                  browser download, camera guard (web)
  screens/        home, camera, editor, preview, settings
  widgets/        PolaroidFrame (geometry + gestures), frame/filter pickers,
                  caption editor, toolbar, date stamp, developing animation
  utils/          constants, helpers (pan/zoom/tilt maths), extensions
assets/
  fonts/          bundled OFL fonts (Caveat, Patrick Hand, Shadows Into
                  Light, Homemade Apple, Special Elite, Playfair Display)
  images/         sample_photo.jpg
test/             unit + widget tests (63 cases)
web/              index.html (title, viewport, camera guard), manifest
android/          Android platform project
ios/              iOS platform project
tool/             asset generator for the sample photo
vercel.json       Vercel build + SPA routing configuration
```

The important invariant: `FrameLayout.forStyle()` is the single source of
truth for the frame geometry, so the live preview, the editor and the
off-screen export renderer always agree pixel for pixel.

## Tests

```bash
flutter analyze   # strict lints (strict-casts / strict-inference)
flutter test      # 63 unit + widget tests
```

Covers JSON round trips and corruption tolerance for every configuration
model, the pan/zoom/tilt clamping maths (including a "no empty corners" proof
over the rendered transform), colour-filter matrices, frame geometry, and the
home/settings/frame widgets (theme + date format persistence included).

## Limitations

* Export always produces a PNG sized from the frame layout; there is no
  custom output size or format picker.
* The camera flow supports photo capture only (no video).
* Recent creations are removed if the app is uninstalled; there is no cloud
  backup (by design), and the list is empty on web.
* Release builds are signed with the debug key; add your own signing config
  in `android/app/build.gradle.kts` before shipping to Play.

## Licences

Fonts are distributed under the SIL Open Font License 1.1 / Apache 2.0 and
their licence files are bundled under `assets/fonts`. The sample photo is
generated by `tool/make_sample_image.dart`.
