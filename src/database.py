import json
import sqlite3
from pathlib import Path
from datetime import datetime
from config import DB_PATH, METADATA_DIR


class Database:
    def __init__(self):
        self.conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        self._create_tables()

    def _create_tables(self):
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS photos (
                id TEXT PRIMARY KEY,
                path TEXT UNIQUE,
                filename TEXT,
                category TEXT,
                persons TEXT,
                scenes TEXT,
                objects TEXT,
                date_taken TEXT,
                gps_lat REAL,
                gps_lon REAL,
                created_at TEXT
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS known_faces (
                id TEXT PRIMARY KEY,
                name TEXT,
                embedding_path TEXT,
                sample_images TEXT,
                created_at TEXT
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS chat_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                role TEXT,
                content TEXT,
                photo_context TEXT,
                timestamp TEXT
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_photos_category ON photos(category)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_photos_path ON photos(path)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_photos_date ON photos(date_taken)")
        self.conn.commit()

    def store_photo(self, photo_path, analysis, category):
        cursor = self.conn.cursor()
        photo_id = str(abs(hash(str(photo_path))))
        now = datetime.now().isoformat()
        metadata = analysis.get("metadata", {})
        scene_list = analysis.get("scene", [])
        scene_names = []
        for s in scene_list:
            if isinstance(s, tuple):
                scene_names.append(s[0])
            elif isinstance(s, dict):
                scene_names.append(s.get("scene", "unknown"))
            else:
                scene_names.append(str(s))
        obj_list = analysis.get("objects", [])
        obj_names = [o["label"] if isinstance(o, dict) else str(o) for o in obj_list]
        cursor.execute("""
            INSERT OR REPLACE INTO photos
            (id, path, filename, category, persons, scenes, objects, date_taken, gps_lat, gps_lon, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            photo_id,
            str(photo_path),
            Path(photo_path).name,
            category,
            json.dumps([f.get("name", "unknown") if isinstance(f, dict) else "unknown" for f in analysis.get("faces", [])]),
            json.dumps(scene_names),
            json.dumps(obj_names),
            metadata.get("date"),
            metadata.get("gps_lat"),
            metadata.get("gps_lon"),
            now,
        ))
        self.conn.commit()

    def get_all_photos(self):
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM photos")
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in rows]

    def search_photos(self, query, limit=50):
        cursor = self.conn.cursor()
        q = f"%{query}%"
        cursor.execute("""
            SELECT * FROM photos
            WHERE persons LIKE ? OR scenes LIKE ? OR objects LIKE ? OR category LIKE ? OR filename LIKE ?
            LIMIT ?
        """, (q, q, q, q, q, limit))
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in rows]

    def photo_exists(self, photo_path):
        cursor = self.conn.cursor()
        cursor.execute("SELECT 1 FROM photos WHERE path = ?", (str(photo_path),))
        return cursor.fetchone() is not None

    def store_known_face(self, name, embedding_path, sample_images):
        cursor = self.conn.cursor()
        face_id = str(abs(hash(name)))
        cursor.execute("""
            INSERT OR REPLACE INTO known_faces (id, name, embedding_path, sample_images, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, (face_id, name, embedding_path, json.dumps(sample_images), datetime.now().isoformat()))
        self.conn.commit()

    def get_known_faces(self):
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM known_faces")
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in rows]

    def store_chat_message(self, role, content, photo_context=None):
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO chat_history (role, content, photo_context, timestamp)
            VALUES (?, ?, ?, ?)
        """, (role, content, json.dumps(photo_context) if photo_context else None, datetime.now().isoformat()))
        self.conn.commit()

    def get_chat_history(self, limit=50):
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM chat_history ORDER BY id DESC LIMIT ?", (limit,))
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in reversed(rows)]

    def clear_chat_history(self):
        cursor = self.conn.cursor()
        cursor.execute("DELETE FROM chat_history")
        self.conn.commit()

    def get_stats(self):
        cursor = self.conn.cursor()
        stats = {}
        cursor.execute("SELECT category, COUNT(*) FROM photos GROUP BY category")
        stats["categories"] = dict(cursor.fetchall())
        cursor.execute("SELECT COUNT(*) FROM photos")
        stats["total_photos"] = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM photos WHERE persons != '[]'")
        stats["total_faces"] = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM known_faces")
        stats["total_persons"] = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(DISTINCT scenes) FROM photos WHERE scenes != '[]'")
        stats["total_scenes"] = cursor.fetchone()[0]
        return stats

    def get_all_locations(self):
        cursor = self.conn.cursor()
        cursor.execute("SELECT DISTINCT category as name, COUNT(*) as photo_count FROM photos WHERE category = 'locations' GROUP BY category")
        rows = cursor.fetchall()
        return [{"name": r[0], "photo_count": r[1]} for r in rows]

    def get_all_faces(self):
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM known_faces")
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in rows]

    def get_all_scenes(self):
        cursor = self.conn.cursor()
        cursor.execute("SELECT scenes FROM photos WHERE scenes != '[]'")
        rows = cursor.fetchall()
        scene_set = set()
        for row in rows:
            try:
                scenes = json.loads(row[0])
                for s in scenes:
                    scene_set.add(s)
            except (json.JSONDecodeError, TypeError):
                pass
        return [{"name": s} for s in sorted(scene_set)]

    def count_photos_by_scene(self, scene_name):
        cursor = self.conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM photos WHERE scenes LIKE ?", (f"%{scene_name}%",))
        return cursor.fetchone()[0]

    def close(self):
        self.conn.close()
