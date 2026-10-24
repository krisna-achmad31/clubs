import '../../../core/theme/app_colors.dart';
import '../domain/entities/mabar_session.dart';
import '../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final Map<String, MabarSession> _byId = {for (final s in _seed) s.id: s};

  static const _people = [
    Participant(name: 'Budi (Host)', initials: 'B', color: AppColors.primary, host: true, present: true),
    Participant(name: 'Sisca', initials: 'S', color: AppColors.purple, via: 'APP', present: true),
    Participant(name: 'Andi', initials: 'A', color: AppColors.orange, guestOf: 'Sisca', via: 'WEB', present: true),
    Participant(name: 'Raka', initials: 'R', color: AppColors.blue, status: PayStatus.menunggu, waitingLabel: '08:12', present: true),
    Participant(name: 'Dinda', initials: 'D', color: AppColors.red, status: PayStatus.belumBayar, present: true),
    Participant(name: 'Eko', initials: 'E', color: AppColors.yellowD, present: true),
    Participant(name: 'Fajar', initials: 'F', color: AppColors.blue, present: true),
    Participant(name: 'Gita', initials: 'G', color: AppColors.purple, present: true),
    Participant(name: 'Hana', initials: 'H', color: AppColors.orange),
    Participant(name: 'Indra', initials: 'I', color: AppColors.primary),
    Participant(name: 'Joko', initials: 'J', color: AppColors.red),
    Participant(name: 'Kevin', initials: 'K', color: AppColors.yellowD),
  ];

  static const _seed = [
    MabarSession(
      id: 'rabu-malam',
      title: 'Mabar Rabu Malam',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'RAB',
      date: '29',
      month: 'OKT',
      start: '19.00',
      end: '22.00',
      venue: 'GOR Mahakam',
      court: 'Lap 2',
      fee: 35000,
      slots: 12,
      filled: 12,
      waiting: 3,
      kind: 'ANTRE',
      recurring: true,
      participants: _people,
      waitlist: ['Rani', 'Joko', 'Mira'],
    ),
    MabarSession(
      id: 'sabtu-pagi',
      title: 'Mabar Sabtu Pagi',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'SAB',
      date: '1',
      month: 'NOV',
      start: '07.00',
      end: '10.00',
      venue: 'GOR Bulungan',
      court: 'Lap 1',
      fee: 30000,
      slots: 16,
      filled: 4,
      cancelDeadline: 'Jumat 31 Okt, 07.00',
    ),
    MabarSession(
      id: 'americano',
      title: 'Americano Bulanan',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'MIN',
      date: '9',
      month: 'NOV',
      start: '15.00',
      end: '19.00',
      venue: 'GOR Mahakam',
      fee: 50000,
      slots: 16,
      filled: 8,
      kind: 'DAFTAR',
      cancelDeadline: 'Sabtu 8 Nov, 15.00',
    ),
    MabarSession(
      id: 'padel-pagi',
      title: 'Padel Pagi',
      clubId: 'padelpagi',
      clubName: 'Padel Pagi Senopati',
      sportId: 'padel',
      day: 'SAB',
      date: '1',
      month: 'NOV',
      start: '07.00',
      end: '09.00',
      venue: 'Senopati Padel',
      fee: 75000,
      slots: 8,
      filled: 8,
      waiting: 4,
      kind: 'ANTRE',
    ),
  ];

  @override
  Future<List<MabarSession>> all() async => _byId.values.toList();

  @override
  Future<List<MabarSession>> forClub(String clubId) async => _byId.values.where((s) => s.clubId == clubId).toList();

  @override
  Future<MabarSession> byId(String id) async => _byId[id] ?? _byId.values.first;

  @override
  Future<MabarSession> create(SessionDraft d) async {
    final id = d.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final s = MabarSession(
      id: _byId.containsKey(id) ? '$id-${_byId.length}' : id,
      title: d.title,
      clubId: d.clubId,
      clubName: 'PB Smash Ceria',
      sportId: d.sportId,
      day: 'RAB',
      date: '29',
      month: 'OKT',
      start: '19.00',
      end: '22.00',
      venue: d.venue.split(',').first,
      court: d.venue.contains(',') ? d.venue.split(',').last.trim() : '',
      fee: d.fee,
      slots: d.slots,
      filled: 0,
      recurring: d.recurring,
      qris: d.qris,
      autoWaitlist: d.autoWaitlist,
      cancelDeadline: 'Selasa 28 Okt, 19.00',
    );
    _byId[s.id] = s;
    return s;
  }

  @override
  Future<void> update(MabarSession session) async => _byId[session.id] = session;
}
