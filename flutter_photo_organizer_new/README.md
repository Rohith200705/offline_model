# Photo Organizer - Flutter Android App

A Flutter-based Android application for offline photo organization and chatbot assistance. This is the mobile port of the original Python/Streamlit desktop application.

## Features

- **Auto-Organize Photos**: Sort by persons, locations, objects, events, or date
- **Face Recognition**: Detect and identify people in photos using TFLite models
- **Scene Classification**: Detect locations (indoor, beach, mountain, etc.) using TFLite
- **Object Detection**: Identify objects in photos using YOLOv8n TFLite
- **Chat Assistant**: Ask questions about your photos (rule-based + optional LLM)
- **Privacy First**: 100% offline - all processing happens on device
- **Material 3 UI**: Modern Android interface with bottom navigation

## Project Structure

```
flutter_photo_organizer/
├── android/                    # Android-specific files
│   ├── app/
│   │   ├── build.gradle       # App-level Gradle config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../MainActivity.kt
│   │       ├── res/
│   │       │   ├── values/styles.xml
│   │       │   ├── drawable/launch_background.xml
│   │       │   └── xml/file_paths.xml
│   ├── build.gradle           # Project-level Gradle config
│   └── settings.gradle
├── assets/
│   ├── models/                # TFLite model files (add your models here)
│   │   ├── face/
│   │   │   ├── ultraface.tflite
│   │   │   └── face_recognition_sface.tflite
│   │   ├── classification/
│   │   │   └── scene_classifier.tflite
│   │   └── object/
│   │       └── yolov8n.tflite
│   └── images/
├── lib/
│   ├── main.dart              # App entry point
│   ├── core/
│   │   ├── constants/         # App constants & theme
│   │   ├── database/          # SQLite database service
│   │   ├── models/            # Data models (freezed)
│   │   ├── services/          # ML services (TFLite)
│   │   │   ├── ml_interfaces.dart
│   │   │   ├── tflite_face_detector.dart
│   │   │   ├── tflite_face_recognizer.dart
│   │   │   ├── tflite_scene_classifier.dart
│   │   │   ├── tflite_object_detector.dart
│   │   │   └── image_processor.dart
│   │   └── utils/             # Utility functions
│   ├── features/
│   │   ├── home/              # Home screen
│   │   ├── organize/          # Photo organization
│   │   ├── chat/              # Chat assistant
│   │   ├── faces/             # Face management
│   │   └── stats/             # Statistics
│   └── shared/
│       ├── constants/         # Shared constants
│       └── widgets/           # Shared UI components
└── pubspec.yaml               # Dependencies
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2+
- Android Studio / VS Code
- Android device or emulator (API 23+)

### Installation

1. **Clone and navigate to the project:**
   ```bash
   cd flutter_photo_organizer
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate code (for freezed/json_serializable):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Add TFLite models:**
   Place your converted TFLite models in the appropriate directories under `assets/models/`:
   - `assets/models/face/ultraface.tflite` - Face detection
   - `assets/models/face/face_recognition_sface.tflite` - Face recognition
   - `assets/models/classification/scene_classifier.tflite` - Scene classification
   - `assets/models/object/yolov8n.tflite` - Object detection (YOLOv8n)

5. **Run the app:**
   ```bash
   flutter run
   ```

### Model Conversion

Convert the original ONNX models to TFLite:

```bash
# Face detection (UltraFace)
python -m tf2onnx.convert --input models/face/ultraface.onnx --output ultraface.onnx
# Then use TensorFlow Lite converter

# Face recognition (SFace)
# Similar process for face_recognition_sface_2021dec.onnx

# Scene classification
# Convert your custom model or use MobileNetV2

# Object detection (YOLOv8n)
# Use ultralytics export: yolo export model=yolov8n.pt format=tflite
```

## Architecture

### Core Services

- **DatabaseService**: SQLite wrapper for photos, faces, and chat history
- **ImageProcessor**: Coordinates all ML services
- **TFLiteFaceDetector**: UltraFace model for face detection
- **TFLiteFaceRecognizer**: SFace model for face embeddings
- **TFLiteSceneClassifier**: Scene classification model
- **TFLiteObjectDetector**: YOLOv8n for object detection

### Domain Layer

- **PhotoOrganizer**: Orchestrates photo analysis and file organization
- **PhotoChatbot**: Rule-based chat assistant with photo context
- **Repositories**: Data access layer for each feature

### UI Layer

- **HomeScreen**: Dashboard with stats and quick actions
- **OrganizeScreen**: Directory picker and organization options
- **ChatScreen**: Chat interface with photo analysis
- **FacesScreen**: Known face management and testing
- **StatsScreen**: Charts and statistics visualization

## Key Differences from Python Version

| Feature | Python (Desktop) | Flutter (Android) |
|---------|------------------|-------------------|
| UI Framework | Streamlit | Flutter Material 3 |
| ML Runtime | ONNX Runtime | TFLite Flutter |
| Database | SQLite (file) | SQLite (sqflite) |
| File Access | Local paths | Scoped storage / MediaStore |
| Chat LLM | ctransformers (GGUF) | Rule-based + optional TFLite LLM |
| Background Processing | Threading | Isolates / Compute |

## Permissions

The app requires:
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` - Access photos
- `WRITE_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` - Organize photos
- `CAMERA` - Take photos for face enrollment

## Building for Release

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## Troubleshooting

### Models not loading
- Ensure models are in `assets/models/` and listed in `pubspec.yaml`
- Run `flutter clean && flutter pub get` after adding models
- Check model input/output shapes match the code

### Storage permission issues
- On Android 11+, use `MANAGE_EXTERNAL_STORAGE` permission
- For scoped storage, use MediaStore API or Storage Access Framework

### Performance
- Run ML inference on background isolates
- Consider using GPU delegate for TFLite
- Cache image thumbnails

## License

MIT License - Same as the original Python project.