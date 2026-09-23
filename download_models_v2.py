# Download pre-converted TFLite models - alternative URLs

import os
import urllib.request

# Working URLs for TFLite models
MODEL_URLS = {
    "object/yolov8n.tflite": [
        "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.tflite",
        "https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.tflite",
    ],
    "classification/mobilenet_v2.tflite": [
        "https://storage.googleapis.com/download.tensorflow.org/models/tflite/mobilenet_v2_1.0_224_quant.tflite",
        "https://tfhub.dev/google/lite-model/mobilenet_v2_1.0_224/1/default/1?lite-format=tflite",
    ],
}

def download_with_fallback(urls, dest_path):
    """Try multiple URLs"""
    for url in urls:
        try:
            print(f"  Trying: {url}")
            urllib.request.urlretrieve(url, dest_path)
            print(f"  Success!")
            return True
        except Exception as e:
            print(f"  Failed: {e}")
    return False

def main():
    base_dir = "flutter_photo_organizer/assets/models"
    os.makedirs(base_dir, exist_ok=True)
    
    print("=" * 60)
    print("Downloading TFLite Models (Alternative URLs)")
    print("=" * 60)
    
    # YOLOv8n
    print("\n1. YOLOv8n (Object Detection)")
    yolov8_path = os.path.join(base_dir, "object/yolov8n.tflite")
    os.makedirs(os.path.dirname(yolov8_path), exist_ok=True)
    if not os.path.exists(yolov8_path):
        download_with_fallback(MODEL_URLS["object/yolov8n.tflite"], yolov8_path)
    else:
        print("  Already exists")
    
    # MobileNetV2
    print("\n2. MobileNetV2 (Scene Classification)")
    mobilenet_path = os.path.join(base_dir, "classification/mobilenet_v2.tflite")
    os.makedirs(os.path.dirname(mobilenet_path), exist_ok=True)
    if not os.path.exists(mobilenet_path):
        download_with_fallback(MODEL_URLS["classification/mobilenet_v2.tflite"], mobilenet_path)
    else:
        print("  Already exists")
    
    # Rename for consistency
    scene_path = os.path.join(base_dir, "classification/scene_classifier.tflite")
    if os.path.exists(mobilenet_path) and not os.path.exists(scene_path):
        import shutil
        shutil.copy2(mobilenet_path, scene_path)
        print(f"  Copied as scene_classifier.tflite")
    
    # Check face models
    print("\n3. Face Models (need ONNX->TFLite conversion)")
    face_dir = os.path.join(base_dir, "face")
    if os.path.exists(os.path.join(face_dir, "ultraface.onnx")):
        print(f"  Found ultraface.onnx (ready for conversion)")
    if os.path.exists(os.path.join(face_dir, "face_recognition_sface.onnx")):
        print(f"  Found face_recognition_sface.onnx (ready for conversion)")
    
    print("\n" + "=" * 60)
    print("Next steps:")
    print("1. For face models: Use Python 3.11 with onnx/tensorflow to convert")
    print("2. Or use online converter: https://convertmodel.com/")
    print("3. For YOLOv8n: Install ultralytics and run 'yolo export model=yolov8n.pt format=tflite'")
    print("=" * 60)

if __name__ == "__main__":
    main()