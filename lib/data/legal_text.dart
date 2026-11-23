/// Version of the legal text. Change it whenever the text below changes.
const String kLegalVersion = '2026-11';

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

class LegalDocument {
  final String title;
  final String updated;
  final List<LegalSection> sections;
  const LegalDocument({
    required this.title,
    required this.updated,
    required this.sections,
  });
}

const kTermsOfService = LegalDocument(
  title: 'Terms of Service',
  updated: 'November 2026',
  sections: [
    LegalSection(
      'Agreeing to these terms',
      'By creating a BookSlot account or using the app, you agree to these Terms of Service. If you do not agree, please do not use the app.\n\n'
          'BookSlot is the Granby Colleges Mobile Library System. It is used to browse, reserve, borrow and return books from the Granby Colleges library.',
    ),
    LegalSection(
      'Who can use BookSlot',
      'BookSlot is for students and library staff of Granby Colleges. A student account only becomes active after the library administrator approves the registration, and the administrator may reject a registration that is wrong or incomplete.\n\n'
          'If you are under 18, please read these terms together with a parent or guardian.',
    ),
    LegalSection(
      'Your account',
      '• Sign in with your own Google account.\n'
          '• Give true and complete information when you sign up (name, student ID, age, sex and course).\n'
          '• Keep your account to yourself. You are responsible for what happens under it.\n'
          '• Tell the library office if you think someone else is using your account.',
    ),
    LegalSection(
      'Reserving and borrowing books',
      '• A reservation is a request. The librarian can accept or deny it.\n'
          '• When a reservation is accepted, a copy is held for you until the pickup deadline. If you do not collect the book in time, the reservation expires and the copy is released.\n'
          '• If the last copy of a book is picked up by another student, other pending reservations for that book are cancelled.\n'
          '• The borrowing period, the number of books you can borrow at once and the number of active reservations you can have are set by the library administrator and can change.\n'
          '• A book counts as borrowed only after the librarian confirms the pickup, and as returned only after the librarian confirms the return.',
    ),
    LegalSection(
      'QR codes',
      'Your pickup and return QR codes are personal. Only show them to a librarian at the library. Do not share them or post them online. A QR code only works for the reservation it belongs to, and nothing happens until a librarian scans it and confirms.',
    ),
    LegalSection(
      'Returning books and caring for them',
      'Return borrowed books on or before the due date and in good condition. Late, lost or damaged books are handled under the regular library rules of Granby Colleges. BookSlot only flags overdue books. It does not charge fines by itself.',
    ),
    LegalSection(
      'Acceptable use',
      '• Do not give false information or pretend to be someone else.\n'
          '• Do not try to break, overload or get around the security of the app or its data.\n'
          '• Do not use the app to harass anyone or for anything unlawful.\n'
          '• Do not make reservations you do not plan to collect.',
    ),
    LegalSection(
      'Suspension and removal',
      'The library administrator may suspend or remove an account that breaks these terms or the library rules. You can ask the library office to close your account at any time, once any books you borrowed have been returned.',
    ),
    LegalSection(
      'Availability of the app',
      'BookSlot is provided "as is". We try to keep it working, but it may be unavailable because of maintenance, internet problems or other reasons. If the app and the library records ever disagree, the librarian has the final say at the desk.',
    ),
    LegalSection(
      'Limits of responsibility',
      'To the extent allowed by law, Granby Colleges and the BookSlot team are not responsible for losses caused by the app being unavailable, by wrong information entered by users, or by use of the app against these terms.',
    ),
    LegalSection(
      'Changes to these terms',
      'These terms may be updated. The date and version at the top of this page show the latest one. When something important changes, we will tell you in the app. Using BookSlot after a change means you accept the updated terms.',
    ),
    LegalSection(
      'Governing law and contact',
      'These terms follow the laws of the Republic of the Philippines. If you have questions, please contact the library office of Granby Colleges or the BookSlot administrator.',
    ),
  ],
);

