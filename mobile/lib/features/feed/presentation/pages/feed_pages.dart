import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../activity/presentation/pages/record_sheet.dart';
import '../../../activity/domain/entities/activity_analysis.dart';
import '../../../activity/presentation/widgets/activity_data_sections.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../profile/presentation/pages/profile_pages.dart'
    show ProfileAvatarView;
import '../../../profile/presentation/widgets/me_top_stats.dart';
import '../../domain/entities/feed_post.dart';
import '../cubit/feed_cubit.dart';

/// J1 Feed tab.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  void initState() {
    super.initState();
    context.read<FeedCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedCubit>().state;
    final streak = context.select((MeCubit c) => c.state.streak);
    final last = context.select((MeCubit c) => c.state.lastActive);
    return KPage(
      header: const MeTopStats(),
      children: [
        Row(
          children: [
            Expanded(
              child: KSegmented(
                items: const ['KOMUNITAS', 'PUBLIK'],
                index: feed.publik ? 1 : 0,
                onChanged: (i) => context.read<FeedCubit>().setPublik(i == 1),
              ),
            ),
            const SizedBox(width: 10),
            _Bell(unread: feed.unread),
          ],
        ),
        _StreakBanner(
          streak: streak,
          safeToday: last != null && DateUtils.isSameDay(last, DateTime.now()),
        ),
        for (final p in feed.posts) _PostCard(post: p),
        if (feed.posts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: MascotSays(
              animal: Animal.kiki,
              text: 'Belum ada aktivitas di sini. Yuk jadi yang pertama!',
            ),
          ),
      ],
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(R.notifications),
      depth: 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: chunkyBorder(AppColors.line, bottom: 4),
            ),
            child: Wobble(
              trigger: unread,
              child: const Icon(
                LucideIcons.bell,
                color: AppColors.muted,
                size: 22,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: PopIn(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Text(
                    '$unread',
                    style: AppText.custom(11, c: AppColors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.safeToday});

  final int streak;

  /// Already moved today: nothing left to secure.
  final bool safeToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: lip(AppColors.orangeD, 5),
      ),
      child: Row(
        children: [
          const Pulse(child: Emo('🔥', size: 34, color: AppColors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak hari beruntun!',
                  style: AppText.custom(19, c: AppColors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  safeToday
                      ? 'Streak hari ini aman ✓'
                      : 'Gerak hari ini, amankan hari ke-${streak + 1}!',
                  style: AppText.custom(
                    14,
                    w: FontWeight.w800,
                    c: AppColors.orangeL,
                  ),
                ),
              ],
            ),
          ),
          KMiniButton(
            'REKAM',
            hue: Hue.white,
            textColor: AppColors.orange,
            onTap: () => showRecordSheet(context),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.post, {this.size = 44});

  final FeedPost post;
  final double size;

  @override
  Widget build(BuildContext context) => post.mine
      ? ProfileAvatarView(
          context.watch<MeCubit>().state.avatar,
          size: size,
          ring: false,
        )
      : post.emoji != null
      ? Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: post.color.withValues(alpha: .15),
            shape: BoxShape.circle,
            border: Border.all(
              color: post.color.withValues(alpha: .4),
              width: 2,
            ),
          ),
          child: Emo(post.emoji!, size: size * .5),
        )
      : LetterAvatar(post.initials, color: post.color, size: size);
}

/// Profile sheet for a post's author.
void _openAuthor(BuildContext context, FeedPost post) {
  if (post.mine) {
    context.go(R.profile);
    return;
  }
  showUserSheet(
    context,
    name: post.author,
    subtitle: post.club ?? Sports.byId(post.sportId).name,
    color: post.color,
    sportId: post.sportId,
  );
}

/// Comment avatars only store a light tint; the sheet wants the full colour.
Color _baseOf(Color light) => switch (light) {
  AppColors.purpleL => AppColors.purple,
  AppColors.orangeL => AppColors.orange,
  AppColors.blueL => AppColors.blue,
  AppColors.yellowL => AppColors.yellowD,
  AppColors.redL => AppColors.red,
  _ => AppColors.primary,
};

