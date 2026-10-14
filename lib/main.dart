import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initializationError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    initializationError = error;
  }

  runApp(MyApp(initializationError: initializationError));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initializationError,
    this.database,
    this.messagesStream,
  });

  final Object? initializationError;
  final AppDatabase? database;
  final Stream<List<StoredMessage>>? messagesStream;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local và Firebase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: DatabasePage(
        initializationError: initializationError,
        database: database,
        messagesStream: messagesStream,
      ),
    );
  }
}

class DatabasePage extends StatefulWidget {
  const DatabasePage({
    super.key,
    this.initializationError,
    this.database,
    this.messagesStream,
  });

  final Object? initializationError;
  final AppDatabase? database;
  final Stream<List<StoredMessage>>? messagesStream;

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final _contentController = TextEditingController();
  final _uuid = const Uuid();

  late final AppDatabase _database;
  late final bool _ownsDatabase;
  late final Stream<List<StoredMessage>> _messagesStream;

  bool _isBusy = false;
  bool _isLocalReady = false;
  bool _isFirebaseReady = false;
  String _localStatus = 'Đang kiểm tra database local...';
  String _firebaseStatus = 'Đang kiểm tra Firebase...';
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _messagesStream = widget.messagesStream ?? _database.watchMessages();

    Future<void>.microtask(_checkAllConnections);
  }

  @override
  void dispose() {
    _contentController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _checkAllConnections() async {
    if (mounted) {
      setState(() {
        _isBusy = true;
      });
    }

    await Future.wait([_checkLocalConnection(), _checkFirebaseConnection()]);

    if (mounted) {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _checkLocalConnection() async {
    try {
      await _database.getAllMessages();
      if (!mounted) return;
      setState(() {
        _isLocalReady = true;
        _localStatus = 'Local SQLite: đã kết nối.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLocalReady = false;
        _localStatus = 'Lỗi Local SQLite: $error';
      });
    }
  }

  Future<void> _checkFirebaseConnection() async {
    if (widget.initializationError != null) {
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _firebaseStatus = _firebaseError(widget.initializationError!);
      });
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('connection_tests')
          .doc('flutter_app')
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;
      setState(() {
        _isFirebaseReady = true;
        _firebaseStatus = 'Cloud Firestore: đã kết nối.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _firebaseStatus = _firebaseError(error);
      });
    }
  }

  Future<void> _saveMessage() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _inputError = 'Hãy nhập nội dung.';
      });
      return;
    }

    if (!_isLocalReady) {
      setState(() {
        _localStatus = 'Database local chưa sẵn sàng. Hãy kiểm tra lại.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _inputError = null;
    });

    final id = _uuid.v4();
    final createdAt = DateTime.now();

    try {
      await _database.addMessage(
        id: id,
        content: content,
        createdAt: createdAt,
      );

      if (!mounted) return;
      _contentController.clear();
      setState(() {
        _localStatus = 'Local SQLite: lưu thành công.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localStatus = 'Lỗi khi lưu Local SQLite: $error';
        _isBusy = false;
      });
      return;
    }

    if (widget.initializationError != null) {
      if (!mounted) return;
      setState(() {
        _firebaseStatus = _firebaseError(widget.initializationError!);
        _isBusy = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('messages').doc(id).set({
        'id': id,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
      });
      await _database.markAsSynced(id);

      if (!mounted) return;
      setState(() {
        _isFirebaseReady = true;
        _firebaseStatus = 'Cloud Firestore: đồng bộ thành công.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _firebaseStatus = '${_firebaseError(error)} Dữ liệu vẫn còn ở local.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _firebaseError(Object error) {
    if (error is FirebaseException) {
      final detail = error.message ?? 'Không có mô tả lỗi.';
      return 'Lỗi Firebase (${error.code}): $detail';
    }
    return 'Không thể kết nối Firebase: $error';
  }

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.hour)}:${twoDigits(date.minute)} '
        '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  Widget _statusRow({
    required IconData icon,
    required String text,
    required bool isReady,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isReady ? colors.primary : colors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local + Firebase')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusRow(
                    icon: Icons.storage,
                    text: _localStatus,
                    isReady: _isLocalReady,
                  ),
                  const SizedBox(height: 12),
                  _statusRow(
                    icon: Icons.cloud,
                    text: _firebaseStatus,
                    isReady: _isFirebaseReady,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _contentController,
                    enabled: !_isBusy,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Nội dung',
                      errorText: _inputError,
                    ),
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) {
                      if (_inputError != null) {
                        setState(() {
                          _inputError = null;
                        });
                      }
                    },
                    onSubmitted: (_) {
                      if (!_isBusy) {
                        _saveMessage();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isBusy ? null : _saveMessage,
                    child: Text(
                      _isBusy ? 'Đang xử lý...' : 'Lưu Local + Firebase',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isBusy ? null : _checkAllConnections,
                    child: const Text('Kiểm tra lại kết nối'),
                  ),
                  if (_isBusy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Dữ liệu đã lưu ở local',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<StoredMessage>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Không đọc được dữ liệu local: ${snapshot.error}',
                        );
                      }

                      final messages = snapshot.data ?? const <StoredMessage>[];
                      if (messages.isEmpty) {
                        return const Text('Chưa có dữ liệu.');
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(message.content),
                            subtitle: Text(
                              '${_formatDate(message.createdAt)} · '
                              '${message.isSynced ? 'Đã đồng bộ Firebase' : 'Chỉ có ở local'}',
                            ),
                            trailing: Icon(
                              message.isSynced
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              semanticLabel: message.isSynced
                                  ? 'Đã đồng bộ Firebase'
                                  : 'Chỉ có ở local',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
