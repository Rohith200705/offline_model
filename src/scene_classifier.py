import numpy as np
import cv2


SCENE_CATEGORIES = [
    "indoor", "outdoor", "beach", "mountain", "city", "forest",
    "sunset", "night", "snow", "portrait", "food", "building",
    "water", "desert", "garden", "parking", "street", "office",
]


class SceneClassifier:
    def __init__(self):
        self.model = None
        self.labels = SCENE_CATEGORIES

    def classify(self, image_path):
        img = cv2.imread(str(image_path))
        if img is None:
            return [("unknown", 0.0)]

        if self.model is not None:
            return self._classify_with_model(img)

        return self._classify_heuristic(img)

    def _classify_with_model(self, img):
        try:
            blob = cv2.dnn.blobFromImage(
                cv2.resize(img, (224, 224)),
                1.0 / 255.0,
                (224, 224),
                (0, 0, 0),
                swapRB=True,
                crop=False,
            )
            self.model.setInput(blob)
            preds = self.model.forward()
            top5_idx = preds[0].argsort()[-5:][::-1]
            results = []
            for idx in top5_idx:
                if idx < len(self.labels):
                    label = self.labels[idx]
                    conf = float(preds[0][idx])
                    results.append((label, conf))
            return results if results else [("unknown", 0.0)]
        except Exception:
            return self._classify_heuristic(img)

    def _classify_heuristic(self, img):
        h, w = img.shape[:2]
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        results = []

        avg_hue = np.mean(hsv[:, :, 0])
        avg_sat = np.mean(hsv[:, :, 1])
        avg_val = np.mean(hsv[:, :, 2])

        blue_mask = cv2.inRange(hsv, np.array([90, 50, 50]), np.array([130, 255, 255]))
        blue_ratio = np.sum(blue_mask > 0) / (h * w)

        green_mask = cv2.inRange(hsv, np.array([30, 50, 50]), np.array([85, 255, 255]))
        green_ratio = np.sum(green_mask > 0) / (h * w)

        brown_mask = cv2.inRange(hsv, np.array([10, 30, 30]), np.array([25, 200, 200]))
        brown_ratio = np.sum(brown_mask > 0) / (h * w)

        red_mask = cv2.inRange(hsv, np.array([0, 50, 50]), np.array([10, 255, 255]))
        red_mask2 = cv2.inRange(hsv, np.array([170, 50, 50]), np.array([180, 255, 255]))
        red_ratio = np.sum(red_mask > 0) + np.sum(red_mask2 > 0)
        red_ratio = red_ratio / (h * w)

        orange_mask = cv2.inRange(hsv, np.array([10, 50, 100]), np.array([25, 255, 255]))
        orange_ratio = np.sum(orange_mask > 0) / (h * w)

        yellow_mask = cv2.inRange(hsv, np.array([20, 50, 100]), np.array([35, 255, 255]))
        yellow_ratio = np.sum(yellow_mask > 0) / (h * w)

        gray_mask = cv2.inRange(hsv, np.array([0, 0, 40]), np.array([180, 30, 200]))
        gray_ratio = np.sum(gray_mask > 0) / (h * w)

        white_mask = cv2.inRange(hsv, np.array([0, 0, 200]), np.array([180, 30, 255]))
        white_ratio = np.sum(white_mask > 0) / (h * w)

        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / (h * w)

        brightness = np.mean(gray)

        bottom_half = img[h // 2:, :]
        top_half = img[:h // 2, :]
        bottom_bright = np.mean(cv2.cvtColor(bottom_half, cv2.COLOR_BGR2GRAY))
        top_bright = np.mean(cv2.cvtColor(top_half, cv2.COLOR_BGR2GRAY))

        lower_skin = np.array([0, 30, 80], dtype=np.uint8)
        upper_skin = np.array([25, 150, 255], dtype=np.uint8)
        skin_mask = cv2.inRange(hsv, lower_skin, upper_skin)
        skin_ratio = np.sum(skin_mask > 0) / (h * w)

        saturation = np.mean(hsv[:, :, 1])

        scores = {cat: 0.0 for cat in SCENE_CATEGORIES}

        if avg_val > 170:
            scores["outdoor"] += 1.0
            scores["beach"] += 0.5
            scores["garden"] += 0.3
        elif avg_val < 60:
            scores["night"] += 1.5
        elif avg_val < 100:
            scores["indoor"] += 0.5

        if blue_ratio > 0.15:
            scores["beach"] += 1.5
            scores["water"] += 1.5
            scores["mountain"] += 0.3
        if blue_ratio > 0.25:
            scores["beach"] += 0.5

        if green_ratio > 0.12:
            scores["forest"] += 1.5
            scores["garden"] += 1.0
            scores["parking"] += 0.3
        if green_ratio > 0.2:
            scores["forest"] += 0.5
            scores["garden"] += 0.5

        if brown_ratio > 0.1:
            scores["mountain"] += 0.8
            scores["desert"] += 1.0
            scores["beach"] += 0.5

        if orange_ratio > 0.1 or (avg_hue < 25 and avg_sat > 80 and avg_val > 100):
            scores["sunset"] += 1.5
            scores["outdoor"] += 0.5

        if yellow_ratio > 0.1:
            scores["desert"] += 0.8
            scores["sunset"] += 0.3
            scores["outdoor"] += 0.3

        if red_ratio > 0.1:
            scores["food"] += 0.8
            scores["city"] += 0.5
            scores["building"] += 0.3

        if gray_ratio > 0.3 and saturation < 30:
            scores["city"] += 1.0
            scores["street"] += 1.0
            scores["office"] += 0.5
            scores["parking"] += 0.5

        if white_ratio > 0.2:
            scores["snow"] += 1.5
            scores["office"] += 0.5
            scores["indoor"] += 0.3

        if laplacian_var < 30:
            scores["indoor"] += 0.5
            scores["office"] += 0.3
        elif laplacian_var > 200:
            scores["city"] += 0.5
            scores["street"] += 0.5
            scores["building"] += 0.3

        if edge_density > 0.12:
            scores["city"] += 1.0
            scores["building"] += 1.0
            scores["street"] += 0.8
        elif edge_density < 0.04:
            scores["indoor"] += 0.5
            scores["outdoor"] += 0.3

        if brightness > 160:
            scores["beach"] += 0.3
            scores["snow"] += 0.5
            scores["outdoor"] += 0.3
        elif brightness < 60:
            scores["night"] += 1.0
            scores["indoor"] += 0.3

        if bottom_bright > top_bright + 10:
            scores["outdoor"] += 0.3
            scores["beach"] += 0.3

        if skin_ratio > 0.08:
            scores["portrait"] += 1.5
            scores["indoor"] += 0.3
        if skin_ratio > 0.15:
            scores["portrait"] += 1.0

        if avg_hue < 10 or avg_hue > 170:
            scores["food"] += 0.5
            scores["sunset"] += 0.3

        if avg_sat < 20:
            scores["office"] += 0.5
            scores["indoor"] += 0.3
            scores["street"] += 0.3
        elif avg_sat > 100:
            scores["beach"] += 0.3
            scores["garden"] += 0.3

        sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        top = sorted_scores[0]
        if top[1] < 0.5:
            return [("unknown", 0.0)]

        total_weight = sum(max(s, 0) for _, s in sorted_scores[:3])
        if total_weight == 0:
            return [("unknown", 0.0)]

        results = []
        for label, score in sorted_scores[:5]:
            if score > 0:
                conf = min(score / total_weight, 1.0)
                results.append((label, conf))

        return results if results else [("unknown", 0.0)]
