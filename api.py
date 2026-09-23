import os
import sys
import json
import shutil
import base64
import tempfile
import hashlib
import threading
import time
from pathlib import Path
from datetime import datetime
from typing import Optional

sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from config import BASE_DIR, SORTED_DIR, CATEGORIES, DATA_DIR
from src.photo_organizer import PhotoOrganizer
from src.chatbot import ChatBot
from src.image_processor import ImageProcessor
from src.database import Database

app = FastAPI(title="Offline Photo Organizer API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

organizer = PhotoOrganizer()
processor = ImageProcessor()
db = Database()
chatbot = ChatBot(db)

organize_progress = {"running": False, "current": 0, "total": 0, "message": "", "result": None}


class ChatRequest(BaseModel):
    message: str


class OrganizeRequest(BaseModel):
    source_dir: str
    organize_by: str = "auto"
    move_files: bool = False


app.mount("/css", StaticFiles(directory=str(Path(__file__).parent / "frontend" / "css")), name="css")
app.mount("/js", StaticFiles(directory=str(Path(__file__).parent / "frontend" / "js")), name="js")


@app.get("/")
async def root():
    return FileResponse(str(Path(__file__).parent / "frontend" / "index.html"))


@app.get("/api/stats")
async def get_stats():
    stats = db.get_stats()
    stats["sorted_dir"] = str(SORTED_DIR)
    cat_counts = {}
    for cat_name, cat_dir in CATEGORIES.items():
        if cat_dir.exists():
            cat_counts[cat_name] = len(list(cat_dir.rglob("*.*")))
        else:
            cat_counts[cat_name] = 0
    stats["categories"] = cat_counts
    stats["organize_progress"] = organize_progress
    return stats


@app.get("/api/organize/progress")
async def get_organize_progress():
    return organize_progress


@app.post("/api/organize")
async def organize_photos(request: OrganizeRequest):
    if organize_progress["running"]:
        raise HTTPException(status_code=409, detail="Organization already in progress")

    if not Path(request.source_dir).exists():
        raise HTTPException(status_code=400, detail="Directory not found")

    def run_organize():
        global organize_progress
        organize_progress = {"running": True, "current": 0, "total": 0, "message": "Starting...", "result": None}
        try:
            result = organizer.organize_photos(
                request.source_dir, request.organize_by, request.move_files
            )
            organize_progress["result"] = result
            organize_progress["message"] = "Done!"
        except Exception as e:
            organize_progress["result"] = {"error": str(e)}
            organize_progress["message"] = f"Error: {e}"
        finally:
            organize_progress["running"] = False

    thread = threading.Thread(target=run_organize, daemon=True)
    thread.start()
    return {"status": "started", "message": "Organization started in background"}


@app.post("/api/chat")
async def chat(request: ChatRequest):
    response = chatbot.chat(request.message)
    return {"response": response}


@app.get("/api/faces")
async def get_known_faces():
    return {"faces": processor.face_identifier.known_faces}


@app.post("/api/faces/add")
async def add_face(name: str = Form(...), file: UploadFile = File(...)):
    temp_path = BASE_DIR / "temp_face.jpg"

    content = await file.read()
    with open(temp_path, "wb") as f:
        f.write(content)

    success = processor.face_identifier.add_known_face(name, [temp_path])

    if temp_path.exists():
        temp_path.unlink()

    if success:
        return {"status": "ok", "message": f"Added {name}"}
    else:
        raise HTTPException(status_code=400, detail="No face detected in image")


@app.delete("/api/faces/{name}")
async def remove_face(name: str):
    success = processor.face_identifier.remove_known_face(name)
    if success:
        return {"status": "ok"}
    else:
        raise HTTPException(status_code=404, detail="Person not found")


@app.post("/api/faces/test")
async def test_face(file: UploadFile = File(...)):
    temp_path = BASE_DIR / "temp_test_face.jpg"

    content = await file.read()
    with open(temp_path, "wb") as f:
        f.write(content)

    faces = processor.face_identifier.detect_faces(temp_path)

    if temp_path.exists():
        temp_path.unlink()

    return {"faces": faces}


@app.get("/api/sorted")
async def get_sorted_photos():
    result = {}
    for cat_name, cat_dir in CATEGORIES.items():
        if cat_dir.exists():
            files = []
            for f in sorted(cat_dir.rglob("*.*")):
                if f.is_file():
                    files.append({
                        "name": f.name,
                        "path": str(f),
                        "relative": str(f.relative_to(cat_dir)),
                        "size": f.stat().st_size,
                    })
            result[cat_name] = files
        else:
            result[cat_name] = []
    return result


@app.get("/api/photo/{path:path}")
async def serve_photo(path: str):
    full_path = Path(path)
    if full_path.exists() and full_path.is_file():
        return FileResponse(str(full_path))
    raise HTTPException(status_code=404, detail="Photo not found")


@app.get("/api/search")
async def search_photos(q: str = ""):
    if not q:
        return {"results": []}
    results = db.search_photos(q)
    return {"results": results}


@app.post("/api/upload")
async def upload_photos(files: list[UploadFile] = File(...)):
    upload_dir = BASE_DIR / "uploads"
    upload_dir.mkdir(exist_ok=True)

    saved = []
    for file in files:
        dest = upload_dir / file.filename
        content = await file.read()
        with open(dest, "wb") as f:
            f.write(content)
        saved.append(str(dest))

    return {"uploaded": len(saved), "paths": saved}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
