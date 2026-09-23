# Download pre-converted TFLite models for Flutter app

import os
import urllib.request
import hashlib

MODELS = {
    "face/ultraface.tflite": {
        "url": "https://github.com/opencv/opencv_3rdparty/raw/dnn_samples_face_detector_20170830/opencv_face_detector_uint8.pb",
        "note": "UltraFace not directly available as TFLite. Use alternative or convert from ONNX."
    },
    "face/face_recognition_sface.tflite": {
        "url": "https://github.com/opencv/opencv_3rdparty/raw/dnn_samples_face_detector_20170830/face_recognition_sface_2021dec.onnx",
        "note": "SFace ONNX - needs conversion to TFLite"
    },
    "object/yolov8n.tflite": {
        "url": "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.tflite",
        "note": "YOLOv8n TFLite from Ultralytics"
    },
    "classification/scene_classifier.tflite": {
        "url": "https://storage.googleapis.com/download.tensorflow.org/models/tflite/mobilenet_v2_1.0_224.tflite",
        "note": "MobileNetV2 for classification"
    }
}

def download_file(url, dest_path):
    """Download file with progress"""
    try:
        print(f"Downloading {os.path.basename(dest_path)}...")
        
        def progress(block_num, block_size, total_size):
            if total_size > 0:
                percent = min(100, (block_num * block_size * 100) // total_size)
                print(f"\r  Progress: {percent}%", end="", flush=True)
        
        urllib.request.urlretrieve(url, dest_path, reporthook=progress)
        print(f"\r  Done! Saved to {dest_path}")
        return True
    except Exception as e:
        print(f"\n  Error: {e}")
        return False

def verify_file(path, expected_size=None):
    """Verify downloaded file"""
    if not os.path.exists(path):
        return False
    size = os.path.getsize(path)
    print(f"  File size: {size / 1024 / 1024:.2f} MB")
    if expected_size and abs(size - expected_size) > 1024:
        print(f"  Warning: Size mismatch (expected ~{expected_size / 1024 / 1024:.2f} MB)")
        return False
    return True

def main():
    base_dir = "flutter_photo_organizer/assets/models"
    os.makedirs(base_dir, exist_ok=True)
    
    print("=" * 60)
    print("Downloading TFLite Models for Flutter Photo Organizer")
    print("=" * 60)
    
    # Download YOLOv8n
    print("\n1. YOLOv8n (Object Detection)")
    yolov8_path = os.path.join(base_dir, "object/yolov8n.tflite")
    os.makedirs(os.path.dirname(yolov8_path), exist_ok=True)
    if not os.path.exists(yolov8_path):
        download_file(MODELS["object/yolov8n.tflite"]["url"], yolov8_path)
    else:
        print("  Already exists")
    verify_file(yolov8_path)
    
    # Download MobileNetV2
    print("\n2. MobileNetV2 (Scene Classification)")
    mobilenet_path = os.path.join(base_dir, "classification/scene_classifier.tflite")
    os.makedirs(os.path.dirname(mobilenet_path), exist_ok=True)
    if not os.path.exists(mobilenet_path):
        download_file(MODELS["classification/scene_classifier.tflite"]["url"], mobilenet_path)
    else:
        print("  Already exists")
    verify_file(mobilenet_path)
    
    # Face models - need conversion from ONNX
    print("\n3. Face Models (UltraFace & SFace)")
    print("  These require ONNX -> TFLite conversion.")
    print("  Source ONNX files in models/face/:")
    print("    - ultraface.onnx")
    print("    - face_recognition_sface_2021dec.onnx")
    print("  ")
    print("  To convert, you need Python 3.11 or earlier with:")
    print("    pip install onnx tensorflow onnx-tf")
    print("  Then run: python convert_models.py")
    print("  ")
    print("  Or use online converters like:")
    print("    - https://convertmodel.com/")
    print("    - https://github.com/onnx/onnx-tensorflow")
    
    # Copy existing ONNX as reference
    import shutil
    face_src = "models/face/ultraface.onnx"
    face_dst = os.path.join(base_dir, "face/ultraface.onnx")
    if os.path.exists(face_src):
        os.makedirs(os.path.dirname(face_dst), exist_ok=True)
        shutil.copy2(face_src, face_dst)
        print(f"  Copied reference: {face_dst}")
    
    face_src2 = "models/face/face_recognition_sface_2021dec.onnx"
    face_dst2 = os.path.join(base_dir, "face/face_recognition_sface.onnx")
    if os.path.exists(face_src2):
        shutil.copy2(face_src2, face_dst2)
        print(f"  Copied reference: {face_dst2}")
    
    print("\n" + "=" * 60)
    print("Download complete!")
    print(f"Models saved to: {base_dir}/")
    print("=" * 60)
    
    # Show structure
    print("\nModel directory structure:")
    for root, dirs, files in os.walk(base_dir):
        level = root.replace(base_dir, '').count(os.sep)
        indent = ' ' * 2 * level
        print(f"{indent}{os.path.basename(root)}/")
        subindent = ' ' * 2 * (level + 1)
        for file in files:
            size = os.path.getsize(os.path.join(root, file))
            print(f"{subindent}{file} ({size / 1024:.1f} KB)")

if __name__ == "__main__":
    main()