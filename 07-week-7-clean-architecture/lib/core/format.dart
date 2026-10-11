/// Fungsi helper formatting murni Dart (testable tanpa dependency Flutter)
String formatDate(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String formatRelativeDate(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Baru saja';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} menit lalu';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} jam lalu';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} hari lalu';
  } else {
    return formatDate(dateTime);
  }
}

String formatSyncStatus(bool isDirty) {
  return isDirty ? 'Belum tersinkron' : 'Tersinkron';
}
