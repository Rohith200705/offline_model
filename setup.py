import os
import sys
import requests
from pathlib import Path
from tqdm import tqdm

BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / "models"

MODELS_TO_DOWNLOAD = {
    "face/deploy.prototxt": {
        "url": "https://raw.githubusercontent.com/opencv/opencv/master/samples/dnn/face_detector/deploy.prototxt",
        "description": "Face detector config",
        "size_mb": 0.01,
    },
    "face/res10_300x300_ssd_iter_140000.caffemodel": {
        "url": "https://raw.githubusercontent.com/opencv/opencv_3rdparty/dnn_samples_face_detector_20170830/res10_300x300_ssd_iter_140000.caffemodel",
        "description": "Face detector model",
        "size_mb": 10.8,
    },
    "face/face_recognition_sface_2021dec.onnx": {
        "url": "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx",
        "description": "Face recognition model",
        "size_mb": 4.6,
    },
}


def download_file(url, dest_path, description=""):
    if dest_path.exists():
        print(f"  [SKIP] {dest_path.name} already exists")
        return True

    print(f"  [DOWNLOAD] {description}...")

    try:
        response = requests.get(url, stream=True, timeout=120)
        response.raise_for_status()

        total_size = int(response.headers.get("content-length", 0))
        dest_path.parent.mkdir(parents=True, exist_ok=True)

        with open(dest_path, "wb") as f:
            with tqdm(total=total_size, unit="B", unit_scale=True, desc=dest_path.name) as pbar:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        pbar.update(len(chunk))

        print(f"  [OK] {dest_path.name}")
        return True

    except Exception as e:
        print(f"  [ERROR] Failed to download {dest_path.name}: {e}")
        if dest_path.exists():
            dest_path.unlink()
        return False


def setup_face_models():
    print("\n=== Setting up face detection models ===")
    face_dir = MODELS_DIR / "face"
    face_dir.mkdir(parents=True, exist_ok=True)

    success = True
    for filename, info in MODELS_TO_DOWNLOAD.items():
        if filename.startswith("face/"):
            dest = MODELS_DIR / filename
            if not download_file(info["url"], dest, info["description"]):
                success = False

    return success


def setup_chatbot_model():
    print("\n=== Chatbot Model Setup ===")
    chatbot_dir = MODELS_DIR / "chatbot"
    chatbot_dir.mkdir(parents=True, exist_ok=True)

    existing = list(chatbot_dir.glob("*.gguf"))
    if existing:
        print(f"  [SKIP] Chatbot model already exists: {existing[0].name}")
        return True

    print("""
  No chatbot model found. Please download a small GGUF model:

  Option 1 (Recommended - ~800MB, good quality):
    Download from: https://huggingface.co/TheBloke/SmolLM2-135M-Instruct-GGUF
    File: smollm2-135m-instruct-q4_k_m.gguf
    Place it in: {chatbot_dir}

  Option 2 (Ultra-lightweight - ~200MB):
    Download from: https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
    File: tinyllama-1.1b-chat-v1.0.q2_k.gguf
    Place it in: {chatbot_dir}

  Option 3 (Skip chatbot - image features still work):
    Press Enter to continue without chatbot model.
""".format(chatbot_dir=chatbot_dir))

    choice = input("Download SmolLM2-135M automatically? (y/n): ").strip().lower()
    if choice == "y":
        url = "https://huggingface.co/TheBloke/SmolLM2-135M-Instruct-GGUF/resolve/main/smollm2-135m-instruct-q4_k_m.gguf"
        dest = chatbot_dir / "smollm2-135m-instruct-q4_k_m.gguf"
        return download_file(url, dest, "SmolLM2-135M chatbot model (~800MB)")

    return True


def print_summary():
    print("\n" + "=" * 50)
    print("  SETUP SUMMARY")
    print("=" * 50)

    face_models = list((MODELS_DIR / "face").glob("*"))
    chatbot_models = list((MODELS_DIR / "chatbot").glob("*.gguf"))

    print(f"\n  Face models:     {len(face_models)} files")
    for f in face_models:
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"    - {f.name} ({size_mb:.1f} MB)")

    print(f"\n  Chatbot models:  {len(chatbot_models)} files")
    for f in chatbot_models:
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"    - {f.name} ({size_mb:.1f} MB)")

    if face_models:
        print("\n  [OK] Face detection ready")
    else:
        print("\n  [WARN] Face detection models missing")

    if chatbot_models:
        print("  [OK] Chatbot ready")
    else:
        print("  [INFO] Chatbot model not loaded (optional)")

    print("\n  Run the app: streamlit run app.py")
    print("=" * 50)


def main():
    print("=" * 50)
    print("  OFFLINE PHOTO ORGANIZER - MODEL SETUP")
    print("=" * 50)

    setup_face_models()
    setup_chatbot_model()
    print_summary()


if __name__ == "__main__":
    main()
