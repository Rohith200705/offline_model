# Model Setup Guide

## Current Status

The Flutter app is structured to use **TensorFlow Lite (.tflite)** models via `tflite_flutter`. However, the source models from the Python project are in **ONNX format**. 

### Models Available (in `flutter_photo_organizer/assets/models/`):

| Model | Format | Size | Purpose |
|-------|--------|------|---------|
| `face/ultraface.onnx` | ONNX | 1.2 MB | Face Detection |
| `face/face_recognition_sface.onnx` | ONNX | 37 MB | Face Recognition (SFace) |
| `object/yolov8n.onnx` | ONNX | 12 MB | Object Detection (YOLOv8n) |

### Models Still Needed (convert from ONNX or download):

| Model | Target Format | Purpose |
|-------|---------------|---------|
| `face/ultraface.tflite` | TFLite | Face Detection |
| `face/face_recognition_sface.tflite` | TFLite | Face Recognition |
| `object/yolov8n.tflite` | TFLite | Object Detection |
| `classification/scene_classifier.tflite` | TFLite | Scene Classification |

---

## Option 1: Convert ONNX → TFLite (Recommended)

### Prerequisites
- Python **3.11 or earlier** (TensorFlow doesn't support Python 3.12+)
- Virtual environment recommended

### Setup Conversion Environment
```bash
# Create virtual environment with Python 3.11
python3.11 -m venv venv_tflite
source venv_tflite/bin/activate  # Linux/Mac
# or
venv_tflite\Scripts\activate  # Windows

# Install conversion dependencies
pip install onnx tensorflow onnx-tf onnxslim
```

### Convert Face Models
```bash
# UltraFace (Face Detection)
python -c "
import onnx
import tensorflow as tf
from onnx_tf.backend import prepare

onnx_model = onnx.load('flutter_photo_organizer/assets/models/face/ultraface.onnx')
tf_rep = prepare(onnx_model)
tf_rep.export_graph('ultraface_tf')
converter = tf.lite.TFLiteConverter.from_saved_model('ultraface_tf')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
with open('flutter_photo_organizer/assets/models/face/ultraface.tflite', 'wb') as f:
    f.write(tflite_model)
print('UltraFace TFLite saved')
"

# SFace (Face Recognition)
python -c "
import onnx
import tensorflow as tf
from onnx_tf.backend import prepare

onnx_model = onnx.load('flutter_photo_organizer/assets/models/face/face_recognition_sface.onnx')
tf_rep = prepare(onnx_model)
tf_rep.export_graph('sface_tf')
converter = tf.lite.TFLiteConverter.from_saved_model('sface_tf')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
with open('flutter_photo_organizer/assets/models/face/face_recognition_sface.tflite', 'wb') as f:
    f.write(tflite_model)
print('SFace TFLite saved')
"
```

### Convert YOLOv8n (Object Detection)
```bash
# Using ultralytics (Linux/macOS only for TFLite)
# On Windows, export to ONNX first, then convert
python -c "
from ultralytics import YOLO
model = YOLO('flutter_photo_organizer/assets/models/object/yolov8n.onnx')
model.export(format='tflite', imgsz=640)
# Copy generated .tflite to flutter_photo_organizer/assets/models/object/yolov8n.tflite
"
```

### Scene Classification Model
Download MobileNetV2 TFLite:
```bash
# Quantized version (smaller, faster)
wget -O flutter_photo_organizer/assets/models/classification/scene_classifier.tflite \
  "https://storage.googleapis.com/download.tensorflow.org/models/tflite/mobilenet_v2_1.0_224_quant.tflite"
```

---

## Option 2: Use Online Converters

If you can't set up the Python environment, use online tools:

1. **ConvertModel.com** - https://convertmodel.com/
   - Upload ONNX → Download TFLite
   - Supports batch conversion

2. **ONNX to TF Lite Converter** - https://github.com/onnx/onnx-tensorflow
   - Run in Google Colab (free GPU)

3. **Netron** - https://netron.app/
   - Visualize models, verify conversions

### Google Colab Conversion (Free)
```python
# Run in Google Colab notebook
!pip install onnx tensorflow onnx-tf onnxslim ultralytics

# UltraFace
import onnx, tensorflow as tf
from onnx_tf.backend import prepare
model = onnx.load('ultraface.onnx')
tf_rep = prepare(model)
tf_rep.export_graph('ultraface_tf')
converter = tf.lite.TFLiteConverter.from_saved_model('ultraface_tf')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
open('ultraface.tflite', 'wb').write(converter.convert())

# SFace (large model, may need more memory)
model = onnx.load('face_recognition_sface.onnx')
tf_rep = prepare(model)
tf_rep.export_graph('sface_tf')
converter = tf.lite.TFLiteConverter.from_saved_model('sface_tf')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
open('face_recognition_sface.tflite', 'wb').write(converter.convert())

# YOLOv8n
from ultralytics import YOLO
YOLO('yolov8n.onnx').export(format='tflite', imgsz=640)

# Download MobileNetV2
!wget -O scene_classifier.tflite \
  "https://storage.googleapis.com/download.tensorflow.org/models/tflite/mobilenet_v2_1.0_224_quant.tflite"
```

Then download the generated `.tflite` files and place them in `flutter_photo_organizer/assets/models/`

---

## Option 3: Use Pre-converted Models

Download from these sources:

| Model | Source |
|-------|--------|
| UltraFace TFLite | https://github.com/opencv/opencv_3rdparty/tree/dnn_samples_face_detector_20170830 |
| SFace TFLite | Convert from ONNX (no direct TFLite available) |
| YOLOv8n TFLite | Export via ultralytics on Linux/macOS |
| MobileNetV2 TFLite | https://tfhub.dev/google/lite-model/mobilenet_v2_1.0_224/1 |

---

## App Behavior Without Models

The app **will run without TFLite models** but with limited functionality:

| Feature | Without Models | With Models |
|---------|----------------|-------------|
| Face Detection | ❌ Heuristic only | ✅ UltraFace |
| Face Recognition | ❌ Returns "unknown" | ✅ SFace embeddings |
| Scene Classification | ✅ Color heuristics | ✅ MobileNetV2 |
| Object Detection | ❌ Heuristic only | ✅ YOLOv8n |
| Photo Organization | ✅ Basic | ✅ Full AI-powered |
| Chat Assistant | ✅ Rule-based | ✅ Rule-based + context |

The fallbacks use OpenCV-style color/shape heuristics implemented in Dart.

---

## Verification

After placing `.tflite` files in `assets/models/`:

```bash
# 1. Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Run app
flutter run

# 3. Check logs for model loading
# Look for: "TFLite model loaded" or "Using fallback"
```

---

## Troubleshooting

### "Model file not found"
- Ensure file is in `assets/models/` subdirectory
- Run `flutter pub get` after adding files
- Check `pubspec.yaml` has `assets/models/` entry

### "Input shape mismatch"
- Verify model input dimensions match code expectations
- UltraFace: 320x240, 3 channels
- SFace: 112x112, 3 channels
- YOLOv8n: 640x640, 3 channels
- MobileNetV2: 224x224, 3 channels

### "Delegate not supported"
- GPU delegate may not work on all devices
- App falls back to CPU automatically

### Large model size (SFace ~37 MB)
- Consider quantization: `converter.optimizations = [tf.lite.Optimize.DEFAULT]`
- Or use float16: `converter.target_spec.supported_types = [tf.float16]`

---

## Alternative: ONNX Runtime in Flutter

If you prefer not to convert, you can use `onnxruntime` Flutter package instead of `tflite_flutter`:

```yaml
dependencies:
  onnxruntime: ^1.17.0  # Instead of tflite_flutter
```

Then update the ML service implementations to use ONNX Runtime API instead of TFLite. This avoids conversion entirely but requires code changes.