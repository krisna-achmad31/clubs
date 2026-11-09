/// The Klubby account this phone is signed in to.
///
/// Login is not built yet, so every install uses this hardcoded test account
/// (the seeded demo profile). The watch app links to whichever account the
/// phone reports, and the phone ignores watch workouts made for another one.
// TODO(auth): replace with the signed-in user once login exists.
abstract final class TestAccount {
  static const id = 'budismash';
  static const name = 'Budi Santoso';
}
