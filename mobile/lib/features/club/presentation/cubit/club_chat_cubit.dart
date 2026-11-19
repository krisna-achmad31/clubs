import 'dart:async';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';

class ClubChatState extends Equatable {
  const ClubChatState({
    this.messages = const [],
    this.announce = false,
    this.error,
    this.sending = false,
  });

  final List<ChatMessage> messages;
  final bool announce;
  final String? error;
  final bool sending;

  ChatMessage? get pinned => messages.where((m) => m.announcement).lastOrNull;
  List<ChatMessage> get thread =>
      messages.where((m) => !m.announcement || m.mine).toList();

  @override
  List<Object?> get props => [messages, announce, error, sending];
}

class ClubChatCubit extends Cubit<ClubChatState> {
  ClubChatCubit(this._repo, this.clubId) : super(const ClubChatState());

  final ClubRepository _repo;
  final String clubId;
  StreamSubscription<void>? _subscription;
  bool _loading = false;
  bool _reload = false;

  Future<void> load() async {
    await _subscription?.cancel();
    if (isClosed) return;
    _subscription = _repo
        .chatChanges(clubId)
        .listen(
          (_) => unawaited(_fetch()),
          onError: (Object error) {
            if (!isClosed) {
              emit(
                ClubChatState(
                  messages: state.messages,
                  announce: state.announce,
                  sending: state.sending,
                  error: 'Chat terputus. Menghubungkan ulang.',
                ),
              );
            }
          },
        );
    await _fetch();
  }

  Future<void> _fetch() async {
    if (isClosed) return;
    if (_loading) {
      _reload = true;
      return;
    }
    _loading = true;
    do {
      _reload = false;
      try {
        final messages = await _repo.chat(clubId);
        if (!isClosed) {
          emit(
            ClubChatState(
              messages: List.of(messages),
              announce: state.announce,
              sending: state.sending,
            ),
          );
        }
      } catch (_) {
        if (!isClosed) {
          emit(
            ClubChatState(
              messages: state.messages,
              announce: state.announce,
              sending: state.sending,
              error: 'Pesan belum bisa dimuat. Coba lagi.',
            ),
          );
        }
      }
    } while (_reload && !isClosed);
    _loading = false;
  }

  void toggleAnnounce(bool v) => emit(
    ClubChatState(
      messages: state.messages,
      announce: v,
      error: state.error,
      sending: state.sending,
    ),
  );

  Future<bool> send(
    String text, {
    bool sticker = false,
    Color? stickerBg,
  }) async {
    if (text.trim().isEmpty || state.sending) return false;
    final announce = state.announce;
    emit(
      ClubChatState(
        messages: state.messages,
        announce: announce,
        sending: true,
      ),
    );
    try {
      await _repo.send(
        clubId,
        text.trim(),
        sticker: sticker,
        announcement: announce,
        stickerBg: stickerBg,
      );
      // One announcement per toggle: the next message is a normal one again.
      if (isClosed) return true;
      emit(ClubChatState(messages: state.messages));
      await _fetch();
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(
          ClubChatState(
            messages: state.messages,
            announce: announce,
            error: 'Pesan belum terkirim. Coba lagi.',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
