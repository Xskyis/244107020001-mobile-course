# AI Code Review vs Keputusan Final Developer

Dokumen ini mencatat interaksi peninjauan kode (code review) menggunakan AI Coding Assistant pada project Flutter berbasis **Feature-First Clean Architecture**, serta hasil audit kritis verifikasi manusia sebelum saran AI diterapkan ke codebase.

---

## 1. Prompt AI Challenge

Prompt yang dikirimkan kepada AI Assistant (berperan sebagai Senior Flutter Developer):

```text
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data),
Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran)
+ alasan + usulan potongan kode perbaikan.
```

---

## 2. Ringkasan 5 Temuan AI

AI memberikan 5 temuan teknis sebagai berikut:

### Temuan 1 (Level: Blocker - Kebenaran & Edge Case)
- **File:** `lib/features/notes/domain/usecases/add_note.dart`
- **Tuduhan AI:** Validasi judul catatan hanya memeriksa `trimmedTitle.isEmpty`. Jika pengguna memasukkan judul hanya berisi karakter kontrol atau spasi tanpa kata, string lolos validasi jika tidak di-trim terlebih dahulu. Selain itu, parameter `body` tidak divalidasi atau di-trim sehingga berpotensi menyimpan spasi kosong masif ke storage lokal.
- **Usulan Kode AI:**
  ```dart
  final cleanTitle = title.trim();
  final cleanBody = body.trim();
  if (cleanTitle.isEmpty) {
    return Future.value((
      note: null,
      failure: const ValidationFailure('Judul catatan tidak boleh kosong.'),
    ));
  }
  return _repository.addNote(title: cleanTitle, body: cleanBody);
  ```

### Temuan 2 (Level: Blocker - Testing)
- **File:** `test/add_note_test.dart`
- **Tuduhan AI:** Test suite use case hanya menguji skenario sukses (`note != null`) dan validasi gagal di layer use case. Tidak ada unit test yang memverifikasi bagaimana use case bereaksi ketika `NoteRepository` mengembalikan kegagalan database (`LocalFailure`).
- **Usulan Kode AI:**
  ```dart
  test('AddNote menangani LocalFailure jika database gagal', () async {
    final repo = FakeNoteRepositoryForAdd(fail: true);
    final useCase = AddNote(repo);
    final result = await useCase(title: 'Catatan Baru');
    expect(result.note, isNull);
    expect(result.failure, isA<LocalFailure>());
  });
  ```

### Temuan 3 (Level: Blocker - Pelanggaran Arsitektur oleh AI)
- **File:** `lib/features/notes/domain/usecases/add_note.dart`
- **Tuduhan AI:** "Untuk mempercepat query dan mengurangi ketergantungan async, simpan cache catatan langsung di use case menggunakan `sqflite` atau `SharedPreferences` sebelum memanggil repository."
- **Usulan Kode AI:**
  ```dart
  import 'package:sqflite/sqflite.dart'; // Pelanggaran Clean Architecture!

  class AddNote {
    ...
    Future<void> cacheDirectly(Database db, Note note) async {
      await db.insert('notes_cache', note.toMap());
    }
  }
  ```

### Temuan 4 (Level: Saran - Style / Nitpick)
- **File:** `lib/features/notes/presentation/widgets/note_tile.dart`
- **Tuduhan AI:** Penempatan import helper format berada di baris acak dan tidak menyertakan trailing comma pada baris constructor `Text(...)`.
- **Usulan Kode AI:** Penataan ulang import dan penambahan trailing comma pada setiap widget leaf.

### Temuan 5 (Level: Saran - State Immutability)
- **File:** `lib/features/notes/presentation/providers/notes_providers.dart`
- **Tuduhan AI:** List catatan pada `NotesState` berpotensi dimutasi secara langsung oleh presentation layer (`state.notes.add(...)`) jika menggunakan tipe data mutable `List<Note>`. Sebaiknya gunakan `List.unmodifiable` atau unmodifiable view.
- **Usulan Kode AI:**
  ```dart
  state = state.copyWith(notes: List.unmodifiable(updatedNotes));
  ```

