import 'package:connect_db/database/app_database.dart';
import 'package:connect_db/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores and updates a local message', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.addMessage(
      id: 'message-1',
      content: 'Dữ liệu thử',
      createdAt: DateTime(2026, 10, 6),
    );

    var messages = await database.getAllMessages();
    expect(messages, hasLength(1));
    expect(messages.single.content, 'Dữ liệu thử');
    expect(messages.single.isSynced, isFalse);

    await database.markAsSynced('message-1');
    messages = await database.getAllMessages();
    expect(messages.single.isSynced, isTrue);
  });

  testWidgets('shows a Firebase initialization error', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MyApp(
        initializationError: 'Lỗi cấu hình thử nghiệm',
        database: database,
        messagesStream: const Stream<List<StoredMessage>>.empty(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local + Firebase'), findsOneWidget);
    expect(find.text('Local SQLite: đã kết nối.'), findsOneWidget);
    expect(find.textContaining('Không thể kết nối Firebase'), findsOneWidget);
    expect(find.text('Lưu Local + Firebase'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
    await tester.pump();
  });
}
