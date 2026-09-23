import shutil
from pathlib import Path
from datetime import datetime

from src.image_processor import ImageProcessor
from src.database import Database
from config import SUPPORTED_FORMATS, CATEGORIES


class PhotoOrganizer:
    def __init__(self):
        self.processor = ImageProcessor()
        self.db = Database()

    def organize_photos(self, source_dir, organize_by="auto", move_files=False):
        source = Path(source_dir)
        if not source.exists():
            return {"error": f"Directory not found: {source_dir}"}

        photos = self._get_all_photos(source)
        if not photos:
            return {"error": "No supported photos found", "total": 0}

        results = {
            "total": len(photos),
            "organized": 0,
            "skipped": 0,
            "errors": 0,
            "details": [],
        }

        for photo in photos:
            try:
                if self.db.photo_exists(str(photo)):
                    results["skipped"] += 1
                    continue

                analysis = self.processor.analyze_image(photo)
                category = self._determine_category(analysis, organize_by)
                dest = self._get_destination(photo, category, analysis)

                if dest.exists():
                    dest = self._add_suffix(dest)

                dest.parent.mkdir(parents=True, exist_ok=True)

                if move_files:
                    shutil.move(str(photo), str(dest))
                else:
                    shutil.copy2(str(photo), str(dest))

                self.db.store_photo(str(photo), analysis, category)
                results["organized"] += 1
                results["details"].append({
                    "file": photo.name,
                    "category": category,
                    "destination": str(dest),
                })

            except Exception as e:
                results["errors"] += 1
                results["details"].append({
                    "file": photo.name,
                    "error": str(e),
                })

        return results

    def _get_all_photos(self, directory):
        photos = []
        for ext in SUPPORTED_FORMATS:
            photos.extend(directory.rglob(f"*{ext}"))
            photos.extend(directory.rglob(f"*{ext.upper()}"))
        return sorted(set(photos))

    def _determine_category(self, analysis, organize_by):
        if organize_by != "auto":
            return organize_by

        if analysis["faces"]:
            return "persons"
        if analysis["scene"]:
            top_scene = analysis["scene"][0][0] if isinstance(analysis["scene"][0], tuple) else analysis["scene"][0].get("scene", "")
            outdoor_scenes = ["outdoor", "beach", "mountain", "forest", "garden", "park"]
            if top_scene in outdoor_scenes:
                return "locations"

        if analysis["metadata"].get("date"):
            return "events"

        if analysis["objects"]:
            return "objects"

        return "others"

    def _get_destination(self, photo, category, analysis):
        if category == "persons":
            names = [f.get("name", "unknown") for f in analysis.get("faces", [])]
            person_name = names[0] if names else "unknown"
            return CATEGORIES["persons"] / person_name / photo.name

        if category == "locations":
            scenes = analysis.get("scene", [])
            scene_name = scenes[0][0] if scenes and isinstance(scenes[0], tuple) else (scenes[0].get("scene", "unknown") if scenes else "unknown")
            return CATEGORIES["locations"] / scene_name / photo.name

        if category == "events":
            date_str = analysis.get("metadata", {}).get("date", "")
            if date_str:
                try:
                    dt = datetime.strptime(date_str, "%Y:%m:%d %H:%M:%S")
                    folder = dt.strftime("%Y-%m")
                except ValueError:
                    folder = "undated"
            else:
                folder = "undated"
            return CATEGORIES["events"] / folder / photo.name

        if category == "objects":
            obj_labels = [o.get("label", "other") for o in analysis.get("objects", [])]
            obj_name = obj_labels[0] if obj_labels else "other"
            return CATEGORIES["objects"] / obj_name / photo.name

        return CATEGORIES[category] / photo.name

    def _add_suffix(self, path):
        stem = path.stem
        suffix = path.suffix
        parent = path.parent
        counter = 1
        while path.exists():
            path = parent / f"{stem}_{counter}{suffix}"
            counter += 1
        return path

    def get_stats(self):
        return self.db.get_stats()
