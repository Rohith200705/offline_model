import streamlit as st
import os
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))

from config import BASE_DIR, SORTED_DIR, CATEGORIES
from src.photo_organizer import PhotoOrganizer
from src.chatbot import PhotoChatbot
from src.image_processor import ImageProcessor
from src.database import Database


st.set_page_config(
    page_title="Offline Photo Organizer",
    page_icon="📷",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown("""
<style>
    .stApp { max-width: 1200px; margin: 0 auto; }
    .photo-card {
        border: 1px solid #ddd;
        border-radius: 8px;
        padding: 10px;
        margin: 5px 0;
        background: #f9f9f9;
    }
    .stat-box {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 20px;
        border-radius: 10px;
        text-align: center;
    }
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def load_organizer():
    return PhotoOrganizer()


@st.cache_resource
def load_chatbot():
    return PhotoChatbot()


@st.cache_resource
def load_processor():
    return ImageProcessor()


@st.cache_resource
def load_database():
    return Database()


def home_page():
    st.title("📷 Offline Photo Organizer & Chatbot")
    st.markdown("---")

    col1, col2, col3, col4 = st.columns(4)

    db = load_database()
    stats = db.get_stats()

    with col1:
        st.metric("Total Photos", stats.get("total_photos", 0))
    with col2:
        st.metric("Known Faces", stats.get("known_faces", 0))
    with col3:
        cats = stats.get("categories", {})
        st.metric("Categories", len(cats))
    with col4:
        st.metric("Storage", "~1-2GB")

    st.markdown("---")

    st.subheader("Features")
    feat_col1, feat_col2, feat_col3 = st.columns(3)

    with feat_col1:
        st.markdown("""
        **📁 Auto-Organize**
        - Sort by persons
        - Sort by locations
        - Sort by objects
        - Sort by date
        """)

    with feat_col2:
        st.markdown("""
        **🔍 Smart Detection**
        - Face recognition
        - Scene classification
        - Object detection
        - Metadata extraction
        """)

    with feat_col3:
        st.markdown("""
        **💬 Chat Assistant**
        - Ask about photos
        - Learn names
        - Remember conversations
        - 100% offline
        """)

    st.markdown("---")

    st.subheader("Quick Start")
    st.markdown("""
    1. **Setup**: Run `python setup.py` to download required models
    2. **Organize**: Go to 'Organize Photos' tab and enter your photo directory
    3. **Chat**: Use the 'Chat' tab to ask questions about your photos
    4. **Manage**: Add known faces in the 'Manage Faces' tab
    """)


def organize_page():
    st.title("📁 Organize Photos")

    source_dir = st.text_input(
        "Enter the path to your photos directory:",
        placeholder="e.g., D:\\Photos\\Camera Roll",
    )

    col1, col2 = st.columns(2)
    with col1:
        organize_by = st.selectbox(
            "Organize by:",
            ["Auto (Recommended)", "Persons", "Locations", "Objects", "Events", "Date"],
        )
    with col2:
        move_files = st.checkbox("Move files (instead of copy)", value=False)

    if st.button("🚀 Start Organizing", type="primary", use_container_width=True):
        if not source_dir or not Path(source_dir).exists():
            st.error("Please enter a valid directory path")
            return

        organizer = load_organizer()
        category = organize_by.lower().split(" ")[0]

        with st.spinner("Analyzing and organizing photos... This may take a while."):
            results = organizer.organize_photos(source_dir, category, move_files)

        if "error" in results:
            st.error(results["error"])
        else:
            st.success(f"Organization complete!")

            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Found", results["total"])
            with col2:
                st.metric("Organized", results["organized"])
            with col3:
                st.metric("Skipped", results["skipped"])

            if results["errors"] > 0:
                st.warning(f"{results['errors']} files had errors")

            if results.get("details"):
                with st.expander("View Details"):
                    for detail in results["details"][:50]:
                        if "error" in detail:
                            st.error(f"  {detail['file']}: {detail['error']}")
                        else:
                            st.success(f"  {detail['file']} -> {detail['category']}")

    st.markdown("---")
    st.subheader("📂 Sorted Photos Directory")

    sorted_dir = SORTED_DIR
    if sorted_dir.exists():
        for cat_name, cat_dir in CATEGORIES.items():
            if cat_dir.exists():
                file_count = len(list(cat_dir.rglob("*.*")))
                if file_count > 0:
                    with st.expander(f"📁 {cat_name.title()} ({file_count} files)"):
                        for f in sorted(cat_dir.rglob("*.*"))[:20]:
                            st.text(f"  {f.relative_to(cat_dir)}")


def chat_page():
    st.title("💬 Chat About Your Photos")

    chatbot = load_chatbot()
    processor = load_processor()

    if st.button("🗑️ Clear Chat History"):
        chatbot.clear_memory()
        st.rerun()

    chat_container = st.container()

    with chat_container:
        for msg in chatbot.conversation_history:
            if msg["role"] == "user":
                with st.chat_message("user"):
                    st.write(msg["content"])
            else:
                with st.chat_message("assistant"):
                    st.write(msg["content"])

    prompt = st.chat_input("Ask about your photos...")

    if prompt:
        with st.chat_message("user"):
            st.write(prompt)

        with st.spinner("Thinking..."):
            response = chatbot.chat(prompt)

        with st.chat_message("assistant"):
            st.write(response)

    st.markdown("---")
    st.subheader("📸 Analyze a Photo")

    uploaded_photo = st.file_uploader(
        "Upload a photo to ask questions about it:",
        type=["jpg", "jpeg", "png", "gif", "bmp", "webp"],
    )

    if uploaded_photo:
        img = Image.open(uploaded_photo)
        st.image(img, caption="Uploaded Photo", use_container_width=True)

        temp_path = BASE_DIR / "temp_upload.jpg"
        img.save(temp_path)

        with st.spinner("Analyzing photo..."):
            analysis = processor.analyze_image(temp_path)

        col1, col2, col3 = st.columns(3)
        with col1:
            st.markdown("**Faces:**")
            for face in analysis.get("faces", []):
                st.text(f"  - {face.get('name', 'unknown')} ({face.get('confidence', 0):.0%})")

        with col2:
            st.markdown("**Scene:**")
            for scene in analysis.get("scene", [])[:2]:
                st.text(f"  - {scene['scene']} ({scene['confidence']:.0%})")

        with col3:
            st.markdown("**Objects:**")
            for obj in analysis.get("objects", [])[:5]:
                st.text(f"  - {obj['label']} ({obj.get('confidence', 0):.0%})")

        question = st.text_input("Ask a question about this photo:")

        if question:
            with st.spinner("Thinking..."):
                response = chatbot.ask_about_photo(question, analysis)

            with st.chat_message("assistant"):
                st.write(response)

        if temp_path.exists():
            temp_path.unlink()


def faces_page():
    st.title("👤 Manage Known Faces")

    processor = load_processor()

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Add New Person")
        person_name = st.text_input("Person's name:", key="new_face_name")

        uploaded_face = st.file_uploader(
            "Upload a photo of this person:",
            type=["jpg", "jpeg", "png"],
            key="face_upload",
        )

        if st.button("➕ Add Person", type="primary"):
            if not person_name:
                st.error("Please enter a name")
            elif not uploaded_face:
                st.error("Please upload a photo")
            else:
                temp_path = BASE_DIR / "temp_face.jpg"
                img = Image.open(uploaded_face)
                img.save(temp_path)

                success = processor.face_identifier.add_known_face(
                    person_name, [temp_path]
                )

                if success:
                    st.success(f"Added {person_name} to known faces!")
                    st.rerun()
                else:
                    st.error("Could not detect a face in the image")

                if temp_path.exists():
                    temp_path.unlink()

    with col2:
        st.subheader("Known Faces")

        known_faces = processor.face_identifier.known_faces

        if not known_faces:
            st.info("No known faces yet. Add your first person!")
        else:
            for name, info in known_faces.items():
                with st.expander(f"👤 {name}"):
                    st.text(f"Samples: {len(info.get('sample_images', []))}")
                    if st.button(f"Remove {name}", key=f"remove_{name}"):
                        processor.face_identifier.remove_known_face(name)
                        st.rerun()

    st.markdown("---")
    st.subheader("🔍 Test Face Recognition")

    test_photo = st.file_uploader(
        "Upload a photo to test recognition:",
        type=["jpg", "jpeg", "png"],
        key="test_face",
    )

    if test_photo:
        img = Image.open(test_photo)
        st.image(img, caption="Test Photo", use_container_width=True)

        temp_path = BASE_DIR / "temp_test.jpg"
        img.save(temp_path)

        with st.spinner("Detecting faces..."):
            faces = processor.face_identifier.detect_faces(temp_path)

        if faces:
            st.success(f"Found {len(faces)} face(s):")
            for i, face in enumerate(faces):
                st.text(
                    f"  Face {i + 1}: {face['name']} (confidence: {face['confidence']:.0%})"
                )
        else:
            st.warning("No faces detected")

        if temp_path.exists():
            temp_path.unlink()


def stats_page():
    st.title("📊 Statistics")

    db = load_database()
    stats = db.get_stats()

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Total Photos", stats.get("total_photos", 0))
    with col2:
        st.metric("Known Faces", stats.get("known_faces", 0))
    with col3:
        cats = stats.get("categories", {})
        st.metric("Categories Used", len(cats))

    st.markdown("---")

    categories = stats.get("categories", {})
    if categories:
        st.subheader("Photos by Category")

        import pandas as pd
        import plotly.express as px

        df = pd.DataFrame(
            list(categories.items()), columns=["Category", "Count"]
        )
        fig = px.bar(df, x="Category", y="Count", color="Category")
        st.plotly_chart(fig, use_container_width=True)

        fig2 = px.pie(df, names="Category", values="Count")
        st.plotly_chart(fig2, use_container_width=True)
    else:
        st.info("No photos organized yet. Go to 'Organize Photos' to get started!")

    st.markdown("---")
    st.subheader("Recently Organized")

    all_photos = db.get_all_photos()
    if all_photos:
        import pandas as pd

        df = pd.DataFrame(all_photos[-20:])
        st.dataframe(
            df[["filename", "category", "date_taken"]].fillna("N/A"),
            use_container_width=True,
        )
    else:
        st.info("No photo records yet.")


def main():
    with st.sidebar:
        st.image("https://img.icons8.com/color/96/camera--v1.png", width=64)
        st.title("Photo Organizer")
        st.markdown("---")

        page = st.radio(
            "Navigation",
            ["🏠 Home", "📁 Organize Photos", "💬 Chat", "👤 Manage Faces", "📊 Stats"],
            label_visibility="collapsed",
        )

        st.markdown("---")
        st.markdown("🔒 **100% Offline**")
        st.markdown("Your data never leaves your device.")

    if page == "🏠 Home":
        home_page()
    elif page == "📁 Organize Photos":
        organize_page()
    elif page == "💬 Chat":
        chat_page()
    elif page == "👤 Manage Faces":
        faces_page()
    elif page == "📊 Stats":
        stats_page()


if __name__ == "__main__":
    main()
