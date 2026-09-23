from pathlib import Path
from src.database import Database
from datetime import datetime
import re
import os


class ChatBot:
    def __init__(self, database: Database):
        self.db = database
        self.llm = None
        self._init_llm()

    def _init_llm(self):
        model_path = Path("models/chatbot/smollm2-135m-instruct-q4_k_m.gguf")
        if not model_path.exists():
            return
        try:
            from ctransformers import AutoModelForCausalLM
            self.llm = AutoModelForCausalLM.from_pretrained(
                str(model_path),
                model_type="llama",
                max_new_tokens=256,
                temperature=0.7,
            )
        except Exception:
            self.llm = None

    def chat(self, message: str) -> str:
        if self.llm is not None:
            return self._llm_chat(message)
        return self._rule_based_chat(message)

    def _llm_chat(self, message: str) -> str:
        try:
            context = self._build_context(message)
            prompt = (
                "You are a helpful photo assistant. You have access to the user's photo library. "
                "Answer concisely based on the library data provided.\n\n"
                f"Library data:\n{context}\n\n"
                f"User: {message}\nAssistant:"
            )
            output = self.llm(prompt)
            if isinstance(output, str):
                return output.strip()
            return str(output).strip()
        except Exception:
            return self._rule_based_chat(message)

    def _build_context(self, message: str) -> str:
        parts = []
        msg_lower = message.lower()

        total_photos = self.db.get_total_photo_count()
        parts.append(f"Total photos: {total_photos}")

        locations = self.db.get_all_locations()
        if locations:
            loc_names = [loc["name"] for loc in locations[:20]]
            parts.append(f"Locations found: {', '.join(loc_names)}")

        faces = self.db.get_all_faces()
        if faces:
            face_names = [f["name"] for f in faces if f["name"] != "unknown"]
            if face_names:
                parts.append(f"People identified: {', '.join(set(face_names))}")

        scenes = self.db.get_all_scenes()
        if scenes:
            scene_names = [s["name"] for s in scenes[:10]]
            parts.append(f"Scenes: {', '.join(scene_names)}")

        recent = self.db.search_photos(limit=5)
        if recent:
            recent_dates = [p.get("date_taken") for p in recent if p.get("date_taken")]
            if recent_dates:
                parts.append(f"Most recent photo dates: {', '.join(recent_dates)}")

        return "\n".join(parts)

    def _rule_based_chat(self, message: str) -> str:
        msg = message.lower()
        now = datetime.now()

        greeting_words = ["hello", "hi", "hey", "greetings"]
        if any(msg.startswith(w) for w in greeting_words):
            return (
                f"Hello! I'm your photo assistant. It's {now.strftime('%A, %B %d, %Y')}. "
                f"I can help you explore your photo library. Try asking about people, places, "
                f"or specific photos. Type /help to see what I can do."
            )

        if "help" in msg:
            return (
                "I can help you with:\n"
                "• Find photos by person: \"Show me photos with [name]\"\n"
                "• Find photos by place: \"Show photos from [location]\"\n"
                "• Find photos by time: \"Show photos from last month\"\n"
                "• Photo stats: \"How many photos do I have?\"\n"
                "• Organize photos: \"Organize my photos\"\n"
                "• Recent photos: \"Show recent photos\"\n"
                "• Scene info: \"What scenes are in my photos?\""
            )

        total = self.db.get_total_photo_count()

        if any(w in msg for w in ["how many", "total", "count", "stats", "statistics"]):
            locations = self.db.get_all_locations()
            faces = self.db.get_all_faces()
            scenes = self.db.get_all_scenes()
            parts = [f"You have {total} photos in your library."]
            if locations:
                parts.append(f"They span {len(locations)} different locations.")
            if faces:
                known = [f for f in faces if f["name"] != "unknown"]
                parts.append(f"I've identified {len(known)} different people.")
            if scenes:
                parts.append(f"There are {len(scenes)} different scene types.")
            return " ".join(parts)

        if "recent" in msg or "latest" in msg or "newest" in msg:
            photos = self.db.search_photos(limit=5)
            if photos:
                lines = ["Here are your most recent photos:"]
                for p in photos:
                    name = Path(p["file_path"]).name
                    date = p.get("date_taken") or "unknown date"
                    lines.append(f"• {name} ({date})")
                return "\n".join(lines)
            return "No photos found in the database yet."

        scene_query = ["scene", "type", "category", "indoor", "outdoor", "beach", "mountain"]
        if any(w in msg for w in scene_query):
            scenes = self.db.get_all_scenes()
            if scenes:
                lines = ["Here are the scene types in your photos:"]
                for s in scenes:
                    count = self.db.count_photos_by_scene(s["name"])
                    lines.append(f"• {s['name'].title()}: {count} photos")
                return "\n".join(lines)
            return "No scenes analyzed yet. Run the organizer first."

        location_query = ["location", "place", "where", "city", "country"]
        if any(w in msg for w in location_query):
            locations = self.db.get_all_locations()
            if locations:
                lines = ["Here are the locations in your photos:"]
                for loc in locations:
                    lines.append(f"• {loc['name']} ({loc['photo_count']} photos)")
                return "\n".join(lines)
            return "No locations found yet. Run the organizer first."

        person_query = ["person", "people", "face", "who", "someone", "recognize"]
        if any(w in msg for w in person_query):
            faces = self.db.get_all_faces()
            if faces:
                lines = ["Here are the people I've identified:"]
                for f in faces:
                    lines.append(f"• {f['name']} ({f['face_count']} faces)")
                return "\n".join(lines)
            return "No faces identified yet. Run the organizer first."

        if any(w in msg for w in ["today", "date", "day", "time"]):
            return f"Today is {now.strftime('%A, %B %d, %Y')} at {now.strftime('%I:%M %p')}."

        if any(w in msg for w in ["hello", "hi", "hey", "how are you"]):
            return (
                f"Hey there! It's {now.strftime('%A')}. "
                f"You have {total} photos. How can I help you explore them?"
            )

        if "sort" in msg or "organize" in msg:
            return "I can help organize photos. Use the Organize button in the dashboard to start sorting."

        if any(w in msg for w in ["thank", "thanks", "nice"]):
            return "You're welcome! Let me know if you need anything else with your photos."

        return (
            f"I understand you're asking about photos. "
            f"You currently have {total} photos in your library. "
            f"Try asking about people, locations, scenes, or specific photos. "
            f"Type /help for a list of things I can do."
        )
