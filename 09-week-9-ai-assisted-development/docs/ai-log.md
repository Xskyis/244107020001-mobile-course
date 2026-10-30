# AI Log: Catatan Prompt, Generasi, Verifikasi, dan Refactoring

Dokumen ini memuat dokumentasi komprehensif dari seluruh siklus **AI-Assisted Development** pada penambahan fitur **Pencarian Catatan (Search & Filter) + Empty State** pada project **Week 5 (Offline First Notes)**, sesuai dengan panduan codelab Minggu 9.

---

## 1. Praktikum 1: Prompt dan Context Engineering

### Formula 5 Slot Prompt
Untuk menghasilkan kode yang presisi, teruji, dan sesuai batasan arsitektur, prompt dirancang menggunakan formula 5 slot:

```text
[Peran]   : Senior Flutter Developer
[Konteks] : Proyek Flutter offline-first notes menggunakan Riverpod (Notifier & FutureProvider),
            SQLite (sqflite), dan model Note (id, title, body, updatedAt, dirty).
[Tugas]   : Tambahkan fitur pencarian catatan berdasarkan judul dan isi catatan (case-insensitive)
            lengkap dengan tampilan empty state jika catatan yang dicari tidak ditemukan.
[Batas]   : Jangan memanggil query database langsung dari widget; pisahkan logika filter ke fungsi
            murni atau provider terisolasi; jangan mengubah skema database yang sudah ada;
            maksimal 80 baris kode.
[Output]  : Fungsi filter murni + StateNotifier/Provider Riverpod + potongan widget UI + 3 unit test.
```

### Perbandingan Prompt Buruk vs Prompt Baik

| Kategori | Prompt Buruk (*Vibe Coding*) | Prompt Baik (*Context-Engineered*) |
| :--- | :--- | :--- |
| **Instruksi** | *"Buatin fitur search catatan yang keren dan langsung jadi dong."* | Mengisi kelima slot secara spesifik: peran senior dev, konteks Riverpod & offline-notes, aturan penanganan empty state, serta kriteria uji. |
| **Dampak Hasil** | Menghasilkan kode monolitik di dalam `build()`, memakai package pencarian pihak ketiga yang tidak terdaftar di `pubspec.yaml`, dan membocorkan query database ke UI. | Menghasilkan fungsi murni yang mudah di-unit test, terintegrasi mulus dengan Riverpod `filteredNotesProvider`, dan ramah arsitektur. |
| **Konteks & Keamanan** | Menempelkan seluruh kode repositori atau kredensial/token tanpa filter. | Hanya menempelkan kontrak kelas `Note` dan `notesProvider`, tanpa membocorkan secret atau file yang tidak relevan. |

---

## 2. Praktikum 2: Generate dan Verifikasi Search

### 1. Prompt Mentah yang Dikirimkan ke AI
```text
Sebagai senior Flutter dev, buatkan fitur pencarian catatan pada aplikasi offline notes Flutter berbasis Riverpod.
Konteks:
- Model Note memiliki field: int? id, String title, String body, DateTime updatedAt, bool dirty.
- Catatan saat ini diakses lewat notesProvider (FutureProvider<List<Note>>).
Kebutuhan:
1. Fungsi filter pencarian case-insensitive pada title dan body.
2. Provider Riverpod untuk query pencarian dan hasil filter.
3. UI SearchBar / TextField dengan tombol clear dan tampilan Empty State jika hasil pencarian nihil.
4. Minimal 2 unit test pembuktian logika filter.
Batasan: Jangan ada query raw SQLite di dalam widget UI.
```

### 2. Output Awal dari AI (Raw Generation)
```dart
// 1. Helper Filter
List<Note> filterNotesByQuery(List<Note> notes, String query) {
  final clean = query.trim().toLowerCase();
  if (clean.isEmpty) return notes;
  return notes.where((n) =>
    n.title.toLowerCase().contains(clean) ||
    n.body.toLowerCase().contains(clean)
  ).toList();
}

// 2. Providers
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
  void clear() => state = '';
}
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notes = ref.watch(notesProvider);
  final query = ref.watch(searchQueryProvider);
  return notes.whenData((list) => filterNotesByQuery(list, query));
});
```

### 3. Verifikasi 6 Langkah

1. **Baca Tiap Baris:**
   - Baris logika `filterNotesByQuery` dipahami: fungsi murni mengambil list, melakukan *lowercasing* pada query dan data, lalu memfilter dengan predikat logika OR (`||`).
   - `filteredNotesProvider` memanfaatkan `.whenData()` dari Riverpod `AsyncValue`, menjaga state loading/error bawaan dari `notesProvider`.
2. **Cek Import & Arsitektur:**
   - File `search.dart` hanya mengimpor model `local/note.dart`. Bebas dari dependensi UI Flutter, Dio, maupun SQLite.
3. **Cek Ketersediaan API Nyata:**
   - Method `contains()`, `toLowerCase()`, `trim()` pada `String` tersedia pada SDK Dart core.
   - Pola `Notifier<String>` dan `.whenData()` valid di Riverpod 2.x.
4. **Jalankan Static Analysis:**
   - Dijalankan `flutter analyze` pada direktori project: `No issues found! (ran in 3.6s)`.
5. **Uji Unit Test & Widget Test:**
   - Dibuat 4 unit test untuk pure logic (case-insensitive, non-matching query, empty query, search by body).
   - Dibuat 1 widget test untuk memverifikasi interaksi pengetikan query pada TextField dan pemunculan `search_empty_state_text`. Seluruh test berstatus **All tests passed!**.
