const { createApp, ref, reactive, computed, watch, nextTick, onMounted, onUnmounted } = Vue;

const API = '';

const app = createApp({
    setup() {
        const currentPage = ref('home');
        const sidebarCollapsed = ref(false);

        const stats = ref({});
        const toasts = ref([]);

        const organizeForm = reactive({
            sourceDir: '',
            organizeBy: 'auto',
            moveFiles: false,
        });
        const organizing = ref(false);
        const organizeResults = ref(null);
        const organizePollTimer = ref(null);

        const chatMessages = ref([]);
        const chatInput = ref('');
        const chatLoading = ref(false);
        const chatPhotoFile = ref(null);
        const chatPhotoPreview = ref(null);
        const chatPhotoAnalysis = ref(null);
        const chatMessagesRef = ref(null);

        const knownFaces = ref({});
        const faceForm = reactive({ name: '' });
        const faceFile = ref(null);
        const facePreview = ref(null);

        const testFile = ref(null);
        const testPreview = ref(null);
        const testResults = ref(null);
        const testLoading = ref(false);

        const sortedPhotos = ref({});
        const browseCategory = ref('persons');
        const browseLoading = ref(false);
        const searchQuery = ref('');
        const searchResults = ref([]);
        const searchLoading = ref(false);
        let searchDebounce = null;

        const currentBrowsePhotos = computed(() => {
            return sortedPhotos.value[browseCategory.value] || [];
        });

        function showToast(message, type = 'success') {
            toasts.value.push({ message, type });
            setTimeout(() => toasts.value.shift(), 3000);
        }

        function photoUrl(path) {
            return `${API}/api/photo/${encodeURIComponent(path)}`;
        }

        async function fetchStats() {
            try {
                const res = await fetch(`${API}/api/stats`);
                stats.value = await res.json();
            } catch (e) {
                console.error('Failed to fetch stats:', e);
            }
        }

        async function fetchSortedPhotos() {
            browseLoading.value = true;
            try {
                const res = await fetch(`${API}/api/sorted`);
                sortedPhotos.value = await res.json();
                const cats = Object.keys(sortedPhotos.value);
                if (cats.length && !cats.includes(browseCategory.value)) {
                    browseCategory.value = cats[0];
                }
            } catch (e) {
                console.error('Failed to fetch sorted photos:', e);
            } finally {
                browseLoading.value = false;
            }
        }

        async function startOrganize() {
            if (!organizeForm.sourceDir.trim()) {
                showToast('Please enter a directory path', 'error');
                return;
            }
            organizing.value = true;
            organizeResults.value = null;
            try {
                const res = await fetch(`${API}/api/organize`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        source_dir: organizeForm.sourceDir,
                        organize_by: organizeForm.organizeBy,
                        move_files: organizeForm.moveFiles,
                    }),
                });
                const data = await res.json();
                if (data.status === 'started') {
                    showToast('Organization started in background');
                    pollOrganizeProgress();
                } else {
                    organizeResults.value = data;
                    organizing.value = false;
                    showToast(`Organized ${data.organized} photos!`);
                    fetchStats();
                    fetchSortedPhotos();
                }
            } catch (e) {
                showToast('Failed to organize photos', 'error');
                organizing.value = false;
            }
        }

        function pollOrganizeProgress() {
            if (organizePollTimer.value) clearInterval(organizePollTimer.value);
            organizePollTimer.value = setInterval(async () => {
                try {
                    const res = await fetch(`${API}/api/organize/progress`);
                    const data = await res.json();
                    if (!data.running) {
                        clearInterval(organizePollTimer.value);
                        organizePollTimer.value = null;
                        organizing.value = false;
                        if (data.result && !data.result.error) {
                            organizeResults.value = data.result;
                            showToast('Organization complete!');
                            fetchStats();
                            fetchSortedPhotos();
                        } else {
                            showToast(data.result?.error || 'Organization failed', 'error');
                        }
                    }
                } catch (e) {
                    clearInterval(organizePollTimer.value);
                    organizePollTimer.value = null;
                    organizing.value = false;
                }
            }, 1000);
        }

        async function sendChat(message) {
            if (!message || !message.trim()) return;

            chatMessages.value.push({ role: 'user', content: message });
            chatInput.value = '';
            chatLoading.value = true;
            scrollChat();

            try {
                const res = await fetch(`${API}/api/chat`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message }),
                });
                const data = await res.json();
                chatMessages.value.push({ role: 'assistant', content: data.response });
            } catch (e) {
                chatMessages.value.push({ role: 'assistant', content: 'Sorry, something went wrong.' });
            } finally {
                chatLoading.value = false;
                scrollChat();
            }
        }

        function scrollChat() {
            nextTick(() => {
                const el = document.querySelector('.chat-messages');
                if (el) el.scrollTop = el.scrollHeight;
            });
        }

        async function fetchFaces() {
            try {
                const res = await fetch(`${API}/api/faces`);
                const data = await res.json();
                knownFaces.value = data.faces || {};
            } catch (e) {
                console.error(e);
            }
        }

        function handleFacePhoto(e) {
            const file = e.target.files[0];
            if (!file) return;
            faceFile.value = file;
            facePreview.value = URL.createObjectURL(file);
        }

        function handleFaceDrop(e) {
            const file = e.dataTransfer.files[0];
            if (!file || !file.type.startsWith('image/')) return;
            faceFile.value = file;
            facePreview.value = URL.createObjectURL(file);
        }

        async function addFace() {
            if (!faceForm.name || !faceFile.value) return;

            const formData = new FormData();
            formData.append('name', faceForm.name);
            formData.append('file', faceFile.value);

            try {
                const res = await fetch(`${API}/api/faces/add`, {
                    method: 'POST',
                    body: formData,
                });
                if (res.ok) {
                    showToast(`Added ${faceForm.name}!`);
                    faceForm.name = '';
                    faceFile.value = null;
                    facePreview.value = null;
                    fetchFaces();
                    fetchStats();
                } else {
                    showToast('No face detected in image', 'error');
                }
            } catch (e) {
                showToast('Failed to add face', 'error');
            }
        }

        async function removeFace(name) {
            if (!confirm(`Remove ${name}?`)) return;
            try {
                await fetch(`${API}/api/faces/${encodeURIComponent(name)}`, { method: 'DELETE' });
                showToast(`Removed ${name}`);
                fetchFaces();
                fetchStats();
            } catch (e) {
                showToast('Failed to remove', 'error');
            }
        }

        function handleTestPhoto(e) {
            const file = e.target.files[0];
            if (!file) return;
            testFile.value = file;
            testPreview.value = URL.createObjectURL(file);
            testFace();
        }

        async function testFace() {
            if (!testFile.value) return;
            testResults.value = null;
            testLoading.value = true;

            const formData = new FormData();
            formData.append('file', testFile.value);

            try {
                const res = await fetch(`${API}/api/faces/test`, {
                    method: 'POST',
                    body: formData,
                });
                const data = await res.json();
                testResults.value = data.faces;
            } catch (e) {
                showToast('Test failed', 'error');
            } finally {
                testLoading.value = false;
            }
        }

        function onSearchInput() {
            if (searchDebounce) clearTimeout(searchDebounce);
            searchDebounce = setTimeout(() => searchPhotos(), 300);
        }

        async function searchPhotos() {
            if (!searchQuery.value.trim()) {
                searchResults.value = [];
                return;
            }
            searchLoading.value = true;
            try {
                const res = await fetch(`${API}/api/search?q=${encodeURIComponent(searchQuery.value)}`);
                const data = await res.json();
                searchResults.value = data.results;
            } catch (e) {
                console.error(e);
            } finally {
                searchLoading.value = false;
            }
        }

        function getBarWidth(count) {
            const vals = Object.values(stats.value.categories || {});
            const max = vals.length ? Math.max(...vals, 1) : 1;
            return (count / max) * 100;
        }

        function openPhoto(photo) {
            window.open(`/api/photo/${encodeURIComponent(photo.path)}`, '_blank');
        }

        function faceBoxStyle(bbox, imgEl) {
            if (!bbox || !imgEl) return {};
            const natW = imgEl.naturalWidth || 1;
            const natH = imgEl.naturalHeight || 1;
            const dispW = imgEl.clientWidth || 1;
            const dispH = imgEl.clientHeight || 1;
            const sx = dispW / natW;
            const sy = dispH / natH;
            return {
                left: (bbox[0] * sx) + 'px',
                top: (bbox[1] * sy) + 'px',
                width: ((bbox[2] - bbox[0]) * sx) + 'px',
                height: ((bbox[3] - bbox[1]) * sy) + 'px',
            };
        }

        watch(currentPage, (page) => {
            if (page === 'browse') fetchSortedPhotos();
            if (page === 'faces') fetchFaces();
            if (page === 'home' || page === 'stats') fetchStats();
        });

        onMounted(() => {
            fetchStats();
            fetchFaces();
        });

        onUnmounted(() => {
            if (organizePollTimer.value) clearInterval(organizePollTimer.value);
            if (searchDebounce) clearTimeout(searchDebounce);
        });

        return {
            currentPage, sidebarCollapsed, stats, toasts,
            organizeForm, organizing, organizeResults, startOrganize,
            chatMessages, chatInput, chatLoading,
            chatMessagesRef, sendChat,
            knownFaces, faceForm, faceFile, facePreview,
            handleFacePhoto, handleFaceDrop, addFace, removeFace,
            testFile, testPreview, testResults, testLoading, handleTestPhoto,
            sortedPhotos, browseCategory, browseLoading, currentBrowsePhotos,
            searchQuery, searchResults, searchLoading, onSearchInput, searchPhotos,
            getBarWidth, openPhoto, photoUrl, faceBoxStyle,
        };
    },
});

app.mount('#app');