---

## 3. Matriks Verifikasi & Keputusan Final Developer

| No | Temuan AI & Target File | Kategori Temuan | Level | Hasil Verifikasi Developer | Keputusan Final | Alasan Teknis & Bukti |
| :---: | :--- | :--- | :---: | :--- | :---: | :--- |
| **1** | Trim validation pada `AddNote` (`add_note.dart`) | Kebenaran / Edge Case | **Blocker** | **Terbukti Benar** | **Diterima** | **Bukti:** Dilakukan pengujian dengan string spasi `"   "`. Jika tidak di-trim, string tersebut memiliki panjang 3 sehingga lolos pemeriksaan `title.isNotEmpty`. Perbaikan dilakukan dengan `title.trim().isEmpty`. |
| **2** | Skenario kegagalan DB pada test (`add_note_test.dart`) | Test Coverage | **Blocker** | **Terbukti Benar** | **Diterima** | **Bukti:** Test suite awal hanya memiliki 2 test. Unit test ketiga (`LocalFailure`) ditambahkan dengan `FakeNoteRepositoryForAdd(fail: true)` dan berhasil memverifikasi bahwa failure dari repository diteruskan secara utuh tanpa uncaught exception. |
| **3** | Direct caching `sqflite` di Domain Use Case | Arsitektur | **Blocker** | **HALUSINASI / SESAT (Saran Berbahaya)** | ❌ **Ditolak Keras** | **Alasan:** Usulan AI melanggar **The Dependency Rule** Clean Architecture secara fatal. Layer Domain harus 100% murni Dart dan tidak boleh mengimpor framework eksternal (`sqflite`, Flutter, Dio). Caching data adalah tanggung jawab layer Data (`NoteRepositoryImpl` / Local DataSource), bukan Domain Use Case. |
| **4** | Trailing comma & urutan baris import | Keterbacaan / Style | **Saran** | **Nitpick Linter** | ❌ **Ditolak dari PR Manual** | **Alasan:** Format import dan trailing comma merupakan domain otomatisasi `dart format` dan `flutter analyze` yang sudah dikawal oleh pipeline CI (`ci.yml`). Review manusia dan PR tidak boleh membuang waktu memperdebatkan spasi atau trailing comma. |
| **5** | Immutability pada Riverpod Notifier List | Kualitas State | **Saran** | **Terbukti Benar** | **Diterima (Disesuaikan)** | **Alasan:** Menjamin integritas unidirectional data flow Riverpod. List immutable mencegah widget UI memodifikasi collection secara imperatif di luar Notifier. |

---

## 4. Analisis Kritis: Kapan Mempercayai AI dan Kapan Menolaknya

1. **Kekuatan AI:** AI sangat unggul dalam mendeteksi *blind spot* logika tepi (seperti spasi kosong, null dereference, unhandled future error) dan celah cakupan unit test (*missing edge-case test cases*).
2. **Kelemahan AI:** AI cenderung menderita bias kecepatan implementasi dan sering mengabaikan batas-batas arsitektur (*architectural boundaries*). Pada Temuan 3, AI menyarankan impor `sqflite` langsung ke dalam domain usecase demi kemudahan caching. Jika saran ini diterima mentah-mentah (*blind approval*), aplikasi akan kehilangan sterilitas domain, menjadi sulit diuji dengan pure Dart unit test, dan terikat permanen pada platform tertentu.
3. **Prinsip Utama:** Kode adalah tanggung jawab software engineer, bukan model bahasa. Setiap saran AI wajib divalidasi melalui 3 filter: **Kebenaran Logika**, **Kepatuhan Dependency Rule**, dan **Kelayakan Otomatisasi (CI)**.

