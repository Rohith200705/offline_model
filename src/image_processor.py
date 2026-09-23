from pathlib import Path
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS

from src.face_identifier import FaceIdentifier
from src.scene_classifier import SceneClassifier
from src.object_detector import ObjectDetector
from config import SUPPORTED_FORMATS


class ImageProcessor:
    def __init__(self):
        self.face_identifier = FaceIdentifier()
        self.scene_classifier = SceneClassifier()
        self.object_detector = ObjectDetector()

    def analyze_image(self, image_path):
        image_path = Path(image_path)
        results = {
            "path": str(image_path),
            "filename": image_path.name,
            "faces": self.face_identifier.detect_faces(image_path),
            "scene": self.scene_classifier.classify(image_path),
            "objects": self.object_detector.detect(image_path),
            "metadata": self._extract_metadata(image_path),
        }
        return results

    def _extract_metadata(self, image_path):
        metadata = {
            "date": None,
            "gps_lat": None,
            "gps_lon": None,
            "camera": None,
            "width": None,
            "height": None,
        }

        try:
            img = Image.open(image_path)
            metadata["width"] = img.width
            metadata["height"] = img.height

            if hasattr(img, "_getexif") and img._getexif():
                exif = img._getexif()
                for tag_id, value in exif.items():
                    tag = TAGS.get(tag_id, tag_id)
                    if tag == "DateTimeOriginal":
                        metadata["date"] = str(value)
                    elif tag == "Model":
                        metadata["camera"] = str(value)
                    elif tag == "GPSInfo":
                        gps_data = self._parse_gps(value)
                        metadata["gps_lat"] = gps_data.get("lat")
                        metadata["gps_lon"] = gps_data.get("lon")
        except Exception:
            pass

        return metadata

    def _parse_gps(self, gps_info):
        result = {"lat": None, "lon": None}
        try:
            for key, val in gps_info.items():
                decode = GPSTAGS.get(key, key)
                if decode == "GPSLatitude":
                    result["lat"] = self._convert_to_degrees(val)
                elif decode == "GPSLatitudeRef":
                    if val == "S":
                        result["lat"] = -abs(result["lat"]) if result["lat"] else None
                elif decode == "GPSLongitude":
                    result["lon"] = self._convert_to_degrees(val)
                elif decode == "GPSLongitudeRef":
                    if val == "W":
                        result["lon"] = -abs(result["lon"]) if result["lon"] else None
        except Exception:
            pass
        return result

    def _convert_to_degrees(self, value):
        try:
            d = float(value[0])
            m = float(value[1])
            s = float(value[2])
            return d + (m / 60.0) + (s / 3600.0)
        except Exception:
            return None

    def is_supported(self, file_path):
        return Path(file_path).suffix.lower() in SUPPORTED_FORMATS
