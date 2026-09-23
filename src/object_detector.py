import numpy as np
import cv2
from config import OBJECT_LABELS


class ObjectDetector:
    def __init__(self):
        self.model = None
        self.labels = OBJECT_LABELS
        self._init_model()

    def _init_model(self):
        try:
            import onnxruntime as ort
            model_path = "models/object/yolov8n.onnx"
            import os
            if os.path.exists(model_path):
                self.model = ort.InferenceSession(model_path)
        except Exception:
            self.model = None

    def detect(self, image_path, confidence_threshold=0.3):
        img = cv2.imread(str(image_path))
        if img is None:
            return []

        if self.model is not None:
            return self._detect_with_yolo(img, confidence_threshold)

        return self._detect_heuristic(img)

    def _detect_with_yolo(self, img, confidence_threshold):
        try:
            h, w = img.shape[:2]
            blob = cv2.dnn.blobFromImage(
                cv2.resize(img, (640, 640)),
                1.0 / 255.0,
                (640, 640),
                swapRB=True,
                crop=False,
            )
            self.model.get_inputs()[0].name
            output = self.model.run(None, {self.model.get_inputs()[0].name: blob})[0]
            output = output[0]
            output = output.T

            boxes = []
            confidences = []
            class_ids = []

            for detection in output:
                scores = detection[5:]
                if len(scores) == 0:
                    continue
                class_id = int(np.argmax(scores))
                confidence = float(scores[class_id])

                if confidence > confidence_threshold:
                    cx, cy, bw, bh = detection[:4]
                    x = int((cx - bw / 2) * w / 640)
                    y = int((cy - bh / 2) * h / 640)
                    bwidth = int(bw * w / 640)
                    bheight = int(bh * h / 640)

                    boxes.append([x, y, bwidth, bheight])
                    confidences.append(confidence)
                    class_ids.append(class_id)

            indices = cv2.dnn.NMSBoxes(boxes, confidences, confidence_threshold, 0.4)
            results = []
            if len(indices) > 0:
                for i in indices.flatten():
                    label = self.labels[class_ids[i]] if class_ids[i] < len(self.labels) else "object"
                    results.append({
                        "label": label,
                        "confidence": confidences[i],
                        "bbox": boxes[i],
                    })
            return results
        except Exception:
            return self._detect_heuristic(img)

    def _detect_heuristic(self, img):
        h, w = img.shape[:2]
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        results = []

        lower_skin = np.array([0, 20, 70], dtype=np.uint8)
        upper_skin = np.array([25, 150, 255], dtype=np.uint8)
        skin_mask = cv2.inRange(hsv, lower_skin, upper_skin)
        kernel = np.ones((5, 5), np.uint8)
        skin_mask = cv2.morphologyEx(skin_mask, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(skin_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            area = cv2.contourArea(contour)
            if 2000 < area < (h * w) * 0.15:
                x, y, cw, ch = cv2.boundingRect(contour)
                aspect = ch / cw if cw > 0 else 0
                if 0.5 < aspect < 2.0:
                    results.append({"label": "person", "confidence": 0.6, "bbox": [int(x), int(y), int(cw), int(ch)]})

        blue_mask = cv2.inRange(hsv, np.array([100, 50, 50]), np.array([130, 255, 255]))
        contours, _ = cv2.findContours(blue_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            area = cv2.contourArea(contour)
            if 3000 < area < (h * w) * 0.2:
                x, y, cw, ch = cv2.boundingRect(contour)
                aspect = cw / ch if ch > 0 else 0
                if 1.5 < aspect < 4.0:
                    results.append({"label": "car", "confidence": 0.5, "bbox": [int(x), int(y), int(cw), int(ch)]})

        lower_green = np.array([35, 50, 50], dtype=np.uint8)
        upper_green = np.array([85, 255, 255], dtype=np.uint8)
        green_mask = cv2.inRange(hsv, lower_green, upper_green)
        contours, _ = cv2.findContours(green_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            area = cv2.contourArea(contour)
            if 1000 < area < (h * w) * 0.1:
                x, y, cw, ch = cv2.boundingRect(contour)
                if ch > cw:
                    results.append({"label": "plant", "confidence": 0.45, "bbox": [int(x), int(y), int(cw), int(ch)]})

        edges = cv2.Canny(gray, 50, 150)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            area = cv2.contourArea(contour)
            if 5000 < area < (h * w) * 0.3:
                peri = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
                x, y, cw, ch = cv2.boundingRect(approx)
                aspect = cw / ch if ch > 0 else 0
                if 0.3 < aspect < 3.0:
                    results.append({"label": "structure", "confidence": 0.4, "bbox": [int(x), int(y), int(cw), int(ch)]})

        results.sort(key=lambda r: r["confidence"], reverse=True)
        return results[:10]
