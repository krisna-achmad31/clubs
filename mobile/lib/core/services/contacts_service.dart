import 'package:flutter_contacts/flutter_contacts.dart' as fc;

/// A phone-book entry with at least one number.
class PhoneContact {
  const PhoneContact(this.name, this.phones);

  final String name;
  final List<String> phones;
}

enum ContactsAccess { granted, denied, blocked }

/// Reads the device phone book (read-only). Behind an interface so tests and
/// previews can supply contacts without the native plugin.
abstract interface class ContactsService {
  /// Asks for permission when needed; [ContactsAccess.blocked] means the user
  /// has to enable it in Settings.
  Future<ContactsAccess> request();
  Future<List<PhoneContact>> all();
  Future<void> openSettings();
}

class DeviceContactsService implements ContactsService {
  @override
  Future<ContactsAccess> request() async {
    final status = await fc.FlutterContacts.permissions.request(
      fc.PermissionType.read,
    );
    return switch (status) {
      fc.PermissionStatus.granted ||
      fc.PermissionStatus.limited => ContactsAccess.granted,
      fc.PermissionStatus.permanentlyDenied ||
      fc.PermissionStatus.restricted => ContactsAccess.blocked,
      _ => ContactsAccess.denied,
    };
  }

  @override
  Future<List<PhoneContact>> all() async {
    final contacts = await fc.FlutterContacts.getAll(
      properties: {fc.ContactProperty.phone},
    );
    return [
      for (final c in contacts)
        if (c.phones.isNotEmpty)
          PhoneContact(
            (c.displayName ?? '').trim().isEmpty
                ? c.phones.first.number
                : c.displayName!.trim(),
            [for (final p in c.phones) p.number],
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> openSettings() => fc.FlutterContacts.permissions.openSettings();
}
