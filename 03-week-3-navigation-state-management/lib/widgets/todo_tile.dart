import 'package:flutter/material.dart';
import '../providers/todo_provider.dart';

/// Widget mandiri untuk menampilkan satu baris item ToDo.
/// Memiliki arsitektur terisolasi sehingga mudah diuji (unit/widget test)
/// dan membuat method build pada parent widget tetap ringkas.
class TodoTile extends StatelessWidget {
  final Todo todo;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: todo.done
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: todo.done,
          activeColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          onChanged: onToggle,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            decoration: todo.done ? TextDecoration.lineThrough : null,
            color: todo.done
                ? const Color(0xFF94A3B8)
                : const Color(0xFF0F172A),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Hapus tugas',
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          hoverColor: const Color(0xFFFEE2E2),
          highlightColor: const Color(0xFFFEE2E2),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
