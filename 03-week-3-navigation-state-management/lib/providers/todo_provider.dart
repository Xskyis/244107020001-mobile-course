import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model data ToDo immutable
class Todo {
  Todo(this.title, {this.done = false, String? id})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String title;
  final bool done;

  Todo copyWith({String? id, String? title, bool? done}) =>
      Todo(title ?? this.title, done: done ?? this.done, id: id ?? this.id);
}

/// Notifier untuk mengelola daftar utama ToDo
class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() => const [];

  void add(String title) => state = [...state, Todo(title)];

  void toggle(String id) {
    state = [
      for (final todo in state)
        if (todo.id == id) todo.copyWith(done: !todo.done) else todo,
    ];
  }

  void remove(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }

  void toggleByIndex(int index) {
    if (index >= 0 && index < state.length) {
      final todos = [...state];
      todos[index] = todos[index].copyWith(done: !todos[index].done);
      state = todos;
    }
  }

  void removeByIndex(int index) {
    if (index >= 0 && index < state.length) {
      state = [...state]..removeAt(index);
    }
  }
}

/// Provider daftar utama ToDo
final todoListProvider =
    NotifierProvider<TodoListNotifier, List<Todo>>(TodoListNotifier.new);

/// Enum kriteria filter ToDo
enum TodoFilter {
  all,
  active,
  completed,
}

/// Notifier pengelola status filter saat ini
class TodoFilterNotifier extends Notifier<TodoFilter> {
  @override
  TodoFilter build() => TodoFilter.all;

  void setFilter(TodoFilter filter) => state = filter;
}

/// Provider status filter aktif
final todoFilterProvider =
    NotifierProvider<TodoFilterNotifier, TodoFilter>(TodoFilterNotifier.new);

/// Provider turunan yang membaca todoListProvider dan todoFilterProvider.
/// Mengembalikan list yang telah disaring secara otomatis tanpa mengubah state asli.
final filteredTodoListProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todoListProvider);
  final filter = ref.watch(todoFilterProvider);

  switch (filter) {
    case TodoFilter.active:
      return todos.where((todo) => !todo.done).toList();
    case TodoFilter.completed:
      return todos.where((todo) => todo.done).toList();
    case TodoFilter.all:
      return todos;
  }
});