const kPrivacyPolicy = LegalDocument(
  title: 'Privacy Policy',
  updated: 'November 2026',
  sections: [
    LegalSection(
      'Who we are',
      'BookSlot is the Granby Colleges Mobile Library System. The library office of Granby Colleges, through the BookSlot administrator, decides how your information is used and is responsible for protecting it.\n\n'
          'This policy explains what we collect, why we collect it, and what your rights are under the Data Privacy Act of 2012 (Republic Act No. 10173).',
    ),
    LegalSection(
      'What we collect',
      'When you sign up:\n'
          '• Your Google account email address\n'
          '• Your full name, student ID, age, sex and course\n'
          '• The date you accepted the Terms of Service and this Privacy Policy\n\n'
          'While you use the app:\n'
          '• Your preferred genres, if you choose any\n'
          '• Your reservations, borrowed books, due dates and return dates\n'
          '• Alerts sent to you about your reservations\n'
          '• A record of important actions in the app (for example making or cancelling a reservation), which the administrator can review\n\n'
          'We do not collect your location, your contacts or the files on your phone. The camera is only used by librarians to scan QR codes, and nothing the camera sees is saved.',
    ),
    LegalSection(
      'Why we collect it',
      '• To check that you are a Granby Colleges student and approve your account\n'
          '• To let you reserve, borrow and return books and to keep the library records\n'
          '• To tell you about your reservations\n'
          '• To recommend books based on the genres you picked\n'
          '• To make library reports, such as how many books are borrowed, and to keep the system secure and accountable\n\n'
          'We use your information based on your consent, which you give when you accept this policy, and on the library\'s need to run its lending service.',
    ),
    LegalSection(
      'Who can see your information',
      '• You can see your own profile, reservations, borrowing history and alerts.\n'
          '• Librarians can see your name, student ID, email, and your reservation and borrowing records, so they can serve you at the library.\n'
          '• The administrator can see all of the above, plus your age, sex and course, and the reports and audit logs built from them.\n'
          '• Other students cannot see your information.\n\n'
          'Reports show totals and rankings (for example the most active readers and borrows by course) and are for library use only. We do not sell your information and we do not show ads.',
    ),
    LegalSection(
      'Where your information is stored',
      'Your information is stored with Google Firebase (Firebase Authentication and Cloud Firestore). Google may store and process data on servers in other countries.\n\n'
          'Access rules make sure that each person can only reach the information they need, and the app talks to the servers over secure connections. No system is completely safe, but we work to protect your information.',
    ),
    LegalSection(
      'How long we keep it',
      'We keep your account information and borrowing records for as long as your account is active and as long as the library needs them for its records and reports. You can ask the library office to remove your account and personal details. We may keep records that we need for books that are still unreturned or that the law requires us to keep.',
    ),
    LegalSection(
      'Your rights',
      'Under the Data Privacy Act you have the right to:\n'
          '• Be informed about how your data is used\n'
          '• Access the data we hold about you\n'
          '• Ask us to correct wrong or outdated data\n'
          '• Object to the use of your data, or withdraw your consent\n'
          '• Ask us to block or remove your data\n'
          '• Receive a copy of your data\n'
          '• Be compensated for damages caused by wrongful use of your data\n\n'
          'To use these rights, please contact the library office. You can also withdraw your agreement in Settings. That signs you out until you accept again. If you believe your rights were violated, you may file a complaint with the National Privacy Commission (privacy.gov.ph).',
    ),
    LegalSection(
      'Children and minors',
      'If you are under 18, please read this policy together with a parent or guardian before you sign up.',
    ),
    LegalSection(
      'Changes to this policy',
      'We may update this policy. The date and version at the top of this page show the latest one. When something important changes, we will tell you in the app.',
    ),
    LegalSection(
      'Contact',
      'For questions or requests about your information, please contact the library office of Granby Colleges or the BookSlot administrator.',
    ),
  ],
);
