# Export YOLOv8n to TFLite using ultralytics

try:
    from ultralytics import YOLO
    
    print("Loading YOLOv8n...")
    model = YOLO('yolov8n.pt')  # This will auto-download if not present
    
    print("Exporting to TFLite...")
    model.export(format='tflite', imgsz=640)
    
    # Find the exported model
    import glob
    tflite_files = glob.glob('**/*.tflite', recursive=True)
    if tflite_files:
        print(f"Exported: {tflite_files}")
        import shutil
        dest = "flutter_photo_organizer/assets/models/object/yolov8n.tflite"
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(tflite_files[0], dest)
        print(f"Copied to: {dest}")
    else:
        print("No TFLite file found after export")
        
except ImportError:
    print("ultralytics not installed. Install with: pip install ultralytics")
except Exception as e:
    print(f"Error: {e}")
    print("\nManual steps:")
    print("1. pip install ultralytics")
    print("2. python -c \"from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='tflite')\"")
    print("3. Copy the generated .tflite file to flutter_photo_organizer/assets/models/object/")