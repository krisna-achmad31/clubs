import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/club/domain/entities/club.dart';
import 'package:klubby/features/club/domain/repositories/club_repository.dart';
import 'package:klubby/features/club/presentation/cubit/club_chat_cubit.dart';

class ChatRepository extends Fake implements ClubRepository {
  final changes = StreamController<void>.broadcast();
  final rows = <ChatMessage>[];
  bool failSend = false;
  bool? announcement;
  @override
  Stream<void> chatChanges(String clubId) => changes.stream;
  @override
  Future<List<ChatMessage>> chat(String clubId) async => [...rows];
  @override
  Future<ChatMessage> send(
    String clubId,
    String text, {
    bool sticker = false,
    bool announcement = false,
    Color? stickerBg,
  }) async {
    if (failSend) throw StateError('offline');
    this.announcement = announcement;
    final message = ChatMessage(
      id: '${rows.length}',
      author: 'Budi',
      emoji: '',
      avatarBg: const Color(0x00000000),
      text: text,
      announcement: announcement,
    );
    rows.add(message);
    return message;
  }
}

void main() {
  test('incoming database events refresh chat without sending, then cancel on close', () async {
    final repo = ChatRepository();
    final cubit = ClubChatCubit(repo, 'club');
    await cubit.load();
    expect(repo.changes.hasListener, isTrue);
    repo.rows.add(
      const ChatMessage(
        id: 'other',
        author: 'Anggota Lain',
        emoji: '',
        avatarBg: Color(0x00000000),
        text: 'Pesan dari perangkat lain',
      ),
    );
    final received = cubit.stream.firstWhere((s) => s.messages.isNotEmpty);
    repo.changes.add(null);
    expect((await received).messages.single.text, 'Pesan dari perangkat lain');
    await cubit.close();
    expect(repo.changes.hasListener, isFalse);
    await repo.changes.close();
  });
  test(
    'failed send retains error and announcement until successful retry',
    () async {
      final repo = ChatRepository()..failSend = true;
      final cubit = ClubChatCubit(repo, 'club');
      await cubit.load();
      cubit.toggleAnnounce(true);
      expect(await cubit.send('Pengumuman'), isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.announce, isTrue);
      repo.failSend = false;
      expect(await cubit.send('Pengumuman'), isTrue);
      expect(repo.announcement, isTrue);
      expect(cubit.state.pinned!.text, 'Pengumuman');
      expect(cubit.state.announce, isFalse);
      await cubit.close();
      await repo.changes.close();
    },
  );
}
