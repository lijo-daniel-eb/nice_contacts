import 'dart:math';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/preferences_service.dart';

/// On-device AI-like intelligence for contacts analysis.
class ContactIntelligenceService {
  static final ContactIntelligenceService _instance =
      ContactIntelligenceService._internal();
  factory ContactIntelligenceService() => _instance;
  ContactIntelligenceService._internal();

  final _prefsService = PreferencesService();

  // ─────────────────────────────────────────────
  //  DUPLICATE DETECTION
  // ─────────────────────────────────────────────

  /// Find potential duplicate contacts using name similarity + phone matching.
  List<DuplicateGroup> findDuplicates(List<Contact> contacts) {
    final List<DuplicateGroup> groups = [];
    final Set<int> processed = {};

    for (int i = 0; i < contacts.length; i++) {
      if (processed.contains(i)) continue;

      final List<Contact> duplicates = [];
      final contact = contacts[i];

      for (int j = i + 1; j < contacts.length; j++) {
        if (processed.contains(j)) continue;

        final other = contacts[j];
        final similarity = _calculateSimilarity(contact, other);

        if (similarity >= 0.7) {
          if (duplicates.isEmpty) duplicates.add(contact);
          duplicates.add(other);
          processed.add(j);
        }
      }

      if (duplicates.isNotEmpty) {
        processed.add(i);
        groups.add(
          DuplicateGroup(
            contacts: duplicates,
            similarityScore: _calculateSimilarity(duplicates[0], duplicates[1]),
            reason: _getDuplicateReason(duplicates[0], duplicates[1]),
          ),
        );
      }
    }

    groups.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return groups;
  }

  double _calculateSimilarity(Contact a, Contact b) {
    double score = 0;
    int factors = 0;

    // Name similarity (weight: 0.4)
    if (a.displayName.isNotEmpty && b.displayName.isNotEmpty) {
      final nameSim = _stringSimilarity(
        a.displayName.toLowerCase(),
        b.displayName.toLowerCase(),
      );
      score += nameSim * 0.4;
      factors++;
    }

    // Phone match (weight: 0.4)
    if (a.phones.isNotEmpty && b.phones.isNotEmpty) {
      final phoneMatch = _hasMatchingPhone(a, b);
      if (phoneMatch) {
        score += 0.4;
      }
      factors++;
    }

    // Email match (weight: 0.2)
    if (a.emails.isNotEmpty && b.emails.isNotEmpty) {
      final emailMatch = _hasMatchingEmail(a, b);
      if (emailMatch) {
        score += 0.2;
      }
      factors++;
    }

    if (factors == 0) return 0;

    // Normalize based on factors present
    return min(1.0, score / (factors > 0 ? factors * 0.4 : 1));
  }

