class PrivacyPolicySection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const PrivacyPolicySection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

/// Canonical privacy-policy copy used by the first-run gate and Settings.
///
/// Keep this content aligned with `PRIVACY.md` and
/// `docs/privacy-policy.html`. Increment [version] whenever a material change
/// should require users to acknowledge the notice again.
abstract final class DevDeskPrivacyPolicy {
  static const String version = '2026-07-24';
  static const String effectiveDate = '24 July 2026';
  static const String developerName = 'Baisalya';
  static const String repositoryUrl =
      'https://github.com/Baisalya/devdesk-support';
  static const String supportUrl =
      'https://github.com/Baisalya/devdesk-support/issues/new/choose';
  static const String securityUrl =
      'https://github.com/Baisalya/devdesk-support/security/advisories/new';
  static const String supportHomeUrl =
      'https://baisalya.github.io/devdesk-support/';
  static const String privacyPolicyUrl =
      'https://baisalya.github.io/devdesk-support/privacy-policy.html';

  static const List<String> gateSummary = [
    'DevDesk has no account, advertising, analytics, telemetry, cloud sync, or DevDesk-operated backend.',
    'Your work is stored on this device. Files are accessed only after you choose them.',
    'Network activity happens when you run an API request, fetch supported GitHub content, check a link, or open a store or repository page.',
    'The destination you choose—not DevDesk—receives the request and normal connection information.',
  ];

  static const List<PrivacyPolicySection> sections = [
    PrivacyPolicySection(
      title: '1. Who this policy covers',
      paragraphs: [
        'This Privacy Policy explains how DevDesk, published by Baisalya, accesses, uses, stores, shares, retains, and deletes information on Android and Windows. DevDesk is an offline-first developer toolbox.',
        'DevDesk has no user account system, advertising, analytics, telemetry, cloud synchronization, or DevDesk-operated backend. Baisalya does not receive ordinary app usage or locally stored content from the app.',
      ],
    ),
    PrivacyPolicySection(
      title: '2. Information stored on your device',
      paragraphs: [
        'DevDesk stores information only to provide features you choose to use. Ordinary application records are stored in the app\'s private local data area.',
      ],
      bullets: [
        'Markdown documents, notes, snippets, favourites, recent tools, and appearance preferences.',
        'API workspaces, environments, sanitized request history, reports, and vault content.',
        'A local record of the Privacy Policy version you accepted and the acceptance time.',
        'Local rating-prompt preferences and launch counters.',
      ],
    ),
    PrivacyPolicySection(
      title: '3. Credentials and sensitive values',
      paragraphs: [
        'API credentials and marked secret values are separated from ordinary workspace records where the operating system provides an appropriate protection boundary.',
      ],
      bullets: [
        'Android: encrypted using a key held by Android Keystore.',
        'Windows: protected with Windows Data Protection API (DPAPI) for the current Windows user.',
        'Protected secret values are excluded from DevDesk backups by default.',
      ],
    ),
    PrivacyPolicySection(
      title: '4. User-initiated network activity',
      paragraphs: [
        'DevDesk does not send analytics or content to Baisalya. It uses the network for the following actions that you initiate:',
      ],
      bullets: [
        'API Tester sends the URL, method, headers, parameters, cookies, and body you prepare to the server or service whose URL you choose, and receives its response.',
        'Supported GitHub comparison and import actions fetch public repository metadata, files, or archives from GitHub URLs you choose.',
        'A link-check action sends an HTTP HEAD request to the link you ask DevDesk to validate.',
        'Rating, store, support, or repository actions open the applicable Google Play, Microsoft Store, GitHub, or browser destination only after you select them.',
      ],
    ),
    PrivacyPolicySection(
      title: '5. What destination services receive',
      paragraphs: [
        'A server contacted by your action receives the information needed to complete that action. Depending on what you enter, this can include your IP address, request URL, headers, cookies, request body, and other content. DevDesk sends these requests directly from your device and does not proxy them through a DevDesk server.',
        'The destination service, network provider, operating system, browser, Google Play, Microsoft Store, or GitHub may process information under its own privacy policy. Review the destination and use HTTPS before sending sensitive information. Android production builds block cleartext HTTP; Windows follows the URL you choose.',
      ],
    ),
    PrivacyPolicySection(
      title: '6. Files, exports, and clipboard',
      paragraphs: [
        'DevDesk reads a file only after you select it through the platform picker. Android uses document access supplied by the system and does not request broad storage access. Windows uses paths selected by you.',
        'Backups and exports remain wherever you save or share them. Explicit copy actions place content in the operating-system clipboard. DevDesk applies conservative redaction to portable API history, reports, generated snippets, clipboard output, collection exports, and backups, but automatic redaction cannot guarantee that every confidential value will be recognized. Review content before sharing it.',
        'Remote images in Markdown are blocked, so Markdown preview does not silently load tracking pixels or other remote image resources.',
      ],
    ),
    PrivacyPolicySection(
      title: '7. Sharing, sale, and third-party SDKs',
      paragraphs: [
        'Baisalya does not sell user data. DevDesk does not share locally stored content with advertisers, data brokers, or a DevDesk service. The user-initiated transfers described above go only to the destination you choose or the external page you open.',
        'The app does not include advertising, analytics, Firebase, social-login, or payment SDKs. Flutter packages used for local storage, file selection, package information, protected platform storage, HTTP requests, and URL launching operate only when the corresponding app feature uses them.',
      ],
    ),
    PrivacyPolicySection(
      title: '8. Security and platform boundaries',
      paragraphs: [
        'DevDesk uses platform-private storage, protected secret storage where available, guarded file replacement, bounded network operations, validation for backup imports, and redaction for portable API data. No security control is absolute.',
        'Device administrators, malware running as your user, screen capture, clipboard managers, synchronized clipboard features, operating-system backups, a compromised device, and the security practices of destination services are outside DevDesk\'s control. Android application backup and data extraction are disabled for DevDesk private data. Windows data follows the Windows user profile and its backup policy.',
      ],
    ),
    PrivacyPolicySection(
      title: '9. Retention and deletion',
      paragraphs: [
        'Local records remain until you delete them, use Clear All Data, clear the app through the operating system, or uninstall the app. Some API history and report collections also use application limits. Clear All Data cancels active API work and removes known local records, protected secrets, settings, rating state, and the policy-acceptance record. The policy gate will appear again afterward.',
        'Files and backups you exported are separate copies and must be deleted from their saved locations by you. Information already sent to a destination service is controlled by that service and must be deleted through that service. DevDesk has no online account to delete and no server-side DevDesk user profile.',
      ],
    ),
    PrivacyPolicySection(
      title: '10. Children\'s privacy',
      paragraphs: [
        'DevDesk is a professional developer tool and is not directed to children. DevDesk does not knowingly operate a service that collects personal information from children.',
      ],
    ),
    PrivacyPolicySection(
      title: '11. Changes to this policy',
      paragraphs: [
        'The effective date and policy version appear at the top of this policy. When a material in-app policy change is introduced, DevDesk changes the version and asks you to acknowledge the updated policy before continuing to use the app.',
      ],
    ),
    PrivacyPolicySection(
      title: '12. Contact',
      paragraphs: [
        'Privacy questions can be submitted to the DevDesk repository issue tracker: https://github.com/Baisalya/devdesk/issues. Do not include credentials, tokens, private request bodies, or personal data in a public issue.',
        'Security-sensitive reports should use a private repository security advisory when available: https://github.com/Baisalya/devdesk/security/advisories/new.',
      ],
    ),
  ];
}
