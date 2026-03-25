import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/contact_insert_service.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Screen (or bottom sheet) for editing an existing contact or creating a new one.
class EditContactScreen extends StatefulWidget {
  /// Pass an existing contact to edit, or null to create a new contact.
  final Contact? contact;

  const EditContactScreen({super.key, this.contact});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late Contact _contact;
  bool _isLoading = true;
  bool _isSaving = false;
  bool get _isNew => widget.contact == null;
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();

  // Name controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _suffixCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  // Notes controller
  final _notesCtrl = TextEditingController();

  // Dynamic lists of controllers for phones / emails / addresses
  final List<_PhoneEntry> _phones = [];
  final List<_EmailEntry> _emails = [];
  final List<_AddressEntry> _addresses = [];

  // Events
  final List<_EventEntry> _events = [];

  // Groups
  List<String> _availableGroups = const [];
  final Set<String> _selectedGroups = {};

  // Organization tags
  List<String> _availableOrganizationTags = const [];
  final Set<String> _selectedOrganizationTags = {};

  final _formKey = GlobalKey<FormState>();
  bool _showMoreNameFields = false;
  bool _photoRemoved = false;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    await _prefsService.init();
    if (!mounted) return;

    if (_isNew) {
      _contact = Contact();
      _contact.propertiesFetched = true;
      _contact.photoFetched = true;
      final insertAccount = await _resolvePreferredInsertAccount();
      if (insertAccount != null) {
        // Some devices reject null/local insert accounts when cloud sync is
        // the default. Explicitly selecting a synced account avoids crashes.
        _contact.accounts = [insertAccount];
      }
      if (!mounted) return;
      _phones.add(_PhoneEntry());
      _emails.add(_EmailEntry());
      _availableGroups = _prefsService.getAvailableContactGroups();
      _availableOrganizationTags = await _buildOrganizationTagCatalog();
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    // Fetch full contact with properties, photo, and accounts (needed for update on Android)
    final full = await FlutterContacts.getContact(
      widget.contact!.id,
      withProperties: true,
      withPhoto: true,
      withThumbnail: true,
      withAccounts: true,
      withGroups: true,
    );

    if (full == null) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact not found')));
      }
      return;
    }

    _contact = full;
    _populateFields();
    _availableGroups = _prefsService.getAvailableContactGroups();
    _selectedGroups
      ..clear()
      ..addAll(_prefsService.getContactGroups(_contact.id));
    _selectedOrganizationTags
      ..clear()
      ..addAll(
        _contact.organizations
            .map((o) => o.company.trim())
            .where((c) => c.isNotEmpty),
      );
    _availableOrganizationTags = await _buildOrganizationTagCatalog(
      include: _selectedOrganizationTags,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<Account?> _resolvePreferredInsertAccount() async {
    final contacts = await FlutterContacts.getContacts(
      withAccounts: true,
      sorted: false,
    );

    final candidates = <Account>[];
    for (final c in contacts) {
      for (final account in c.accounts) {
        final type = account.type.trim();
        final name = account.name.trim();
        if (type.isEmpty || name.isEmpty) continue;
        candidates.add(account);
      }
    }

    if (candidates.isEmpty) return null;

    bool isLikelyLocalOrSim(Account account) {
      final type = account.type.toLowerCase();
      final name = account.name.toLowerCase();
      return type.contains('local') ||
          type.contains('sim') ||
          name.contains('local') ||
          name.contains('sim');
    }

    final preferred = candidates.firstWhere(
      (a) => !isLikelyLocalOrSim(a),
      orElse: () => candidates.first,
    );

    return Account('', preferred.type, preferred.name, const <String>[]);
  }

  Future<List<String>> _buildOrganizationTagCatalog({
    Iterable<String> include = const [],
  }) async {
    final merged = <String>[];

    void addTag(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final exists = merged.any((t) => t.toLowerCase() == trimmed.toLowerCase());
      if (!exists) merged.add(trimmed);
    }

    for (final tag in _prefsService.getAvailableOrganizationTags()) {
      addTag(tag);
    }

    await _repo.ensureLoaded();
    for (final contact in _repo.contacts) {
      for (final org in contact.organizations) {
        addTag(org.company);
      }
    }

    for (final tag in include) {
      addTag(tag);
    }

    for (final tag in merged) {
      await _prefsService.addAvailableOrganizationTag(tag);
    }

    return merged;
  }

  void _populateFields() {
    // Name
    _firstNameCtrl.text = _contact.name.first;
    _lastNameCtrl.text = _contact.name.last;
    _middleNameCtrl.text = _contact.name.middle;
    _prefixCtrl.text = _contact.name.prefix;
    _suffixCtrl.text = _contact.name.suffix;
    _nicknameCtrl.text = _contact.name.nickname;

    _showMoreNameFields =
        _contact.name.middle.isNotEmpty ||
        _contact.name.prefix.isNotEmpty ||
        _contact.name.suffix.isNotEmpty ||
        _contact.name.nickname.isNotEmpty;

    // Phones
    for (final p in _contact.phones) {
      _phones.add(
        _PhoneEntry(
          controller: TextEditingController(text: p.number),
          label: p.label,
          customLabel: p.customLabel,
        ),
      );
    }
    if (_phones.isEmpty) _phones.add(_PhoneEntry());

    // Emails
    for (final e in _contact.emails) {
      _emails.add(
        _EmailEntry(
          controller: TextEditingController(text: e.address),
          label: e.label,
          customLabel: e.customLabel,
        ),
      );
    }
    if (_emails.isEmpty) _emails.add(_EmailEntry());

    // Addresses
    for (final a in _contact.addresses) {
      _addresses.add(
        _AddressEntry(
          controller: TextEditingController(text: a.address),
          label: a.label,
        ),
      );
    }

    // Notes
    if (_contact.notes.isNotEmpty) {
      _notesCtrl.text = _contact.notes.first.note;
    }

    // Events
    for (final ev in _contact.events) {
      _events.add(
        _EventEntry(
          year: ev.year,
          month: ev.month,
          day: ev.day,
          label: ev.label,
        ),
      );
    }
  }

  void _collectFields() {
    // Photo removal — apply only at save time so discard leaves original intact
    if (_photoRemoved) {
      _contact.photo = null;
      _contact.thumbnail = null;
      _contact.photoFetched = true;
      _contact.thumbnailFetched = true;
    }

    // Name
    _contact.name = Name(
      first: _firstNameCtrl.text.trim(),
      last: _lastNameCtrl.text.trim(),
      middle: _middleNameCtrl.text.trim(),
      prefix: _prefixCtrl.text.trim(),
      suffix: _suffixCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
    );

    // Phones
    _contact.phones = _phones
        .where((p) => p.controller.text.trim().isNotEmpty)
        .map(
          (p) => Phone(
            p.controller.text.trim(),
            label: p.label,
            customLabel: p.customLabel,
          ),
        )
        .toList();

    // Emails
    _contact.emails = _emails
        .where((e) => e.controller.text.trim().isNotEmpty)
        .map(
          (e) => Email(
            e.controller.text.trim(),
            label: e.label,
            customLabel: e.customLabel,
          ),
        )
        .toList();

    // Addresses
    _contact.addresses = _addresses
        .where((a) => a.controller.text.trim().isNotEmpty)
        .map((a) => Address(a.controller.text.trim(), label: a.label))
        .toList();

    // Organization tags
    _contact.organizations = _selectedOrganizationTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => Organization(company: tag))
        .toList();

    // Notes
    if (_notesCtrl.text.trim().isNotEmpty) {
      _contact.notes = [Note(_notesCtrl.text.trim())];
    } else {
      _contact.notes = [];
    }

    // Events
    _contact.events = _events
        .map(
          (e) =>
              Event(year: e.year, month: e.month, day: e.day, label: e.label),
        )
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_firstNameCtrl.text.trim().isEmpty &&
        _lastNameCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least a first or last name'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    _collectFields();

    try {
      Contact saved;
      if (_isNew) {
        saved = await ContactInsertService.insertContactSafely(_contact);
      } else {
        saved = await FlutterContacts.updateContact(_contact);
      }

      // Check mounted after first async operation
      if (!mounted) return;

      // Persist app-level group assignment for this contact.
      await _prefsService.setContactGroups(saved.id, _selectedGroups.toList());

      // Check mounted again
      if (!mounted) return;

      // Refresh the shared repository so all screens see changes
      await ContactsRepository().refresh();

      if (!mounted) return;
      // Capture Navigator before the next async gap so the context
      // reference stays valid even if something queues a rebuild.
      final nav = Navigator.of(context);
      final updated = await FlutterContacts.getContact(
        saved.id,
        withProperties: true,
        withThumbnail: true,
        withPhoto: false,
      );
      // Fall back to the saved contact if the re-fetch returns null
      // (can happen on some devices during sync delay).
      nav.pop(updated ?? saved);
    } catch (e) {
      // Guard setState — widget may have been disposed if the user
      // dismissed the screen while the platform call was in-flight.
      if (!mounted) return;
      setState(() => _isSaving = false);
      
      // Ensure context is still valid before showing snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _deleteContact() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${_contact.displayName}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MyContactsColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await FlutterContacts.deleteContact(_contact);
      
      // Check mounted after first async operation
      if (!mounted) return;
      
      await ContactsRepository().refresh();
      
      // Check mounted and capture Navigator before the pop
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      // Guard setState — widget may have been disposed
      if (!mounted) return;
      setState(() => _isSaving = false);
      
      // Double-check mounted before showing snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _prefixCtrl.dispose();
    _suffixCtrl.dispose();
    _nicknameCtrl.dispose();
    _notesCtrl.dispose();
    for (final p in _phones) {
      p.controller.dispose();
    }
    for (final e in _emails) {
      e.controller.dispose();
    }
    for (final a in _addresses) {
      a.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Contact' : 'Edit Contact'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          // Disable close while a save is in-flight to prevent a
          // dispose-during-save race that causes setState-after-dispose.
          onPressed: _isSaving ? null : _confirmDiscard,
        ),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Saving…' : 'Save'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _buildAvatarSection(colorScheme),
                  _buildNameSection(theme),
                  _buildPhoneSection(theme),
                  _buildEmailSection(theme),
                  _buildOrganizationSection(theme),
                  _buildGroupsSection(theme),
                  _buildAddressSection(theme),
                  _buildEventsSection(theme),
                  _buildNotesSection(theme),
                  _buildAccountsSection(theme),
                  if (!_isNew) _buildDeleteSection(theme),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Any unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  // ──────────────────────── Avatar ────────────────────────

  Uint8List? get _activePhotoBytes {
    if (_photoRemoved) return null;
    final photo = _contact.photo;
    if (photo != null && photo.isNotEmpty) return photo;
    final thumbnail = _contact.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;
    return null;
  }

  Future<void> _showPhotoActions() async {
    final hasPhoto = _activePhotoBytes != null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_rounded),
                title: Text(hasPhoto ? 'Update photo' : 'Add photo'),
                subtitle: const Text('Choose an image from your device'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickProfilePhoto();
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected image')),
      );
      return;
    }

    setState(() {
      _contact.photo = bytes;
      _contact.photoFetched = true;
      _photoRemoved = false; // new photo overrides any pending removal
    });
  }

  void _removeProfilePhoto() {
    // Only mark as removed — do NOT mutate _contact yet.
    // The actual nulling happens in _collectFields() so a discard
    // leaves the original contact data untouched.
    setState(() => _photoRemoved = true);
  }

  Widget _buildAvatarSection(ColorScheme colorScheme) {
    final photoBytes = _activePhotoBytes;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Stack(
        children: [
          if (photoBytes != null)
            CircleAvatar(
              radius: 56,
              backgroundImage: MemoryImage(photoBytes),
              backgroundColor: colorScheme.primaryContainer,
            )
          else if (_isNew)
            CircleAvatar(
              radius: 56,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            )
          else
            ContactAvatar(contact: _contact, radius: 56, fontSize: 36),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _showPhotoActions,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: MyContactsColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── Name ────────────────────────

  Widget _buildNameSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.person_rounded,
      title: 'Name',
      children: [
        _buildTextField(
          controller: _firstNameCtrl,
          label: 'First name',
          textCapitalization: TextCapitalization.words,
          autofocus: _isNew,
        ),
        _buildTextField(
          controller: _lastNameCtrl,
          label: 'Last name',
          textCapitalization: TextCapitalization.words,
        ),
        if (_showMoreNameFields) ...[
          _buildTextField(
            controller: _middleNameCtrl,
            label: 'Middle name',
            textCapitalization: TextCapitalization.words,
          ),
          _buildTextField(
            controller: _prefixCtrl,
            label: 'Prefix (e.g. Dr)',
            textCapitalization: TextCapitalization.words,
          ),
          _buildTextField(
            controller: _suffixCtrl,
            label: 'Suffix (e.g. Jr)',
            textCapitalization: TextCapitalization.words,
          ),
          _buildTextField(
            controller: _nicknameCtrl,
            label: 'Nickname',
            textCapitalization: TextCapitalization.words,
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _showMoreNameFields = !_showMoreNameFields;
            }),
            icon: Icon(
              _showMoreNameFields
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(_showMoreNameFields ? 'Less' : 'More name fields'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────── Phones ────────────────────────

  Widget _buildPhoneSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.phone_rounded,
      title: 'Phone',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: () => setState(() => _phones.add(_PhoneEntry())),
        tooltip: 'Add phone',
      ),
      children: [
        for (int i = 0; i < _phones.length; i++) _buildPhoneRow(i, theme),
      ],
    );
  }

  Widget _buildPhoneRow(int index, ThemeData theme) {
    final entry = _phones[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: entry.controller,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(width: 8),
          _buildLabelChip<PhoneLabel>(
            value: entry.label,
            labels: const {
              PhoneLabel.mobile: 'Mobile',
              PhoneLabel.home: 'Home',
              PhoneLabel.work: 'Work',
              PhoneLabel.main: 'Main',
              PhoneLabel.other: 'Other',
            },
            onChanged: (val) => setState(() => entry.label = val),
            theme: theme,
          ),
          if (_phones.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => setState(() {
                _phones[index].controller.dispose();
                _phones.removeAt(index);
              }),
              color: MyContactsColors.redShade400,
            ),
        ],
      ),
    );
  }

  // ──────────────────────── Emails ────────────────────────

  Widget _buildEmailSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.email_rounded,
      title: 'Email',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: () => setState(() => _emails.add(_EmailEntry())),
        tooltip: 'Add email',
      ),
      children: [
        for (int i = 0; i < _emails.length; i++) _buildEmailRow(i, theme),
      ],
    );
  }

  Widget _buildEmailRow(int index, ThemeData theme) {
    final entry = _emails[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: entry.controller,
              label: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: 8),
          _buildLabelChip<EmailLabel>(
            value: entry.label,
            labels: const {
              EmailLabel.home: 'Home',
              EmailLabel.work: 'Work',
              EmailLabel.school: 'School',
              EmailLabel.other: 'Other',
            },
            onChanged: (val) => setState(() => entry.label = val),
            theme: theme,
          ),
          if (_emails.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => setState(() {
                _emails[index].controller.dispose();
                _emails.removeAt(index);
              }),
              color: MyContactsColors.redShade400,
            ),
        ],
      ),
    );
  }

  // ──────────────────────── Organization ────────────────────────

  Widget _buildOrganizationSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.business_rounded,
      title: 'Organization Tags',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: _showAddOrganizationTagDialog,
        tooltip: 'Create organization tag',
      ),
      children: [
        if (_availableOrganizationTags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No organization tags yet',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableOrganizationTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: _selectedOrganizationTags.contains(tag),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedOrganizationTags.add(tag);
                    } else {
                      _selectedOrganizationTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _showAddOrganizationTagDialog() async {
    String draftTagName = '';

    final tagName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New Organization Tag'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tag name (e.g. TechCorp)',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              setDialogState(() {
                draftTagName = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: draftTagName.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, draftTagName.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (tagName == null || tagName.isEmpty) return;

    try {
      await _prefsService.init();
      await _prefsService.addAvailableOrganizationTag(tagName);
      if (!mounted) return;

      setState(() {
        _availableOrganizationTags = _prefsService.getAvailableOrganizationTags();
        final resolved = _availableOrganizationTags.firstWhere(
          (t) => t.toLowerCase() == tagName.toLowerCase(),
          orElse: () => tagName,
        );
        _selectedOrganizationTags.add(resolved);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('Failed to add organization tag: $e')),
      );
    }
  }

  // ──────────────────────── Groups ────────────────────────

  Widget _buildGroupsSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.group_work_rounded,
      title: 'Groups',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: _showAddGroupDialog,
        tooltip: 'Create group',
      ),
      children: [
        if (_availableGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No groups yet',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableGroups.map((group) {
              return FilterChip(
                label: Text(group),
                selected: _selectedGroups.contains(group),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGroups.add(group);
                    } else {
                      _selectedGroups.remove(group);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _showAddGroupDialog() async {
    String draftGroupName = '';

    final groupName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New Group'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Group name (e.g. Neighbours)',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              setDialogState(() {
                draftGroupName = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: draftGroupName.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      draftGroupName.trim(),
                    ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (groupName == null || groupName.isEmpty) return;

    try {
      await _prefsService.init();
      await _prefsService.addAvailableContactGroup(groupName);
      if (!mounted) return;

      setState(() {
        _availableGroups = _prefsService.getAvailableContactGroups();
        final resolved = _availableGroups.firstWhere(
          (g) => g.toLowerCase() == groupName.toLowerCase(),
          orElse: () => groupName,
        );
        _selectedGroups.add(resolved);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add group: $e')));
    }
  }

  // ──────────────────────── Addresses ────────────────────────

  Widget _buildAddressSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.location_on_rounded,
      title: 'Address',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: () => setState(() => _addresses.add(_AddressEntry())),
        tooltip: 'Add address',
      ),
      children: [
        for (int i = 0; i < _addresses.length; i++) _buildAddressRow(i, theme),
        if (_addresses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No addresses',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressRow(int index, ThemeData theme) {
    final entry = _addresses[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildTextField(
              controller: entry.controller,
              label: 'Address',
              maxLines: 3,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _buildLabelChip<AddressLabel>(
                value: entry.label,
                labels: const {
                  AddressLabel.home: 'Home',
                  AddressLabel.work: 'Work',
                  AddressLabel.other: 'Other',
                },
                onChanged: (val) => setState(() => entry.label = val),
                theme: theme,
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => setState(() {
                  _addresses[index].controller.dispose();
                  _addresses.removeAt(index);
                }),
                color: MyContactsColors.redShade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────── Events ────────────────────────

  Widget _buildEventsSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.cake_rounded,
      title: 'Events',
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        onPressed: () => _addEvent(theme),
        tooltip: 'Add event',
      ),
      children: [
        for (int i = 0; i < _events.length; i++) _buildEventRow(i, theme),
        if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No events',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addEvent(ThemeData theme) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _events.add(
          _EventEntry(
            year: picked.year,
            month: picked.month,
            day: picked.day,
            label: _events.isEmpty ? EventLabel.birthday : EventLabel.other,
          ),
        );
      });
    }
  }

  Widget _buildEventRow(int index, ThemeData theme) {
    final entry = _events[index];
    final dateStr = entry.year != null
        ? '${entry.day.toString().padLeft(2, '0')}/${entry.month.toString().padLeft(2, '0')}/${entry.year}'
        : '${entry.day.toString().padLeft(2, '0')}/${entry.month.toString().padLeft(2, '0')}';

    final labelStr = entry.label == EventLabel.birthday
        ? 'Birthday'
        : entry.label == EventLabel.anniversary
        ? 'Anniversary'
        : 'Other';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(
                    entry.year ?? DateTime.now().year,
                    entry.month,
                    entry.day,
                  ),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    entry.year = picked.year;
                    entry.month = picked.month;
                    entry.day = picked.day;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(dateStr, style: const TextStyle(fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labelStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => setState(() => _events.removeAt(index)),
            color: MyContactsColors.redShade400,
          ),
        ],
      ),
    );
  }

  // ──────────────────────── Notes ────────────────────────

  Widget _buildNotesSection(ThemeData theme) {
    return _buildSection(
      theme: theme,
      icon: Icons.notes_rounded,
      title: 'Notes',
      children: [
        _buildTextField(
          controller: _notesCtrl,
          label: 'Notes',
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  // ──────────────────────── Accounts / Source ────────────────────────

  Widget _buildAccountsSection(ThemeData theme) {
    final accounts = _contact.accounts;
    if (accounts.isEmpty) {
      return _buildSection(
        theme: theme,
        icon: Icons.cloud_rounded,
        title: 'Saved to',
        children: [
          _buildInfoTile(
            icon: _isNew ? Icons.account_circle_rounded : Icons.phone_android_rounded,
            title: _isNew ? 'Default contact account' : 'Device',
            subtitle: _isNew
                ? 'Will be saved to your phone default (Phone or Gmail)'
                : 'Saved on this device',
            theme: theme,
          ),
          if (_isNew)
            Text(
              'To change where new contacts are saved, update the default account in your device Contacts app settings.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      );
    }

    return _buildSection(
      theme: theme,
      icon: Icons.cloud_rounded,
      title: 'Saved to',
      children: [
        for (final account in accounts) _buildAccountTile(account, theme),
        const SizedBox(height: 8),
        Text(
          'Contact accounts are managed by your device. '
          'To move a contact between accounts (e.g. from Device '
          'to Gmail), use your device\'s Contacts app → Manage accounts.',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTile(Account account, ThemeData theme) {
    final accountType = account.type.toLowerCase();
    IconData icon;
    String typeName;

    if (accountType.contains('google') || accountType.contains('gmail')) {
      icon = Icons.mail_rounded;
      typeName = 'Google';
    } else if (accountType.contains('exchange') ||
        accountType.contains('microsoft')) {
      icon = Icons.business_rounded;
      typeName = 'Exchange';
    } else if (accountType.contains('icloud') ||
        accountType.contains('apple')) {
      icon = Icons.cloud_rounded;
      typeName = 'iCloud';
    } else if (accountType.contains('sim')) {
      icon = Icons.sim_card_rounded;
      typeName = 'SIM Card';
    } else if (accountType.contains('whatsapp')) {
      icon = FontAwesomeIcons.whatsapp;
      typeName = 'WhatsApp';
    } else if (accountType.contains('telegram')) {
      icon = Icons.send_rounded;
      typeName = 'Telegram';
    } else {
      icon = Icons.account_circle_rounded;
      typeName = account.type.isNotEmpty
          ? account.type.split('.').last.capitalize()
          : 'Device';
    }

    return _buildInfoTile(
      icon: icon,
      title: typeName,
      subtitle: account.name.isNotEmpty ? account.name : 'Local account',
      theme: theme,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── Delete ────────────────────────

  Widget _buildDeleteSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _deleteContact,
        icon: const Icon(Icons.delete_forever_rounded),
        label: const Text('Delete Contact'),
        style: OutlinedButton.styleFrom(
          foregroundColor: MyContactsColors.redShade600,
          side: BorderSide(color: MyContactsColors.redShade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ──────────────────────── Shared Builders ────────────────────────

  Widget _buildSection({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool autofocus = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        autofocus: autofocus,
        textCapitalization: textCapitalization,
      ),
    );
  }

  Widget _buildLabelChip<T>({
    required T value,
    required Map<T, String> labels,
    required ValueChanged<T> onChanged,
    required ThemeData theme,
  }) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labels[value] ?? 'Other',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
      itemBuilder: (_) => labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }
}

// ──────────────────────── Data models ────────────────────────

class _PhoneEntry {
  TextEditingController controller;
  PhoneLabel label;
  String customLabel;

  _PhoneEntry({
    TextEditingController? controller,
    this.label = PhoneLabel.mobile,
    this.customLabel = '',
  }) : controller = controller ?? TextEditingController();
}

class _EmailEntry {
  TextEditingController controller;
  EmailLabel label;
  String customLabel;

  _EmailEntry({
    TextEditingController? controller,
    this.label = EmailLabel.home,
    this.customLabel = '',
  }) : controller = controller ?? TextEditingController();
}

class _AddressEntry {
  TextEditingController controller;
  AddressLabel label;

  _AddressEntry({
    TextEditingController? controller,
    this.label = AddressLabel.home,
  }) : controller = controller ?? TextEditingController();
}

class _EventEntry {
  int? year;
  int month;
  int day;
  EventLabel label;

  _EventEntry({
    this.year,
    this.month = 1,
    this.day = 1,
    this.label = EventLabel.birthday,
  });
}

// ──────────────────────── Extensions ────────────────────────

extension _StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