  bool _hasMatchingPhone(Contact a, Contact b) {
    for (final pA in a.phones) {
      for (final pB in b.phones) {
        final nA = _normalizePhone(pA.number);
        final nB = _normalizePhone(pB.number);
        // Compare last 8 digits (handles country code variations)
        if (nA.length >= 8 && nB.length >= 8) {
          if (nA.substring(nA.length - 8) == nB.substring(nB.length - 8)) {
            return true;
          }
        } else if (nA == nB) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasMatchingEmail(Contact a, Contact b) {
    final emailsA = a.emails.map((e) => e.address.toLowerCase()).toSet();
    final emailsB = b.emails.map((e) => e.address.toLowerCase()).toSet();
    return emailsA.intersection(emailsB).isNotEmpty;
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String _getDuplicateReason(Contact a, Contact b) {
    final reasons = <String>[];

    final nameSim = _stringSimilarity(
      a.displayName.toLowerCase(),
      b.displayName.toLowerCase(),
    );
    if (nameSim > 0.8) reasons.add('Similar names');

    if (_hasMatchingPhone(a, b)) reasons.add('Same phone number');
    if (_hasMatchingEmail(a, b)) reasons.add('Same email');

    return reasons.isEmpty ? 'Similar contact info' : reasons.join(' • ');
  }

  /// Levenshtein-based string similarity (0.0 to 1.0)
  double _stringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len = max(s1.length, s2.length);
    final dist = _levenshteinDistance(s1, s2);
    return 1.0 - (dist / len);
  }

  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return d[m][n];
  }

  // ─────────────────────────────────────────────
  //  SMART GROUPS
  // ─────────────────────────────────────────────

  /// Auto-categorize contacts into smart groups.
  Map<String, SmartGroup> categorizeContacts(List<Contact> contacts) {
    final Map<String, List<Contact>> groups = {
      'Work': [],
      'Personal': [],
      'Family': [],
      'Social': [],
      'Unknown': [],
    };

    final Map<String, String> groupIcons = {
      'Work': '💼',
      'Personal': '👤',
      'Family': '👨‍👩‍👧‍👦',
      'Social': '🌐',
      'Unknown': '❓',
    };

    for (final contact in contacts) {
      final category = _categorizeContact(contact);
      groups[category]?.add(contact);
    }

    // Remove empty groups
    groups.removeWhere((_, v) => v.isEmpty);

    return groups.map(
      (name, contacts) => MapEntry(
        name,
        SmartGroup(
          name: name,
          icon: groupIcons[name] ?? '📇',
          contacts: contacts,
          description: _getGroupDescription(name),
        ),
      ),
    );
  }

  String _categorizeContact(Contact contact) {
    // Check company/organization
    if (contact.organizations.isNotEmpty) {
      final company = contact.organizations.first.company.toLowerCase();
      if (company.isNotEmpty) return 'Work';
    }

    // Check email domain
    for (final email in contact.emails) {
      final domain = email.address.toLowerCase().split('@').last;
      if (_isWorkDomain(domain)) return 'Work';
      if (_isPersonalDomain(domain)) return 'Personal';
    }

    // Check if labeled as family in phone labels
    for (final phone in contact.phones) {
      final label = phone.label.name.toLowerCase();
      if (label.contains('home') || label.contains('family')) {
        return 'Family';
      }
      if (label.contains('work') || label.contains('office')) {
        return 'Work';
      }
    }

    // Check for social media fields
    if (contact.socialMedias.isNotEmpty) return 'Social';

    // Check name patterns for family members
    if (contact.name.suffix.isNotEmpty || contact.name.nickname.isNotEmpty) {
      return 'Personal';
    }

    return 'Unknown';
  }

  bool _isWorkDomain(String domain) {
    final personalDomains = {
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'aol.com',
      'icloud.com',
      'mail.com',
      'protonmail.com',
      'live.com',
      'msn.com',
      'ymail.com',
      'zoho.com',
    };
    return !personalDomains.contains(domain) && domain.contains('.');
  }

  bool _isPersonalDomain(String domain) {
    final personalDomains = {
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'aol.com',
      'icloud.com',
      'mail.com',
      'protonmail.com',
      'live.com',
      'msn.com',
      'ymail.com',
      'zoho.com',
    };
    return personalDomains.contains(domain);
  }

  String _getGroupDescription(String group) {
    switch (group) {
      case 'Work':
        return 'Contacts with company emails or organizations';
      case 'Personal':
        return 'Contacts with personal email addresses';
      case 'Family':
        return 'Contacts labeled as home or family';
      case 'Social':
        return 'Contacts with social media profiles';
      default:
        return 'Contacts that could not be categorized';
    }
  }

  // ─────────────────────────────────────────────
  //  CONTACT INSIGHTS
  // ─────────────────────────────────────────────

  /// Generate insights about the contact list.
  ContactInsights analyzeContacts(List<Contact> contacts) {
    int withPhone = 0;
    int withEmail = 0;
    int withPhoto = 0;
    int withOrganization = 0;
    int withAddress = 0;
    int withBirthday = 0;
    final Map<String, int> domainDistribution = {};
    final Map<String, int> companyDistribution = {};
    final List<Contact> incompleteContacts = [];

    for (final contact in contacts) {
      if (contact.phones.isNotEmpty) withPhone++;
      if (contact.emails.isNotEmpty) withEmail++;
      if (contact.thumbnail != null) withPhoto++;
      if (contact.organizations.isNotEmpty) withOrganization++;
      if (contact.addresses.isNotEmpty) withAddress++;
      if (contact.events.isNotEmpty) withBirthday++;

      // Domain distribution
      for (final email in contact.emails) {
        final domain = email.address.split('@').last.toLowerCase();
        domainDistribution[domain] = (domainDistribution[domain] ?? 0) + 1;
      }

      // Company distribution
      if (contact.organizations.isNotEmpty) {
        final company = contact.organizations.first.company;
        if (company.isNotEmpty) {
          companyDistribution[company] =
              (companyDistribution[company] ?? 0) + 1;
        }
      }

      // Completeness check
      final score = _completenessScore(contact);
      if (score < 0.5) {
        incompleteContacts.add(contact);
      }
    }

    // Sort distributions
    final sortedDomains = Map.fromEntries(
      domainDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    final sortedCompanies = Map.fromEntries(
      companyDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return ContactInsights(
      totalContacts: contacts.length,
      withPhone: withPhone,
      withEmail: withEmail,
      withPhoto: withPhoto,
      withOrganization: withOrganization,
      withAddress: withAddress,
      withBirthday: withBirthday,
      domainDistribution: sortedDomains,
      companyDistribution: sortedCompanies,
      incompleteContacts: incompleteContacts,
      averageCompleteness: contacts.isEmpty
          ? 0
          : contacts.map(_completenessScore).reduce((a, b) => a + b) /
                contacts.length,
    );
  }

  /// Calculate completeness score for a contact (0.0 to 1.0)
  double completenessScore(Contact contact) => _completenessScore(contact);

  double _completenessScore(Contact contact) {
    double score = 0;
    const total = 6.0;

    if (contact.displayName.isNotEmpty) score += 1;
    if (contact.phones.isNotEmpty) score += 1;
    if (contact.emails.isNotEmpty) score += 1;
    if (contact.organizations.isNotEmpty) score += 1;
    if (contact.thumbnail != null) score += 1;
    if (contact.events.isNotEmpty) score += 1;

    return score / total;
  }

  // ─────────────────────────────────────────────
  //  SUGGESTED ACTIONS
  // ─────────────────────────────────────────────

  /// Generate context-aware suggested actions.
  List<SuggestedAction> generateSuggestions(List<Contact> contacts) {
    final suggestions = <SuggestedAction>[];
    final recents = _prefsService.getRecents();
    final now = DateTime.now();

    // 1. Contacts not contacted in 30+ days
    final recentIds = <String, DateTime>{};
    for (final r in recents) {
      if (!recentIds.containsKey(r.contactId) ||
          r.timestamp.isAfter(recentIds[r.contactId]!)) {
        recentIds[r.contactId] = r.timestamp;
      }
    }

    for (final entry in recentIds.entries) {
      final daysSince = now.difference(entry.value).inDays;
      if (daysSince >= 30) {
        final contact = contacts.where((c) => c.id == entry.key).firstOrNull;
        if (contact != null) {
          suggestions.add(
            SuggestedAction(
              type: SuggestionType.reconnect,
              title: 'Reconnect with ${contact.displayName}',
              subtitle: 'Last contacted $daysSince days ago',
              contact: contact,
              priority: min(daysSince, 100) / 100.0,
            ),
          );
        }
      }
    }

    // 2. Birthday reminders (today & upcoming 7 days)
    for (final contact in contacts) {
      for (final event in contact.events) {
        if (event.year != null || event.month != null) {
          final month = event.month;
          final day = event.day;
          if (month == now.month && day == now.day) {
            suggestions.insert(
              0,
              SuggestedAction(
                type: SuggestionType.birthday,
                title: '🎂 ${contact.displayName}\'s birthday is today!',
                subtitle: 'Send a wish',
                contact: contact,
                priority: 1.0,
              ),
            );
          } else {
            // Check if birthday is within next 7 days
            for (int d = 1; d <= 7; d++) {
              final upcoming = now.add(Duration(days: d));
              if (month == upcoming.month && day == upcoming.day) {
                suggestions.add(
                  SuggestedAction(
                    type: SuggestionType.birthday,
                    title:
                        '🎂 ${contact.displayName}\'s birthday in $d day${d > 1 ? 's' : ''}',
                    subtitle: 'Set a reminder',
                    contact: contact,
                    priority: 0.9 - (d * 0.05),
                  ),
                );
              }
            }
          }
        }
      }
    }

    // 3. Incomplete contacts that are favourites
    final favs = _prefsService.getFavourites();
    for (final contact in contacts) {
      if (favs.contains(contact.id)) {
        final score = _completenessScore(contact);
        if (score < 0.5) {
          suggestions.add(
            SuggestedAction(
              type: SuggestionType.completeInfo,
              title: 'Complete ${contact.displayName}\'s info',
              subtitle:
                  'This favourite contact is only ${(score * 100).toInt()}% complete',
              contact: contact,
              priority: 0.6,
            ),
          );
        }
      }
    }

    // 4. Frequently contacted but not in favourites
    final freqMap = _prefsService.getFrequentlyContacted();
    for (final entry in freqMap.entries.take(5)) {
      if (!favs.contains(entry.key) && entry.value >= 3) {
        final contact = contacts.where((c) => c.id == entry.key).firstOrNull;
        if (contact != null) {
          suggestions.add(
            SuggestedAction(
              type: SuggestionType.addToFavourites,
              title: 'Add ${contact.displayName} to favourites?',
              subtitle: 'You\'ve contacted them ${entry.value} times recently',
              contact: contact,
              priority: 0.5,
            ),
          );
        }
      }
    }

    // Sort by priority
    suggestions.sort((a, b) => b.priority.compareTo(a.priority));
    return suggestions;
  }
}

// ═══════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════

class DuplicateGroup {
  final List<Contact> contacts;
  final double similarityScore;
  final String reason;

  DuplicateGroup({
    required this.contacts,
    required this.similarityScore,
    required this.reason,
  });
}

class SmartGroup {
  final String name;
  final String icon;
  final List<Contact> contacts;
  final String description;

  SmartGroup({
    required this.name,
    required this.icon,
    required this.contacts,
    required this.description,
  });
}

class ContactInsights {
  final int totalContacts;
  final int withPhone;
  final int withEmail;
  final int withPhoto;
  final int withOrganization;
  final int withAddress;
  final int withBirthday;
  final Map<String, int> domainDistribution;
  final Map<String, int> companyDistribution;
  final List<Contact> incompleteContacts;
  final double averageCompleteness;

  ContactInsights({
    required this.totalContacts,
    required this.withPhone,
    required this.withEmail,
    required this.withPhoto,
    required this.withOrganization,
    required this.withAddress,
    required this.withBirthday,
    required this.domainDistribution,
    required this.companyDistribution,
    required this.incompleteContacts,
    required this.averageCompleteness,
  });
}

class SuggestedAction {
  final SuggestionType type;
  final String title;
  final String subtitle;
  final Contact contact;
  final double priority; // 0.0 to 1.0

  SuggestedAction({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.contact,
    required this.priority,
  });
}

enum SuggestionType { reconnect, birthday, completeInfo, addToFavourites }