void _openCommenter(BuildContext context, Comment c) => showUserSheet(
  context,
  name: c.author,
  subtitle: 'Anggota Klubby',
  color: _baseOf(c.avatarBg),
);

Future<void> _sharePost(FeedPost post) => SharePlus.instance.share(
  ShareParams(
    text: '${post.author}: ${post.title}\nhttps://klubby.id/p/${post.id}',
  ),
);

/// Avatar of a comment: mine shows my profile animal, others their emoji.
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar(this.c, {this.size = 36});

  final Comment c;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (c.mine) {
      return ProfileAvatarView(
        context.select((MeCubit m) => m.state.avatar),
        size: size,
        ring: false,
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.avatarBg, shape: BoxShape.circle),
      child: Emo(c.emoji, size: size * .5),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FeedCubit>();
    final c = post.comments.firstOrNull;
    return KCard(
      onTap: () => context.push(R.post(post.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pressable(
                onTap: () => _openAuthor(context, post),
                depth: 0,
                child: _Avatar(post),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pressable(
                      onTap: () => _openAuthor(context, post),
                      depth: 0,
                      child: Text(
                        post.author,
                        style: AppText.name(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      post.meta,
                      style: AppText.bodySm(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () => _showPostMenu(context, post),
                depth: 0,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(LucideIcons.ellipsis, color: AppColors.faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.title, style: AppText.cardTitle()),
          if (post.hasRoute) ...[
            const SizedBox(height: 10),
            FlatMap(
              height: 120,
              animate: false,
              route: post.activity == null
                  ? null
                  : ActivityAnalysis(post.activity!).route,
            ),
          ],
          const SizedBox(height: 12),
          StatRow([
            for (final s in post.stats)
              StatBox(s.label, s.value, color: s.color),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in post.reactions)
                      ReactionPill(
                        key: ValueKey(r.emoji),
                        emoji: r.emoji,
                        count: r.count,
                        color: r.color,
                        active: r.mine,
                        onToggle: (_) => cubit.react(post.id, r.emoji),
                      ),
                    _AddReaction(
                      onPick: (e) => cubit.react(post.id, e),
                      mine: {
                        for (final r in post.reactions)
                          if (r.mine) r.emoji,
                      },
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () => context.push(R.post(post.id)),
                depth: 0,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.messageCircle,
                    color: AppColors.faint,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (c != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _CommentAvatar(c, size: 24),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${c.author}: ',
                            style: AppText.custom(13),
                          ),
                          TextSpan(
                            text: c.text,
                            style: c.sticker
                                ? AppText.custom(
                                    13,
                                    c: c.stickerFg ?? AppColors.orangeD,
                                  )
                                : AppText.custom(14, w: FontWeight.w800),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+😊" pill: opens the picker so friends can add any reaction, not only the
/// ones already on the post.
class _AddReaction extends StatelessWidget {
  const _AddReaction({required this.onPick, required this.mine});

  final ValueChanged<String> onPick;
  final Set<String> mine;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      depth: 2,
      onTap: () => showKSheet<void>(
        context,
        (ctx) => KSheet(
          children: [
            Text('Kasih reaksi', style: AppText.title()),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final (i, e) in Reaction.choices.indexed)
                  StaggerIn(
                    index: i,
                    step: 18,
                    child: Pressable(
                      onTap: () {
                        Navigator.pop(ctx);
                        onPick(e);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Reaction.hueOf(e)
                              .withValues(alpha: mine.contains(e) ? .16 : .07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: mine.contains(e)
                                ? Reaction.hueOf(e).withValues(alpha: .55)
                                : AppColors.line,
                            width: 2,
                          ),
                        ),
                        child: Emo(e, size: 24, color: Reaction.hueOf(e)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: const Icon(
          LucideIcons.smilePlus,
          size: 18,
          color: AppColors.faint,
        ),
      ),
    );
  }
}

/// "•••" menu on a feed card and J2. [onGone] runs after the post is hidden, muted or reported.
Future<void> _showPostMenu(
  BuildContext context,
  FeedPost post, {
  VoidCallback? onGone,
}) {
  final cubit = context.read<FeedCubit>();
  final link = 'https://klubby.id/p/${post.id}';
  final first = post.author.split(' ').first;
  return showKSheet<void>(context, (ctx) {
    void run(VoidCallback action) {
      Navigator.pop(ctx);
      action();
    }

    return KSheet(
      gap: 4,
      children: [
        const SizedBox(height: 6),
        KRow(
          title: 'Bagikan',
          icon: LucideIcons.share2,
          onTap: () => run(() => _sharePost(post)),
        ),
        KRow(
          title: 'Salin tautan',
          icon: LucideIcons.link,
          onTap: () => run(() {
            Clipboard.setData(ClipboardData(text: link));
            toast(context, 'Tautan disalin');
          }),
        ),
        KRow(
          title: 'Sembunyikan post ini',
          icon: LucideIcons.eyeOff,
          onTap: () => run(() {
            cubit.hide(post.id);
            toast(context, 'Post disembunyikan');
            onGone?.call();
          }),
        ),
        KRow(
          title: 'Bisukan $first',
          subtitle: 'Post-nya tidak muncul lagi di feed-mu',
          icon: LucideIcons.volumeX,
          onTap: () => run(() {
            cubit.mute(post.author);
            toast(context, '$first dibisukan');
            onGone?.call();
          }),
        ),
        KRow(
          title: 'Laporkan',
          icon: LucideIcons.flag,
          iconFg: AppColors.red,
          iconBg: AppColors.redL,
          onTap: () =>
              run(() => _showReport(context, cubit, post, onGone: onGone)),
        ),
      ],
    );
  });
}

Future<void> _showReport(
  BuildContext context,
  FeedCubit cubit,
  FeedPost post, {
  VoidCallback? onGone,
}) {
  const reasons = [
    'Spam atau iklan',
    'Data aktivitas palsu',
    'Konten tidak pantas',
    'Pelecehan atau ujaran kebencian',
    'Lainnya',
  ];
  return showKSheet<void>(
    context,
    (ctx) => KSheet(
      gap: 4,
      children: [
        const SizedBox(height: 6),
        Text('Kenapa dilaporkan?', style: AppText.title()),
        const SizedBox(height: 6),
        for (final r in reasons)
          KRow(
            title: r,
            onTap: () {
              Navigator.pop(ctx);
              cubit.report(post.id, r);
              toast(
                context,
                'Laporan dicatat di sesi demo ini. Pengiriman ke moderator belum tersedia.',
              );
              onGone?.call();
            },
          ),
      ],
    ),
  );
}

class _CommentBody extends StatelessWidget {
  const _CommentBody(this.c);

  final Comment c;

  @override
  Widget build(BuildContext context) => c.sticker
      ? Wobble(
          trigger: c.text,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.stickerBg ?? AppColors.yellowL,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (c.stickerFg ?? AppColors.orangeD).withValues(alpha: .3),
                width: 2,
              ),
            ),
            child: Text(
              c.text,
              style: AppText.custom(13, c: c.stickerFg ?? AppColors.orangeD),
            ),
          ),
        )
      : Text(
          c.text,
          style: AppText.custom(14, w: FontWeight.w800),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
}

/// J2 Activity detail.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.id});

  final String id;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _text = TextEditingController();
  late final _initial = context.read<FeedCubit>().post(widget.id);

  static const _stickers = [
    ('😮‍💨 Napas Habis', AppColors.blueL, AppColors.blue),
    ('🔥 Gacor!', AppColors.orangeL, AppColors.orange),
    ('👑 Raja Jalanan', AppColors.purpleL, AppColors.purple),
    ('🧃 Minum dulu', AppColors.yellowL, AppColors.orangeD),
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(FeedCubit cubit, {String? sticker, Color? bg, Color? fg}) {
    final text = sticker ?? _text.text.trim();
    if (text.isEmpty) return;
    final me = context.read<MeCubit>().state;
    cubit.comment(
      widget.id,
      Comment(
        author: me.firstName,
        emoji: '🐥',
        avatarBg: AppColors.yellowL,
        text: text,
        sticker: sticker != null,
        stickerBg: bg,
        stickerFg: fg,
        mine: true,
      ),
    );
    _text.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FeedCubit>();
    final post = context.select(
      (FeedCubit c) =>
          c.state.details[widget.id] ??
          c.state.posts.where((p) => p.id == widget.id).firstOrNull,
    );
    if (post == null) {
      return FutureBuilder(
        future: _initial,
        builder: (context, snap) => snap.hasData
            ? _body(context, cubit, snap.data!)
            : snap.hasError
            ? KPage(
                header: const KHeader('Aktivitas'),
                children: [
                  KBanner.error('Aktivitas tidak ditemukan.'),
                  KButton('KEMBALI KE FEED', onTap: () => context.go(R.feed)),
                ],
              )
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return _body(context, cubit, post);
  }

  Widget _body(BuildContext context, FeedCubit cubit, FeedPost post) {
    final best = post.splits.isEmpty
        ? 0
        : post.splits.reduce((a, b) => a < b ? a : b);
    final worst = post.splits.isEmpty
        ? 1
        : post.splits.reduce((a, b) => a > b ? a : b);
    return KPage(
      header: KHeader(
        'Aktivitas',
        actions: [
          KIconButton(LucideIcons.share2, onTap: () => _sharePost(post)),
          KIconButton(
            LucideIcons.ellipsis,
            onTap: () => _showPostMenu(context, post),
          ),
        ],
      ),
      bottomBorder: true,
      bottom: Row(
        children: [
          KIconButton(
            LucideIcons.smile,
            color: AppColors.orange,
            onTap: () => showKSheet<void>(
              context,
              (ctx) => KSheet(
                children: [
                  Text('Kirim stiker', style: AppText.title()),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (t, bg, fg) in _stickers)
                        Pressable(
                          onTap: () {
                            Navigator.pop(ctx);
                            _send(cubit, sticker: t, bg: bg, fg: fg);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(14),
                              border: chunkyBorder(
                                fg.withValues(alpha: .4),
                                bottom: 4,
                              ),
                            ),
                            child: Text(t, style: AppText.custom(15, c: fg)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: KInput(
              controller: _text,
              hint: 'Tulis komentar…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          KMiniButton(
            'KIRIM',
            hue: Hue.primary,
            onTap: _text.text.trim().isEmpty ? null : () => _send(cubit),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            Pressable(
              onTap: () => _openAuthor(context, post),
              child: _Avatar(post, size: 48),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pressable(
                    onTap: () => _openAuthor(context, post),
                    child: Text(post.author, style: AppText.name()),
                  ),
                  Text(
                    post.title.isEmpty
                        ? post.meta
                        : '${post.title} · ${post.meta}',
                    style: AppText.bodySm(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (post.hasRoute)
          FlatMap(
            route: post.activity == null
                ? null
                : ActivityAnalysis(post.activity!).route,
          ),
        Row(
          children: [
            for (final (i, s) in post.stats.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.value, style: AppText.value()),
                    const SizedBox(height: 2),
                    Text(s.label, style: AppText.micro(AppColors.muted)),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (post.splits.isNotEmpty && post.activity == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('SPLIT PER KM'),
              const SizedBox(height: 8),
              for (final (i, s) in post.splits.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          '${i + 1}',
                          style: AppText.custom(13, c: AppColors.muted),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Align(
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end:
                                    .55 +
                                    .45 * (worst - s + 1) / (worst - best + 1),
                              ),
                              duration:
                                  Motion.slow + Duration(milliseconds: i * 90),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Container(
                                width: c.maxWidth * v,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: s == best
                                      ? AppColors.primary
                                      : AppColors.primaryM,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 48,
                        child: Text(
                          Fmt.pace(Duration(seconds: s), 1),
                          textAlign: TextAlign.right,
                          style: AppText.custom(
                            13,
                            c: s == best ? AppColors.primary : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (post.activity != null)
          ActivityDataSections(activity: post.activity!, owner: post.mine),
        if (post.segment != null)
          KCard(
            color: AppColors.yellowL,
            border: AppColors.yellow,
            onTap: () => context.push(
              '${R.segment}?id=${post.segmentId ?? 'tanjakan-senayan'}',
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.crown, color: AppColors.yellowD),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.segment!,
                    style: AppText.custom(15, c: AppColors.orangeD),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.orangeD),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in post.reactions)
                  ReactionPill(
                    key: ValueKey(r.emoji),
                    emoji: r.emoji,
                    count: r.count,
                    color: r.color,
                    active: r.mine,
                    onToggle: (_) => cubit.react(post.id, r.emoji),
                  ),
                _AddReaction(
                  onPick: (e) => cubit.react(post.id, e),
                  mine: {
                    for (final r in post.reactions)
                      if (r.mine) r.emoji,
                  },
                ),
              ],
            ),
            if (post.reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              KLink(
                '${post.reactions.fold(0, (n, r) => n + r.count)} reaksi · lihat rincian',
                onTap: () => showKSheet<void>(
                  context,
                  (ctx) => KSheet(
                    children: [
                      Text('Reaksi', style: AppText.title()),
                      for (final r in post.reactions)
                        KRow(
                          title:
                              '${r.emoji} · ${r.count} reaksi${r.mine ? ' · termasuk kamu' : ''}',
                        ),
                      Text(
                        'Identitas pemberi reaksi belum tersedia di data demo.',
                        style: AppText.bodySm(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        for (final c in post.comments)
          PopIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  onTap: () => _openCommenter(context, c),
                  child: _CommentAvatar(c),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.soft,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Pressable(
                          onTap: () => _openCommenter(context, c),
                          child: Text(c.author, style: AppText.custom(13)),
                        ),
                        const SizedBox(height: 4),
                        _CommentBody(c),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// J3 Notifikasi.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<FeedCubit>().state.notifications;
    final today = list.where((n) => n.today).toList();
    final older = list.where((n) => !n.today).toList();
    return KPage(
      header: KHeader(
        'Notifikasi',
        actions: [
          Pressable(
            onTap: () => context.read<FeedCubit>().markAllRead(),
            depth: 0,
            child: Text(
              'TANDAI DIBACA',
              style: AppText.custom(13, c: AppColors.primary),
            ),
          ),
        ],
      ),
      gap: 10,
      children: [
        if (list.isEmpty)
          const MascotSays(
            animal: Animal.kiki,
            text: 'Belum ada notifikasi. Ajakan dan kabar klub akan muncul di sini.',
          ),
        if (today.isNotEmpty) const FieldLabel('HARI INI'),
        for (final n in today) _NotifTile(n),
        if (older.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: FieldLabel('KEMARIN'),
          ),
        for (final n in older) _NotifTile(n),
      ],
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile(this.n);

  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final goyang = n.kind == NotifKind.goyang;
    final danger = n.kind == NotifKind.streak;
    final bg = goyang
        ? AppColors.orangeL
        : (danger ? AppColors.orangeL : AppColors.bg);
    final border = goyang
        ? AppColors.orange
        : (danger ? AppColors.orange : AppColors.line);
    return Pressable(
      onTap: () async {
        await context.read<FeedCubit>().markRead(n.id);
        if (!context.mounted) return;
        if ([R.feed, R.clubs, R.league, R.profile].contains(n.route)) {
          context.go(n.route);
        } else {
          context.push(n.route);
        }
      },
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: chunkyBorder(border, bottom: 4),
        ),
        child: Row(
          children: [
            goyang
                ? Wobble(
                    trigger: n.id,
                    child: const IconBox(
                      LucideIcons.vibrate,
                      bg: AppColors.orange,
                      fg: AppColors.white,
                      size: 46,
                    ),
                  )
                : IconBox(
                    LucideIcons.bell,
                    emoji: n.emoji,
                    bg: AppColors.soft,
                    size: 46,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: AppText.custom(15)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: n.body),
                        if (n.action != null)
                          TextSpan(
                            text: ' · ${n.action}',
                            style: AppText.custom(13, c: AppColors.orange),
                          ),
                      ],
                    ),
                    style: AppText.bodySm(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  n.ago,
                  style: AppText.caption(
                    n.ago == 'Baru' ? AppColors.orange : AppColors.faint,
                  ),
                ),
                if (n.unread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
