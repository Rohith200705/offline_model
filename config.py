import os
from pathlib import Path

BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / "models"
DATA_DIR = BASE_DIR / "data"
SORTED_DIR = BASE_DIR / "sorted_photos"

FACE_MODEL_DIR = MODELS_DIR / "face"
CLASSIFICATION_MODEL_DIR = MODELS_DIR / "classification"
CHATBOT_MODEL_DIR = MODELS_DIR / "chatbot"

FACES_DB_DIR = DATA_DIR / "faces"
METADATA_DIR = DATA_DIR / "metadata"

SUPPORTED_FORMATS = [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".heic", ".tiff"]

SCENE_LABELS = [
    "indoor", "outdoor", "beach", "mountain", "city",
    "forest", "desert", "snow", "rain", "night",
    "sunset", "garden", "office", "home", "restaurant",
    "street", "park", "lake", "river", "field"
]

OBJECT_LABELS = [
    "person", "bicycle", "car", "motorcycle", "bus", "truck",
    "traffic light", "bench", "bird", "cat", "dog", "horse",
    "backpack", "umbrella", "handbag", "suitcase", "bottle",
    "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "chair", "couch", "potted plant", "bed", "dining table",
    "toilet", "tv", "laptop", "cell phone", "book", "clock",
    "vase", "scissors", "teddy bear"
]

CATEGORIES = {
    "persons": SORTED_DIR / "persons",
    "locations": SORTED_DIR / "locations",
    "events": SORTED_DIR / "events",
    "objects": SORTED_DIR / "objects",
    "documents": SORTED_DIR / "documents",
    "others": SORTED_DIR / "others",
}

DB_PATH = DATA_DIR / "photos.db"
MEMORY_PATH = DATA_DIR / "chat_memory.json"
KNOWN_FACES_PATH = DATA_DIR / "known_faces.json"

for d in [MODELS_DIR, DATA_DIR, SORTED_DIR, FACES_DB_DIR, METADATA_DIR]:
    d.mkdir(parents=True, exist_ok=True)
for cat_dir in CATEGORIES.values():
    cat_dir.mkdir(parents=True, exist_ok=True)
