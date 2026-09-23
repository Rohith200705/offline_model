import os
import json
import numpy as np
import cv2
from pathlib import Path
from config import FACE_MODEL_DIR, KNOWN_FACES_PATH, FACES_DB_DIR


class FaceIdentifier:
    SFACE_MEAN = np.array([127.0, 127.0, 127.0], dtype=np.float32)
    SFACE_STD = np.array([128.0, 128.0, 128.0], dtype=np.float32)

    def __init__(self):
        self.known_faces = self._load_known_faces()
        self.detector_session = None
        self.recognizer_session = None
        self._init_models()

    def _init_models(self):
        import onnxruntime as ort

        try:
            detector_path = FACE_MODEL_DIR / "ultraface.onnx"
            if detector_path.exists():
                self.detector_session = ort.InferenceSession(str(detector_path))
        except Exception:
            self.detector_session = None

        try:
            recognizer_path = FACE_MODEL_DIR / "face_recognition_sface_2021dec.onnx"
            if recognizer_path.exists():
                self.recognizer_session = ort.InferenceSession(
                    str(recognizer_path),
                    providers=["CPUExecutionProvider"],
                )
        except Exception:
            self.recognizer_session = None

    def _load_known_faces(self):
        if KNOWN_FACES_PATH.exists():
            try:
                with open(KNOWN_FACES_PATH, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}

    def _save_known_faces(self):
        KNOWN_FACES_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(KNOWN_FACES_PATH, "w") as f:
            json.dump(self.known_faces, f, indent=2)

    def detect_faces(self, image_path):
        img = cv2.imread(str(image_path))
        if img is None:
            return []

        h, w = img.shape[:2]

        if self.detector_session is not None:
            return self._detect_with_ultraface(img, h, w)

        return self._detect_with_skin_color(img, h, w)

    def _detect_with_ultraface(self, img, h, w):
        try:
            img_resized = cv2.resize(img, (320, 240))
            img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
            img_float = img_rgb.astype(np.float32)
            img_float = (img_float - 127.0) / 128.0
            img_float = img_float.transpose(2, 0, 1)
            img_float = np.expand_dims(img_float, axis=0)

            input_name = self.detector_session.get_inputs()[0].name
            outputs = self.detector_session.run(None, {input_name: img_float})

            scores_out = outputs[0][0]
            boxes_out = outputs[1][0]

            score_indices = np.where(scores_out > 0.5)[0]
            if len(score_indices) == 0:
                return self._detect_with_skin_color(img, h, w)

            keep_boxes = []
            keep_scores = []
            for idx in score_indices:
                box = boxes_out[idx]
                x1 = int(box[0] * w)
                y1 = int(box[1] * h)
                x2 = int(box[2] * w)
                y2 = int(box[3] * h)
                keep_boxes.append([x1, y1, x2, y2])
                keep_scores.append(float(scores_out[idx]))

            keep_boxes = np.array(keep_boxes, dtype=np.float32)
            keep_scores = np.array(keep_scores, dtype=np.float32)

            indices = cv2.dnn.NMSBoxes(
                bboxes=[(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1])) for b in keep_boxes],
                scores=keep_scores.tolist(),
                score_threshold=0.5,
                nms_threshold=0.4,
            )

            faces = []
            if isinstance(indices, np.ndarray):
                indices = indices.flatten()
            elif isinstance(indices, list):
                indices = np.array(indices)

            for i in indices:
                box = keep_boxes[i]
                x1, y1, x2, y2 = int(box[0]), int(box[1]), int(box[2]), int(box[3])

                pad_x = int((x2 - x1) * 0.1)
                pad_y = int((y2 - y1) * 0.15)
                x1 = max(0, x1 - pad_x)
                y1 = max(0, y1 - pad_y)
                x2 = min(w, x2 + pad_x)
                y2 = min(h, y2 + pad_y)

                if x2 > x1 and y2 > y1:
                    face_img = img[y1:y2, x1:x2]
                    name = self._identify_face(face_img)
                    faces.append({
                        "bbox": [x1, y1, x2, y2],
                        "confidence": float(keep_scores[i]),
                        "name": name,
                    })
            return faces
        except Exception:
            return self._detect_with_skin_color(img, h, w)

    def _detect_with_skin_color(self, img, h, w):
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lower_skin = np.array([0, 20, 70], dtype=np.uint8)
        upper_skin = np.array([25, 150, 255], dtype=np.uint8)
        mask = cv2.inRange(hsv, lower_skin, upper_skin)

        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        faces = []
        min_area = (h * w) * 0.005
        max_area = (h * w) * 0.15

        for contour in contours:
            area = cv2.contourArea(contour)
            if min_area < area < max_area:
                x, y, cw, ch = cv2.boundingRect(contour)
                aspect = ch / cw if cw > 0 else 0
                if 0.5 < aspect < 2.0:
                    face_img = img[y:y + ch, x:x + cw]
                    name = self._identify_face(face_img)
                    faces.append({
                        "bbox": [int(x), int(y), int(x + cw), int(y + ch)],
                        "confidence": 0.6,
                        "name": name,
                    })

        faces.sort(key=lambda f: f["confidence"], reverse=True)
        return faces[:5]

    def _align_face(self, face_img, target_size=112):
        h, w = face_img.shape[:2]
        if h == 0 or w == 0:
            return cv2.resize(face_img, (target_size, target_size))
        size = max(h, w)
        pad_x = (size - w) // 2
        pad_y = (size - h) // 2
        padded = np.full((size, size, 3), 128, dtype=np.uint8)
        padded[pad_y:pad_y + h, pad_x:pad_x + w] = face_img
        return cv2.resize(padded, (target_size, target_size))

    def _prepare_face_for_recognition(self, face_img):
        aligned = self._align_face(face_img, 112)
        face_rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
        face_float = face_rgb.astype(np.float32)
        face_float = (face_float - self.SFACE_MEAN) / self.SFACE_STD
        face_float = face_float.transpose(2, 0, 1)
        face_float = np.expand_dims(face_float, axis=0)
        return face_float

    def _identify_face(self, face_img):
        if self.recognizer_session is not None and self.known_faces:
            try:
                face_float = self._prepare_face_for_recognition(face_img)
                input_name = self.recognizer_session.get_inputs()[0].name
                embedding = self.recognizer_session.run(None, {input_name: face_float})[0][0]

                best_name = "unknown"
                best_score = -1

                for person_name, info in self.known_faces.items():
                    for emb_path in info.get("embeddings", []):
                        if Path(emb_path).exists():
                            known_emb = np.load(emb_path)
                            norm_emb = np.linalg.norm(embedding)
                            norm_known = np.linalg.norm(known_emb)
                            if norm_emb > 0 and norm_known > 0:
                                similarity = float(np.dot(embedding, known_emb) / (norm_emb * norm_known))
                            else:
                                similarity = 0.0
                            if similarity > best_score:
                                best_score = similarity
                                best_name = person_name

                if best_score > 0.4:
                    return best_name
            except Exception:
                pass
        return "unknown"

    def add_known_face(self, name, image_paths):
        if not image_paths:
            return False

        embeddings = []
        for img_path in image_paths:
            img = cv2.imread(str(img_path))
            if img is None:
                continue

            if self.recognizer_session is not None:
                try:
                    faces = self.detect_faces(img_path)
                    if faces:
                        best = max(faces, key=lambda f: f["confidence"])
                        bx1, by1, bx2, by2 = best["bbox"]
                        face_crop = img[by1:by2, bx1:bx2]
                    else:
                        face_crop = img

                    face_float = self._prepare_face_for_recognition(face_crop)
                    input_name = self.recognizer_session.get_inputs()[0].name
                    emb = self.recognizer_session.run(None, {input_name: face_float})[0][0]

                    emb_path = str(FACES_DB_DIR / f"{name}_{len(embeddings)}.npy")
                    FACES_DB_DIR.mkdir(parents=True, exist_ok=True)
                    np.save(emb_path, emb)
                    embeddings.append(emb_path)
                except Exception:
                    pass

        if embeddings:
            self.known_faces[name] = {
                "embeddings": embeddings,
                "sample_images": [str(p) for p in image_paths],
            }
            self._save_known_faces()
            return True
        return False

    def remove_known_face(self, name):
        if name in self.known_faces:
            info = self.known_faces.pop(name)
            for emb_path in info.get("embeddings", []):
                p = Path(emb_path)
                if p.exists():
                    p.unlink()
            self._save_known_faces()
            return True
        return False
