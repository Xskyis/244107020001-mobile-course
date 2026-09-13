import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_tile.dart';

/// Halaman utama daftar ToDo yang menggunakan [filteredTodoListProvider]
/// dan widget terpisah [TodoTile].
class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Membaca list yang telah disaring dari provider turunan
    final filteredTodos = ref.watch(filteredTodoListProvider);
    // Membaca status filter saat ini
    final currentFilter = ref.watch(todoFilterProvider);
    // Membaca keseluruhan list untuk mengetahui apakah benar-benar belum ada data
    final allTodos = ref.watch(todoListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'ToDo Riverpod',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filter Chips Minimalis
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Semua',
                  filter: TodoFilter.all,
                  isSelected: currentFilter == TodoFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Belum Selesai',
                  filter: TodoFilter.active,
                  isSelected: currentFilter == TodoFilter.active,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: 'Selesai',
                  filter: TodoFilter.completed,
                  isSelected: currentFilter == TodoFilter.completed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Daftar Item ToDo
          Expanded(
            child: allTodos.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada tugas',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                : filteredTodos.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada tugas pada filter ini',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 4),
                        itemCount: filteredTodos.length,
                        itemBuilder: (context, index) {
                          final todo = filteredTodos[index];
                          return TodoTile(
                            key: ValueKey(todo.id),
                            todo: todo,
                            onToggle: (_) => ref
                                .read(todoListProvider.notifier)
                                .toggle(todo.id),
                            onDelete: () => ref
                                .read(todoListProvider.notifier)
                                .remove(todo.id),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required TodoFilter filter,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      showCheckmark: false,
      onSelected: (_) => ref.read(todoFilterProvider.notifier).setFilter(filter),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tugas baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tuliskan tugas yang perlu dikerjakan...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                ref.read(todoListProvider.notifier).add(text);
              }
              controller.clear();
              Navigator.pop(context);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}