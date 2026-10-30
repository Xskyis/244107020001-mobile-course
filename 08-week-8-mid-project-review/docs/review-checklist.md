# Mid-Project Review & Code Review Checklist

Dokumen ini memuat checklist evaluasi arsitektur, simulasi perbaikan pesan commit konvensional, catatan peer code review sejawat, serta audit kesiapan paruh semester (Mid-Project Review) untuk repository mobile-course.

---

## 1. Simulasi Perbaikan Pesan Commit Lama (Hygiene Commit)

Berdasarkan audit riwayat commit (`git log --oneline -15`) pada repository, ditemukan beberapa pesan commit yang belum mengikuti standar [Conventional Commits](https://www.conventionalcommits.org/). Berikut adalah penulisan ulang 3 pesan commit lama menjadi format konvensional `tipe(scope): deskripsi imperatif` beserta alasan perbaikannya:

| No | Commit Hash Asli | Pesan Commit Asli | Pesan Commit Konvensional (Sesudah) | Alasan & Evaluasi Perbaikan |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `1417888` | `Delete Mistaken File` | `chore(repo): remove mistakenly committed temporary files` | Pesan asli tidak memiliki scope, tipe commit tidak baku, dan tidak spesifik mengenai berkas apa yang dihapus. Format baru menjelaskan bahwa ini adalah pemeliharaan repo (`chore`) untuk menghapus file sampah/temporer. |
| 2 | `5f34a7d` | `Jobsheet 5 - Klasterisasi Hierarki` | `docs(week-5): add clustering notes and jobsheet report` | Pesan asli mencampur materi tanpa spesifikasi tindakan (`feat`/`docs`). Penulisan baru menjelaskan scope modul (`week-5`) dan tindakan penambahan laporan dokumentasi jobsheet. |
| 3 | `6939bc1` | `fix notes database migration` | `fix(notes): handle v2 schema migration in SQLite open helper` | Pesan asli terlalu ambigu mengenai bug apa yang diperbaiki dan di mana perbaikannya terjadi. Format baru secara presisi menyebutkan modul `notes`, perbaikan migrasi skema SQLite versi 2, dan dampak teknisnya. |

---

## 2. Peer Code Review Checklist (Praktikum 2)

### Metadata Pull Request
- **PR Title:** `fix(auth): reject invalid email addresses and add tests` (#2)
- **Base Branch:** `develop`
- **Compare Branch:** `fix/1-auth-email-validation`
- **Related Issue:** `Login validation accepts incomplete email addresses` (#1)
- **Author:** Mahasiswa (Author)
- **Reviewer:** Peer Reviewer (Sejawat)
- **Waktu Review:** 15 Menit

### Checklist Temuan Peer Review
Setiap temuan disusun dengan pola **Observasi $\rightarrow$ Dampak $\rightarrow$ Usulan Konkret**:

| Kategori | Lokasi Kode / File | Observasi & Dampak | Usulan Konkret & Rekomendasi | Status Tindak Lanjut |
| :--- | :--- | :--- | :--- | :--- |
| **Kebenaran 1 (Edge Case)** | `lib/features/auth/domain/usecases/login.dart` | *Observasi:* Validasi email hanya memeriksa string mengandung `@` (`email.contains('@')`).<br>*Dampak:* String seperti `"user@"` atau `"@example"` dianggap valid dan dikirim ke API backend, menyebabkan runtime 400 Bad Request tak tertangani. | *Usulan:* Gunakan regular expression standar RFC 5322 sederhana untuk memeriksa format username, domain, dan TLD minimal (misal `^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+`). | **Selesai (Fixed)** |
| **Kebenaran 2 (State / Error Path)** | `lib/features/auth/presentation/providers/auth_provider.dart` | *Observasi:* Saat login gagal akibat `NetworkFailure`, state error disimpan tetapi flag `isLoading` tidak di-reset ke `false` pada blok catch tertentu.<br>*Dampak:* Tombol login di UI tetap berada pada status `CircularProgressIndicator` dan disabled selamanya. | *Usulan:* Pastikan blok `try-catch` atau pattern matching `Failure` selalu menetapkan `state = AsyncError(failure, stackTrace)` sehingga status loading otomatis berakhir. | **Selesai (Fixed)** |
| **Arsitektur (Dependency Rule)** | `lib/features/auth/domain/usecases/login.dart` | *Observasi:* Ditemukan baris `import 'package:flutter/material.dart';` untuk menggunakan utility `TextEditingController` di dalam file domain Use Case.<br>*Dampak:* Layer Domain tercemar oleh dependensi UI framework Flutter, melanggar *The Dependency Rule* Clean Architecture dan menyulitkan pure Dart unit testing. | *Usulan:* Hapus import `flutter/material.dart`. Use Case hanya boleh menerima tipe data primitif Dart murni (`String email`, `String password`) atau Value Object. | **Selesai (Fixed)** |
| **Test (Test Coverage)** | `test/login_test.dart` | *Observasi:* Unit test baru hanya mencakup skenario email kosong dan email tanpa simbol `@`. Tidak ada test case untuk menguji kegagalan otentikasi dari server (`AuthFailure`).<br>*Dampak:* Regresi pada penanganan credential salah tidak dapat dideteksi secara otomatis oleh CI. | *Usulan:* Tambahkan minimal 2 unit test baru di `login_test.dart`: satu untuk penolakan format email tanpa domain (`user@`), dan satu untuk memverifikasi propagasi `AuthFailure(401)` dari mock repository. | **Selesai (Fixed)** |
| **Keterbacaan (Clean Code)** | `lib/features/auth/presentation/pages/login_page.dart` | *Observasi:* Terdapat method `build()` sepanjang 85 baris dengan ternary operator bertingkat untuk menampilkan badge error dan form.<br>*Dampak:* Keterbacaan UI menurun dan sulit dipelihara. | *Usulan:* Ekstrak widget form input dan banner notifikasi error ke dalam private helper widget atau file terpisah (`_LoginFormWidget`). | **Selesai (Fixed)** |

### Keputusan Review:
1. **Putaran 1:** ❌ **Request Changes** (Meminta perbaikan regex email, pelepasan import Flutter dari domain, dan penambahan 2 unit test).
2. **Putaran 2 (Re-review):**  **Approved** (Seluruh 5 catatan telah diperbaiki, analyze bersih, dan 14 test lulus).

---

## 3. Evaluasi Kesiapan Tengah Semester (Mid-Project Readiness Checklist)

Checklist ini menilai kesiapan fondasi arsitektur dan engineering hygiene proyek sebelum melangkah ke paruh semester kedua:

| Aspek Penilaian | Kriteria & Indikator | Bukti Nyata & Hasil Audit | Status |
| :--- | :--- | :--- | :---: |
| **Struktur Feature-First** | Pembagian folder berdasarkan modul bisnis (`features/notes`, `features/settings`, `features/auth`), bukan layer-first global. | Struktur direktori `lib/features/notes/` memuat `data/`, `domain/`, dan `presentation/` secara mandiri. |  **Lulus** |
| **Sterilitas Layer Domain** | Layer domain murni Dart tanpa import `package:flutter`, `package:sqflite`, atau layer presentation. | Hasil 3 perintah grep sterilitas menghasilkan **0 pelanggaran**:<br>- Grep `package:flutter` di domain: `0 match`<br>- Grep `package:sqflite` di domain: `0 match`<br>- Grep `presentation` di domain: `0 match` |  **Lulus** |
| **Static Analysis** | `flutter analyze` tidak menghasilkan error, warning, maupun info linter. | Output: `Analyzing 07-week-7-clean-architecture... No issues found! (ran in 3.4s)`. |  **Lulus** |
| **Code Formatting** | `dart format` konsisten di seluruh codebase tanpa whitespace tak perlu. | `dart format --output=none --set-exit-if-changed lib test` menghasilkan return code 0 (20 files checked, 0 changed). |  **Lulus** |
| **Test Suite Hijau** | Seluruh unit test lulus menguji use case, core helper, dan repository mock. | `flutter test` berhasil menjalankan seluruh 9 unit test dengan status **All tests passed!**. |  **Lulus** |
| **Hygiene Git & Branching** | Cabang kerja pendek (< 3 hari), branching model `develop` dan `feature/*` / `fix/*`, commit konvensional. | Riwayat commit tertata rapi, PR terdefinisi, branch dilindungi dan di-merge melalui Pull Request. |  **Lulus** |
| **Otomatisasi CI** | Terdapat pipeline CI (`.github/workflows/ci.yml`) yang memvalidasi analyze, format, dan test pada setiap PR. | Berkas `.github/workflows/ci.yml` aktif memeriksa pull request sebelum merge ke branch `develop`. |  **Lulus** |
| **Dokumentasi & Reproducibility** | README lengkap memuat petunjuk instalasi, diagram arsitektur, bukti verifikasi, dan screenshot aplikasi. | Berkas `README.md` pada setiap modul minggu terisi lengkap dengan visual dan langkah eksekusi. |  **Lulus** |

