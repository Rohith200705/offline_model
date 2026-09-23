# Model Conversion Script
# Converts ONNX models to TFLite for Flutter app

import os
import sys

def convert_onnx_to_tflite(onnx_path, tflite_path, input_shape=None):
    """Convert ONNX model to TFLite via TensorFlow"""
    try:
        import onnx
        import tensorflow as tf
        from onnx_tf.backend import prepare
        
        print(f"Loading ONNX model: {onnx_path}")
        onnx_model = onnx.load(onnx_path)
        onnx.checker.check_model(onnx_model)
        
        print("Converting ONNX to TensorFlow...")
        tf_rep = prepare(onnx_model)
        
        # Save as TensorFlow SavedModel
        tf_savedmodel_path = onnx_path.replace('.onnx', '_tf')
        tf_rep.export_graph(tf_savedmodel_path)
        
        print("Converting TensorFlow to TFLite...")
        converter = tf.lite.TFLiteConverter.from_saved_model(tf_savedmodel_path)
        
        # Optimization
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # For quantization (optional, reduces size)
        # converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"Saved TFLite model: {tflite_path}")
        print(f"Model size: {len(tflite_model) / 1024 / 1024:.2f} MB")
        
        # Clean up
        import shutil
        shutil.rmtree(tf_savedmodel_path, ignore_errors=True)
        
        return True
        
    except Exception as e:
        print(f"Error converting {onnx_path}: {e}")
        return False


def convert_ultraface():
    """Convert UltraFace ONNX to TFLite"""
    onnx_path = "models/face/ultraface.onnx"
    tflite_path = "flutter_photo_organizer/assets/models/face/ultraface.tflite"
    
    os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
    
    if not os.path.exists(onnx_path):
        print(f"ONNX model not found: {onnx_path}")
        return False
    
    return convert_onnx_to_tflite(onnx_path, tflite_path)


def convert_sface():
    """Convert SFace ONNX to TFLite"""
    onnx_path = "models/face/face_recognition_sface_2021dec.onnx"
    tflite_path = "flutter_photo_organizer/assets/models/face/face_recognition_sface.tflite"
    
    os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
    
    if not os.path.exists(onnx_path):
        print(f"ONNX model not found: {onnx_path}")
        return False
    
    return convert_onnx_to_tflite(onnx_path, tflite_path)


def download_yolov8n_tflite():
    """Download YOLOv8n TFLite model"""
    import urllib.request
    
    url = "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.tflite"
    tflite_path = "flutter_photo_organizer/assets/models/object/yolov8n.tflite"
    
    os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
    
    try:
        print(f"Downloading YOLOv8n TFLite from {url}...")
        urllib.request.urlretrieve(url, tflite_path)
        print(f"Saved: {tflite_path}")
        return True
    except Exception as e:
        print(f"Error downloading YOLOv8n: {e}")
        print("Alternative: Run 'yolo export model=yolov8n.pt format=tflite' with ultralytics installed")
        return False


def download_mobilenetv2_tflite():
    """Download MobileNetV2 TFLite for scene classification"""
    import urllib.request
    
    # MobileNetV2 from TensorFlow Hub
    url = "https://storage.googleapis.com/download.tensorflow.org/models/tflite/mobilenet_v2_1.0_224.tflite"
    tflite_path = "flutter_photo_organizer/assets/models/classification/scene_classifier.tflite"
    
    os.makedirs(os.path.dirname(tflite_path), exist_ok=True)
    
    try:
        print(f"Downloading MobileNetV2 TFLite from {url}...")
        urllib.request.urlretrieve(url, tflite_path)
        print(f"Saved: {tflite_path}")
        return True
    except Exception as e:
        print(f"Error downloading MobileNetV2: {e}")
        return False


if __name__ == "__main__":
    print("=" * 60)
    print("Model Conversion for Flutter Photo Organizer")
    print("=" * 60)
    
    # Check dependencies
    try:
        import onnx
        import tensorflow as tf
        import onnx_tf
        print("Dependencies OK")
    except ImportError as e:
        print(f"Missing dependencies: {e}")
        print("Install with: pip install onnx tensorflow onnx-tf")
        sys.exit(1)
    
    # Convert face models
    print("\n1. Converting UltraFace...")
    convert_ultraface()
    
    print("\n2. Converting SFace...")
    convert_sface()
    
    # Download other models
    print("\n3. Downloading YOLOv8n...")
    download_yolov8n_tflite()
    
    print("\n4. Downloading MobileNetV2...")
    download_mobilenetv2_tflite()
    
    print("\n" + "=" * 60)
    print("Conversion complete!")
    print("Check flutter_photo_organizer/assets/models/")
    print("=" * 60)