6. **Uji Manual:**
   - Input query cocok (`"belanja"`) $\rightarrow$ Hanya catatan relevan yang tampil.
   - Input query acak (`"zzztakada"`) $\rightarrow$ Widget empty state dengan ikon `Icons.search_off` muncul.
   - Tekan icon clear (`X`) $\rightarrow$ Seluruh catatan kembali tampil utuh.

---

## 3. Praktikum 3: Debug dan Refactor

### 1. Siklus Debug dengan Test Merah (Red-to-Green Testing)

1. **Reproduksi Masalah:**
   Pada implementasi awal, pencarian rentan terhadap whitespace: jika pengguna menekan tombol spasi beberapa kali (`"   "`), fungsi filter menganggap query tidak kosong dan melakukan pencocokan terhadap string kosong, atau jika huruf besar/kecil tidak ditangani konsisten maka pencarian `"BELANJA"` gagal menemukan `"Belanja"`.
2. **Isolasi Logika:**
   Logika pencarian dipisahkan sepenuhnya dari widget `NotesTab` ke berkas `lib/data/search.dart` sebagai fungsi murni `filterNotesByQuery(List<Note> notes, String query)`.
3. **Pembuatan Test Merah (Failing Test):**
   ```dart
   test('Filter abaikan huruf besar/kecil (case-insensitive)', () {
     final results = filterNotesByQuery(sampleNotes, 'bElAnJa');
     expect(results.length, 2); // Awalnya gagal jika implementasi naif
   });
   ```
4. **Perbaikan Kode (Fix):**
   Memastikan pemanggilan `.trim().toLowerCase()` sebelum pencocokan substring dilakukan:
   ```dart
   final cleanQuery = query.trim().toLowerCase();
   if (cleanQuery.isEmpty) return notes;
   ```
5. **Akar Masalah (Root Cause Analysis):**
   Perbedaan representasi string pada form input pengguna dan teks database. Tanpa normalisasi `trim()` dan `toLowerCase()`, perbandingan string menghasilkan false negative.

---

### 2. Refaktorisasi ke Layer yang Tepat

Pemisahan tanggung jawab dilakukan sesuai prinsip Separation of Concerns:
- **Presentation Layer (Widget UI):** `NotesTab` di `lib/main.dart` hanya bertugas merender form input pencarian dan mendengarkan `filteredNotesProvider`. Tidak ada satu baris pun logika komparasi string atau query SQL di dalam method `build()`.
- **Presentation Layer (State Management):** `SearchQueryNotifier` di `lib/data/providers.dart` mengelola state teks query secara reaktif.
- **Pure Logic Layer:** `filterNotesByQuery` di `lib/data/search.dart` menangani aturan filtering tanpa efek samping (*side-effect free*).
- **Data Layer:** `NoteRepository` di `lib/data/repositories/note_repository.dart` tetap fokus mengelola persistensi data SQLite lokal.

---

## 4. AI Challenge: Review Senior Developer

### 1. Prompt Review Senior Dev
```text
Review kode search Flutter ini sebagai senior dev.
Konteks: feature-first (presentation->domain<-data),
Riverpod, SQLite + Dio.
Fokus: kebenaran, arsitektur, test. Abaikan style.
Beri 3 temuan + level blocker/saran + alasan.
```

### 2. Tiga Temuan AI & Evaluasi Kritis

| No | Temuan AI | Level | Analisis & Verifikasi Developer | Keputusan Final |
| :---: | :--- | :---: | :--- | :---: |
| **1** | **Edge Case Whitespace:** Pengujian unit test harus mencakup query yang hanya terdiri dari whitespace (`"   "`). Jika tidak di-trim, fungsi filter akan memfilter data yang tidak diinginkan. | **Blocker** | **Terbukti Benar:** Pengujian manual dan unit test membuktikan bahwa tanpa `query.trim().isEmpty`, spasi akan dicocokkan sebagai substring spasi di dalam konten. |  **Diterima & Diperbaiki** |
| **2** | **Halusinasi Arsitektural AI:** AI menyarankan: *"Pindahkan pencarian ke SQLite menggunakan query `WHERE title LIKE '%query%'` setiap kali `onChanged` dipicu pada TextField agar lebih hemat memori."* | **Blocker** | **HALUSINASI BERBAHAYA:** Pada arsitektur offline-first dengan dataset lokal berukuran kecil-menengah (catatan pribadi), menjalankan query I/O disk SQLite pada setiap ketukan keyboard tanpa debouncing akan memicu lag UI, race condition, dan disk thrashing. In-memory filter pada Riverpod stream/provider jauh lebih instan (0ms) dan menjaga widget tetap terisolasi dari database. | ❌ **Ditolak Keras** |
| **3** | **UX Keterbacaan:** Sediakan aksi cepat pembersihan query (tombol `Icons.clear`) pada `InputDecoration.suffixIcon` hanya ketika ada teks query aktif. | **Saran** | **Terbukti Membantu UX:** Meningkatkan kenyamanan pengguna saat ingin membatalkan pencarian dan kembali ke daftar lengkap catatan dalam 1 ketukan. |  **Diterima** |

---

## 5. Ringkasan Siklus Vibe Coding vs Responsible AI Development

```
[Prompt Terstruktur] ──> [Generate Kode AI] ──> [Verifikasi Manusia (Read & Grep)]
                                                           │
                                                           ▼
[Dokumentasi & Refleksi] <── [Refactoring Bersih] <── [Testing (Analyze & Test)]
```

Dengan alur di atas, pengembang tidak menjadi "pengetik pasif" saran AI (*vibe coding*), melainkan bertindak sebagai **kurator dan arsitek kode** yang menjamin keamanan, kebenaran logika, dan kebersihan arsitektur sistem.

