# Offline Photo Organizer & Chatbot

A 100% offline photo organization and chatbot system that runs on your local machine. No internet required, no data leaves your device.

## Features

- **Auto-Organize Photos**: Sort by persons, locations, objects, or events
- **Face Recognition**: Detect and identify people in photos
- **Scene Classification**: Detect locations (indoor, beach, mountain, etc.)
- **Object Detection**: Identify objects in photos
- **Chat Assistant**: Ask questions about your photos
- **Memory**: Remembers conversations and learns over time
- **Privacy**: Everything runs offline - your data stays on your device

## Requirements

- Python 3.8+
- ~1-2GB disk space (for models)
- Windows/macOS/Linux

## Quick Start

### 1. Install Dependencies

```bash
# Option A: Use the install script (Windows)
install.bat

# Option B: Manual install
pip install -r requirements.txt
python setup.py
```

### 2. Run the App

```bash
# Option A: Use the run script (Windows)
run_app.bat

# Option B: Manual run
streamlit run app.py
```

### 3. Open Browser

The app will open at: http://localhost:8501

## Usage Guide

### Organize Photos

1. Go to **"Organize Photos"** tab
2. Enter the path to your photo directory
3. Choose how to organize (Auto, Persons, Locations, etc.)
4. Click **"Start Organizing"**

### Chat About Photos

1. Go to **"Chat"** tab
2. Type questions about your photos
3. Upload specific photos to ask about them

### Manage Known Faces

1. Go to **"Manage Faces"** tab
2. Upload photos of people you want to identify
3. Enter their name
4. The system will learn to recognize them

## File Structure

```
offline model/
├── app.py                  # Main web interface
├── config.py               # Configuration
├── setup.py                # Model downloader
├── requirements.txt        # Dependencies
├── install.bat             # Windows installer
├── run_app.bat             # Windows launcher
├── src/
│   ├── image_processor.py  # Image analysis
│   ├── face_identifier.py  # Face detection/recognition
│   ├── scene_classifier.py # Location detection
│   ├── object_detector.py  # Object detection
│   ├── photo_organizer.py  # File sorting
│   ├── chatbot.py          # AI chat assistant
│   └── database.py         # Data storage
├── models/                 # Downloaded AI models
├── data/                   # App data & embeddings
└── sorted_photos/          # Organized output
    ├── persons/
    ├── locations/
    ├── events/
    ├── objects/
    └── others/
```

## Supported File Types

- JPEG/JPG
- PNG
- GIF
- BMP
- WebP
- HEIC
- TIFF

## Model Sizes

| Component | Size | Purpose |
|-----------|------|---------|
| Face Detection | ~11 MB | Detect faces in photos |
| Face Recognition | ~5 MB | Identify known people |
| Chatbot (optional) | ~800 MB | AI chat assistant |
| **Total** | **~16-820 MB** | |

## Troubleshooting

### "No faces detected"
- Ensure the photo has clear, visible faces
- Try uploading a higher resolution image

### "Chatbot not responding"
- Download a GGUF model (see setup.py output)
- Place it in the `models/chatbot/` folder

### "Streamlit not found"
- Run: `pip install streamlit`
- Or use: `pip install -r requirements.txt`

## Privacy

- All processing happens locally on your machine
- No internet connection required after setup
- No data is sent to any external servers
- Your photos and data stay private

## License

MIT License - Free to use and modify.
