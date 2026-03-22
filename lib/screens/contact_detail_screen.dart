import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:my_contacts/screens/edit_contact_screen.dart';
import 'package:my_contacts/screens/fake_call_screen.dart';
import 'package:my_contacts/services/call_recordings_service.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/direct_call_service.dart';
import 'package:my_contacts/services/contact_ringtone_service.dart';
import 'package:my_contacts/services/fake_call_scheduler_service.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  final _fakeCallScheduler = FakeCallSchedulerService();
  final _callRecordingsService = CallRecordingsService();
  final AudioPlayer _recordingPlayer = AudioPlayer();
  final ValueNotifier<String?> _playingRecordingPathListenable =
      ValueNotifier<String?>(null);
  late bool _isFavourite;
  late Contact _currentContact;
  bool _isLoadingRecordings = false;
  bool _isRecordingActionBusy = false;
  String? _playingRecordingPath;
  String? _customRingtone;
  List<CallRecordingItem> _callRecordings = const [];
  List<String> _contactGroups = const [];

  Contact get contact => _currentContact;

  @override
  void initState() {
    super.initState();
    _currentContact = widget.contact;
    _isFavourite = _prefsService.isFavourite(contact.id);
    _customRingtone = _prefsService.getContactRingtone(contact.id);
    _repo.addListener(_onRepoUpdated);
    // Kick off high-res photo load
    _repo.getHighResPhoto(contact.id);
    _loadContactGroups();
    _loadCallRecordings();
    _recordingPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      _setPlayingRecordingPath(null);
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    _recordingPlayer.dispose();
    _playingRecordingPathListenable.dispose();
    super.dispose();
  }

  void _onRepoUpdated() {
    if (!mounted) return;
    // Stop listening once the high-res photo is loaded
    if (_repo.hasHighResPhoto(contact.id)) {
      _repo.removeListener(_onRepoUpdated);
    }
    setState(() {});
  }

  Future<void> _editContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact)),
    );

    if (!mounted) return;

    if (result == 'deleted') {
      // Contact was deleted — pop back to the list
      Navigator.pop(context, 'deleted');
      return;
    }

    if (result is Contact) {
      setState(() {
        _currentContact = result;
      });
      _loadContactGroups();
      _loadCallRecordings();
    }
  }

  void _loadContactGroups() {
    final groups = _prefsService.getContactGroups(contact.id);
    if (!mounted) return;
    setState(() {
      _contactGroups = groups;
    });
  }

  Future<void> _loadCallRecordings() async {
    if (!mounted) return;
    setState(() => _isLoadingRecordings = true);
    final recordings = await _callRecordingsService.getRecordingsForContact(
      contact,
    );
    if (!mounted) return;
    setState(() {
      _callRecordings = recordings;
      _isLoadingRecordings = false;
    });
  }

  Future<void> _toggleRecordingPlayback(CallRecordingItem recording) async {
    if (_isRecordingActionBusy) return;
    _isRecordingActionBusy = true;

    try {
      if (_playingRecordingPath == recording.path) {
        await _recordingPlayer.stop();
        _setPlayingRecordingPath(null);
        return;
      }

      await _recordingPlayer.stop();
      await _recordingPlayer.play(DeviceFileSource(recording.path));
      _setPlayingRecordingPath(recording.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play this recording file')),
      );
    } finally {
      _isRecordingActionBusy = false;
    }
  }

  void _setPlayingRecordingPath(String? path) {
    if (!mounted) return;
    setState(() => _playingRecordingPath = path);
    _playingRecordingPathListenable.value = path;
  }

  Future<void> _makeCall(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'call');
    await DirectCallService.call(number);
  }

  void _startFakeCall(String number) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            FakeCallScreen(
              contact: contact,
              phoneNumber: number,
              autoAttend: _prefsService.getAutoAttendFakeCalls(),
              ringtonePath: _customRingtone,
            ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _fakeCall(String number) async {
    final pendingCalls = await _fakeCallScheduler.getScheduledCallsFor(
      contact.id,
      number,
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  child: Text(
                    'Fake Call Options',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (pendingCalls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      '${pendingCalls.length} pending schedule${pendingCalls.length == 1 ? '' : 's'}',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _sheetAction(
                  context: ctx,
                  icon: Icons.phone_callback_rounded,
                  title: 'Start Now',
                  subtitle: 'Launch fake call screen immediately',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startFakeCall(number);
                  },
                ),
                _sheetAction(
                  context: ctx,
                  icon: Icons.schedule_rounded,
                  title: 'In 10 seconds',
                  subtitle: 'Quick trigger',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _scheduleFakeCall(
                      number,
                      DateTime.now().add(const Duration(seconds: 10)),
                    );
                  },
                ),
                _sheetAction(
                  context: ctx,
                  icon: Icons.schedule_rounded,
                  title: 'In 30 seconds',
                  subtitle: 'Short delay',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _scheduleFakeCall(
                      number,
                      DateTime.now().add(const Duration(seconds: 30)),
                    );
                  },
                ),
                _sheetAction(
                  context: ctx,
                  icon: Icons.schedule_rounded,
                  title: 'In 1 minute',
                  subtitle: 'Choose and adjust minutes',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickCustomMinuteAndSchedule(number);
                  },
                ),
                if (pendingCalls.isNotEmpty)
                  _sheetAction(
                    context: ctx,
                    icon: Icons.list_alt_rounded,
                    title: 'View Pending Schedules',
                    subtitle: 'Open next window to manage each schedule',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _showScheduledFakeCallsSheet(number);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: titleColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
      ),
      subtitle: Text(subtitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  Future<void> _scheduleFakeCall(String number, DateTime when) async {
    await _fakeCallScheduler.scheduleFakeCall(
      contactId: contact.id,
      contactName: contact.displayName,
      phoneNumber: number,
      when: when,
    );

    if (!mounted) return;
    final pretty = DateFormat('EEE, MMM d • h:mm a').format(when);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fake call scheduled for $pretty')),
    );
  }

  Future<void> _pickCustomMinuteAndSchedule(String number) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        var selectedMinutes = 1;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Fake Call',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust delay in minutes',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: selectedMinutes > 1
                              ? () {
                                  setSheetState(() {
                                    selectedMinutes--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$selectedMinutes min',
                          style: Theme.of(ctx).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 16),
                        IconButton.filled(
                          onPressed: () {
                            setSheetState(() {
                              selectedMinutes++;
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetCtx, selectedMinutes),
                        icon: const Icon(Icons.schedule_rounded),
                        label: const Text('Schedule'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || minutes == null) return;
    await _scheduleFakeCall(number, DateTime.now().add(Duration(minutes: minutes)));
  }

  Future<void> _showScheduledFakeCallsSheet(String number) async {
    final calls = await _fakeCallScheduler.getScheduledCallsFor(contact.id, number);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final items = calls.toList();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Text(
                        'Pending Schedules',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        child: Text(
                          'No pending schedules for this number.',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final call = items[index];
                            return ListTile(
                              leading: const Icon(Icons.alarm_rounded),
                              title: Text(
                                DateFormat(
                                  'EEE, MMM d • h:mm a',
                                ).format(call.scheduledAt),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text('Scheduled fake call'),
                              trailing: IconButton(
                                tooltip: 'Delete schedule',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: MyContactsColors.red,
                                ),
                                onPressed: () async {
                                  await _fakeCallScheduler.cancelScheduledFakeCall(
                                    call.id,
                                  );
                                  if (!mounted) return;
                                  setSheetState(() {
                                    items.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Scheduled fake call deleted'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelScheduledFakeCall(int scheduleId) async {
    await _fakeCallScheduler.cancelScheduledFakeCall(scheduleId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scheduled fake call cancelled')),
    );
  }

  Future<void> _sendSms(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'message');
    final uri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'email');
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'whatsapp');
    // Strip everything except digits and +
    var cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    // If the number doesn't start with + or a country code, assume India (+91)
    if (!cleanNumber.startsWith('+')) {
      // If it's a 10-digit local number, prepend 91
      if (cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }
      // If it already starts with 91 and is 12 digits, keep as-is
    }
    // Remove any leading + for WhatsApp (it expects digits only)
    cleanNumber = cleanNumber.replaceAll('+', '');
    // Try opening directly in WhatsApp app first
    final appUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web link
      final webUri = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _shareContact() async {
    final buffer = StringBuffer();
    buffer.writeln(contact.displayName);
    for (final phone in contact.phones) {
      buffer.writeln('Phone: ${phone.number}');
    }
    for (final email in contact.emails) {
      buffer.writeln('Email: ${email.address}');
    }
    if (contact.organizations.isNotEmpty) {
      buffer.writeln('Company: ${contact.organizations.first.company}');
    }
    await Share.share(buffer.toString());
  }

  Future<void> _pickRingtone() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'],
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _prefsService.setContactRingtone(contact.id, path);
    // Apply to the Android system contact so the real incoming call also uses it.
    await ContactRingtoneService.setSystemRingtone(
      contactId: contact.id,
      filePath: path,
    );
    if (!mounted) return;
    setState(() => _customRingtone = path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ringtone set: ${result.files.first.name}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearRingtone() async {
    await _prefsService.clearContactRingtone(contact.id);
    // Remove the custom system ringtone so real incoming calls revert to default.
    await ContactRingtoneService.clearSystemRingtone(contactId: contact.id);
    if (!mounted) return;
    setState(() => _customRingtone = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringtone reset to default'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleFavourite() async {
    await _prefsService.toggleFavourite(contact.id);
    setState(() {
      _isFavourite = !_isFavourite;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavourite
                ? '${contact.displayName} added to favourites'
                : '${contact.displayName} removed from favourites',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Build the header with either a full-bleed profile photo or gradient + avatar.
  Widget _buildHeaderBackground(ThemeData theme, ColorScheme colorScheme) {
    // Try high-res photo first, then thumbnail, then inline thumbnail.
    final Uint8List? photo =
        _repo.getHighResPhoto(contact.id) ??
        _repo.getThumbnail(contact.id) ??
        contact.thumbnail;
    final hasPhoto = photo != null && photo.isNotEmpty;

    if (hasPhoto) {
      // Full-bleed photo header
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo, fit: BoxFit.cover, width: double.infinity),
          // Dark gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MyContactsColors.black.withValues(alpha: 0.1),
                  MyContactsColors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          // Name and company at the bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: MyContactsColors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: MyContactsColors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (contact.organizations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.organizations.first.company,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MyContactsColors.white.withValues(alpha: 0.9),
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: MyContactsColors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Fallback: gradient + avatar (no photo available)
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Hero(
              tag: 'avatar-${contact.id}',
              child: ContactAvatar(
                contact: contact,
                radius: 52,
                fontSize: 36,
                showBorder: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              contact.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: MyContactsColors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (contact.organizations.isNotEmpty)
              Text(
                contact.organizations.first.company,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyContactsColors.white.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.primary,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyContactsColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: MyContactsColors.white,
                  size: 20,
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _editContact,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MyContactsColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: MyContactsColors.white,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleFavourite,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MyContactsColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isFavourite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _isFavourite
                        ? MyContactsColors.cFFFFA62E
                        : MyContactsColors.white,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: _shareContact,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MyContactsColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: MyContactsColors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderBackground(theme, colorScheme),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: MyContactsColors.cFF4CAF50,
                      onTap: () => _makeCall(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.phone_callback_rounded,
                      label: 'Fake Call',
                      color: MyContactsColors.cFFE91E63,
                      onTap: () => _fakeCall(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.message_rounded,
                      label: 'Message',
                      color: MyContactsColors.cFF2196F3,
                      onTap: () => _sendSms(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      color: MyContactsColors.cFF25D366,
                      onTap: () => _openWhatsApp(contact.phones.first.number),
                    ),
                  if (contact.emails.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: MyContactsColors.cFFFF9800,
                      onTap: () => _sendEmail(contact.emails.first.address),
                    ),
                  _buildQuickAction(
                    context,
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: colorScheme.tertiary,
                    onTap: _shareContact,
                  ),
                ],
              ),
            ),
          ),

          // Contact Info Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  // Phone numbers with call/message actions
                  if (contact.phones.isNotEmpty)
                    _buildPhoneCard(
                      context,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Emails with send action
                  if (contact.emails.isNotEmpty)
                    _buildEmailCard(
                      context,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Addresses
                  if (contact.addresses.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Addresses',
                      icon: Icons.location_on_rounded,
                      items: contact.addresses
                          .map(
                            (a) => _InfoItem(
                              label: _addressLabel(a.label),
                              value: a.address,
                            ),
                          )
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Organizations
                  if (_organizationTags.isNotEmpty)
                    _buildOrganizationTagsCard(
                      context,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  if (_contactGroups.isNotEmpty)
                    _buildGroupsCard(
                      context,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Websites
                  if (contact.websites.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Websites',
                      icon: Icons.language_rounded,
                      items: contact.websites
                          .map((w) => _InfoItem(label: 'Website', value: w.url))
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                      onItemTap: (item) async {
                        var url = item.value;
                        if (!url.startsWith('http')) url = 'https://$url';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),

                  // Events (birthdays, anniversaries)
                  if (contact.events.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Events',
                      icon: Icons.cake_rounded,
                      items: contact.events.map((e) {
                        final label = switch (e.label) {
                          EventLabel.birthday => 'Birthday',
                          EventLabel.anniversary => 'Anniversary',
                          _ => 'Event',
                        };
                        final dateStr =
                            '${e.month}/${e.day}'
                            '${e.year != null ? '/${e.year}' : ''}';
                        return _InfoItem(label: label, value: dateStr);
                      }).toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  _buildRingtoneCard(
                    context,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),

                  _buildCallRecordingsCard(
                    context,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),

                  // Notes
                  if (contact.notes.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Notes',
                      icon: Icons.note_rounded,
                      items: contact.notes
                          .map((n) => _InfoItem(label: 'Note', value: n.note))
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFF4CAF50.withValues(alpha: 0.15),
                        MyContactsColors.cFF4CAF50.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: MyContactsColors.cFF4CAF50,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Phone Numbers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...contact.phones.asMap().entries.map((entry) {
            final phone = entry.value;
            final isLast = entry.key == contact.phones.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: phone.number),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${phone.number}"'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _phoneLabel(phone.label),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone.number,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _iconActionButton(
                        icon: Icons.call_rounded,
                        color: MyContactsColors.cFF4CAF50,
                        tooltip: 'Call',
                        onTap: () => _makeCall(phone.number),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: Icons.phone_callback_rounded,
                        color: MyContactsColors.cFFE91E63,
                        tooltip: 'Fake Call',
                        onTap: () => _fakeCall(phone.number),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: Icons.message_rounded,
                        color: MyContactsColors.cFF2196F3,
                        tooltip: 'Message',
                        onTap: () => _sendSms(phone.number),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: FontAwesomeIcons.whatsapp,
                        color: MyContactsColors.cFF25D366,
                        tooltip: 'WhatsApp',
                        onTap: () => _openWhatsApp(phone.number),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRingtoneCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final hasCustom = _customRingtone != null;
    final fileName = hasCustom
        ? _customRingtone!.split('/').last.split('\\').last
        : 'Default ringtone';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFFFF9800.withValues(alpha: 0.15),
                        MyContactsColors.cFFFF9800.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    size: 16,
                    color: MyContactsColors.cFFFF9800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ringtone',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MyContactsColors.cFFFF9800.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasCustom ? Icons.music_note_rounded : Icons.notifications_rounded,
                color: MyContactsColors.cFFFF9800,
                size: 20,
              ),
            ),
            title: Text(
              fileName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              hasCustom
                  ? 'Plays on fake calls & real incoming calls'
                  : 'Pick a tone for fake calls and real incoming calls',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCustom)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Reset to default',
                    onPressed: _clearRingtone,
                  ),
                IconButton(
                  icon: Icon(
                    Icons.folder_open_rounded,
                    color: MyContactsColors.cFFFF9800,
                  ),
                  tooltip: 'Pick ringtone',
                  onPressed: _pickRingtone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallRecordingsCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final remainingCount = _callRecordings.length > 10
        ? _callRecordings.length - 10
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFF7C3AED.withValues(alpha: 0.15),
                        MyContactsColors.cFF7C3AED.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: MyContactsColors.cFF7C3AED,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Call Recordings',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isLoadingRecordings ? null : _loadCallRecordings,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh recordings',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoadingRecordings)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Scanning recording folders...'),
                ],
              ),
            )
          else if (_callRecordings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No matched recordings found for this contact.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            ..._callRecordings.take(10).map((recording) {
              final index = _callRecordings.indexOf(recording);
              final isLast = index ==
                  (_callRecordings.length > 10
                      ? 9
                      : _callRecordings.length - 1);
              final isPlaying = _playingRecordingPath == recording.path;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    onTap: () => _toggleRecordingPlayback(recording),
                    title: Text(
                      recording.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy, hh:mm a').format(recording.modifiedAt)} • ${_formatBytes(recording.sizeBytes)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: isPlaying ? 'Stop playback' : 'Play recording',
                      onPressed: () => _toggleRecordingPlayback(recording),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isPlaying
                            ? MyContactsColors.cFF4CAF50
                            : colorScheme.primary.withValues(alpha: 0.78),
                        size: 26,
                      ),
                    ),
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }),
          if (!_isLoadingRecordings && _callRecordings.length > 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickRecordingDateRange,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '+$remainingCount more recordings (filter by date range)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickRecordingDateRange() async {
    if (_callRecordings.isEmpty) return;

    var minDate = DateTime(
      _callRecordings.first.modifiedAt.year,
      _callRecordings.first.modifiedAt.month,
      _callRecordings.first.modifiedAt.day,
    );
    var maxDate = minDate;

    for (final recording in _callRecordings) {
      final dateOnly = DateTime(
        recording.modifiedAt.year,
        recording.modifiedAt.month,
        recording.modifiedAt.day,
      );
      if (dateOnly.isBefore(minDate)) minDate = dateOnly;
      if (dateOnly.isAfter(maxDate)) maxDate = dateOnly;
    }

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: minDate,
      lastDate: maxDate,
      initialDateRange: DateTimeRange(start: minDate, end: maxDate),
      helpText: 'Filter recordings by date',
    );

    if (pickedRange == null || !mounted) return;

    final rangeStart = DateTime(
      pickedRange.start.year,
      pickedRange.start.month,
      pickedRange.start.day,
    );
    final rangeEnd = DateTime(
      pickedRange.end.year,
      pickedRange.end.month,
      pickedRange.end.day,
      23,
      59,
      59,
      999,
    );

    final filteredRecordings = _callRecordings.where((recording) {
      final modifiedAt = recording.modifiedAt;
      return !modifiedAt.isBefore(rangeStart) && !modifiedAt.isAfter(rangeEnd);
    }).toList();

    final rangeLabel =
        '${DateFormat('dd MMM yyyy').format(rangeStart)} - ${DateFormat('dd MMM yyyy').format(rangeEnd)}';

    await _showRecordingsSheet(
      recordings: filteredRecordings,
      title: 'Recordings in Range (${filteredRecordings.length})',
      subtitle: rangeLabel,
    );
  }

  Future<void> _showRecordingsSheet({
    required List<CallRecordingItem> recordings,
    required String title,
    String? subtitle,
  }) async {
    if (recordings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recordings found in selected range.')),
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final colorScheme = Theme.of(sheetCtx).colorScheme;
        final theme = Theme.of(sheetCtx);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetCtx).size.height * 0.72,
                  ),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _playingRecordingPathListenable,
                    builder: (context, playingPath, _) => ListView.separated(
                      shrinkWrap: true,
                      itemCount: recordings.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (_, index) {
                        final recording = recordings[index];
                        final isPlaying = playingPath == recording.path;

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _toggleRecordingPlayback(recording),
                          title: Text(
                            recording.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy, hh:mm a').format(recording.modifiedAt)} • ${_formatBytes(recording.sizeBytes)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: isPlaying ? 'Stop playback' : 'Play recording',
                            onPressed: () => _toggleRecordingPlayback(recording),
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: isPlaying
                                  ? MyContactsColors.cFF4CAF50
                                  : colorScheme.primary.withValues(alpha: 0.78),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildEmailCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFFFF9800.withValues(alpha: 0.15),
                        MyContactsColors.cFFFF9800.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.email_rounded,
                    size: 16,
                    color: MyContactsColors.cFFFF9800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Email Addresses',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...contact.emails.asMap().entries.map((entry) {
            final email = entry.value;
            final isLast = entry.key == contact.emails.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: email.address),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${email.address}"'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _emailLabel(email.label),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email.address,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _iconActionButton(
                        icon: Icons.send_rounded,
                        color: MyContactsColors.cFFFF9800,
                        tooltip: 'Send email',
                        onTap: () => _sendEmail(email.address),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFF7C3AED.withValues(alpha: 0.15),
                        MyContactsColors.cFF7C3AED.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.group_work_rounded,
                    size: 16,
                    color: MyContactsColors.cFF7C3AED,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Groups',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _contactGroups
                  .map(
                    (group) => Chip(
                      label: Text(group),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      backgroundColor: colorScheme.surface,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _organizationTags {
    final tags = <String>[];
    for (final org in contact.organizations) {
      final name = org.company.trim();
      if (name.isEmpty) continue;
      final exists = tags.any((t) => t.toLowerCase() == name.toLowerCase());
      if (!exists) tags.add(name);
    }
    return tags;
  }

  Widget _buildOrganizationTagsCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MyContactsColors.cFF1B98E0.withValues(alpha: 0.15),
                        MyContactsColors.cFF1B98E0.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    size: 16,
                    color: MyContactsColors.cFF1B98E0,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Organization',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _organizationTags
                  .map(
                    (org) => Chip(
                      label: Text(org),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      backgroundColor: colorScheme.surface,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    required ColorScheme colorScheme,
    required ThemeData theme,
    void Function(_InfoItem item)? onItemTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.15),
                        colorScheme.tertiary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: onItemTap != null ? () => onItemTap(item) : null,
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "${item.value}"'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.value,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _phoneLabel(PhoneLabel label) {
    return switch (label) {
      PhoneLabel.mobile => 'Mobile',
      PhoneLabel.work => 'Work',
      PhoneLabel.home => 'Home',
      PhoneLabel.main => 'Main',
      PhoneLabel.pager => 'Pager',
      PhoneLabel.other => 'Other',
      _ => 'Phone',
    };
  }

  String _emailLabel(EmailLabel label) {
    return switch (label) {
      EmailLabel.home => 'Home',
      EmailLabel.work => 'Work',
      EmailLabel.other => 'Other',
      _ => 'Email',
    };
  }

  String _addressLabel(AddressLabel label) {
    return switch (label) {
      AddressLabel.home => 'Home',
      AddressLabel.work => 'Work',
      AddressLabel.other => 'Other',
      _ => 'Address',
    };
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem({required this.label, required this.value});
}
