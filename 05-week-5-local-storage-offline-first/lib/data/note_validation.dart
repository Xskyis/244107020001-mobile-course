/// Validasi judul catatan: harus memiliki teks non-spasi dan panjang maksimal 120 karakter.
bool isValidNoteTitle(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty && trimmed.length <= 120;
}

/// Normalisasi judul catatan dengan menghapus spasi berlebih di awal/akhir.
String normalizeNoteTitle(String value) => value.trim();
