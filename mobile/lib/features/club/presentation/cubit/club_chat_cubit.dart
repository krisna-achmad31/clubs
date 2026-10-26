import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';

class ClubChatState extends Equatable {
  const ClubChatState({this.messages = const [], this.announce = false});

  final List<ChatMessage> messages;
  final bool announce;

  ChatMessage? get pinned => messages.where((m) => m.announcement).lastOrNull;
  List<ChatMessage> get thread =>
      messages.where((m) => !m.announcement || m.mine).toList();

  @override
  List<Object?> get props => [messages, announce];
}

class ClubChatCubit extends Cubit<ClubChatState> {
  ClubChatCubit(this._repo, this.clubId) : super(const ClubChatState());

  final ClubRepository _repo;
  final String clubId;

  Future<void> load() async => emit(
    ClubChatState(
      messages: List.of(await _repo.chat(clubId)),
      announce: state.announce,
    ),
  );

  void toggleAnnounce(bool v) =>
      emit(ClubChatState(messages: state.messages, announce: v));

  Future<void> send(
    String text, {
    bool sticker = false,
    Color? stickerBg,
  }) async {
    if (text.trim().isEmpty) return;
    await _repo.send(
      clubId,
      text.trim(),
      sticker: sticker,
      announcement: state.announce,
      stickerBg: stickerBg,
    );
    // One announcement per toggle: the next message is a normal one again.
    emit(ClubChatState(messages: List.of(await _repo.chat(clubId))));
  }
}
