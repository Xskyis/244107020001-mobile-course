import 'package:go_router/go_router.dart';

import 'features/chat_screen.dart';
import 'main.dart';
import 'pages/note_detail_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'note/:id',
          builder: (context, state) => NoteDetailPage(
            noteId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: 'ai-chat',
          builder: (context, state) => const AiChatScreen(),
        ),
      ],
    ),
  ],
);
