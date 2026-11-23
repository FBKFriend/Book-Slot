# BookSlot

**A mobile library system for Granby Colleges.**
Students browse and reserve books from their phones, librarians hand books over and take them back with QR codes, and the administrator keeps an eye on everything through reports and audit logs.

![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

### Students
- **Sign up with Google.** Students register with their own details and wait for the administrator to approve the account.
- **Preferred genres.** On the first login a student can pick favorite genres (optional) and change them later in Settings.
- **Menu.** A sideways-scrolling *Recommended for you* row (based on preferred genres) above the full book catalog.
- **Search.** Search by title, author, ID or genre, filter by genre, and sort by title, newest or availability.
- **Book details and reservations.** See live stock and reserve a book with one tap.
- **My Library.** Current reservations (pending ones can be cancelled), a **pickup QR code** once a reservation is approved, and borrowed books with due dates and a **return QR code**.
- **Alerts.** In-app notifications when a reservation is accepted, denied, expired or dropped.
- **History.** Every reservation and borrow, with status and date filters.
- **Terms of Service and Privacy Policy** acceptance.

### Librarians
- **Dashboard.** Books, copies, borrowed now, overdue, pending requests, books waiting for pickup, and today's borrows and returns.
- **Book management.** Add, edit and delete books with covers, genres, publication year and number of copies.
- **QR scanner.** Scan a student's pickup or return QR code, check the book and student on a confirmation sheet, and confirm.
- **Borrowing and reservations.** Accept or deny requests, see what is waiting for pickup and what is currently borrowed.
- **Transaction history.** A searchable log of every borrow and return.

### Administrator (superadmin)
- **System dashboard.** Registered students, librarians, books, active and overdue borrowings, and borrows this month.
- **User management.** Approve or reject registrations, edit information, suspend or reactivate accounts, add librarians and change roles.
- **Reports and analytics.** Borrowing activity chart, most borrowed books, popular genres, most active readers, borrows by course, pickup rate, late returns, average days kept and reservation outcomes, for any period.
- **Audit logs.** Every important action (accounts, settings, books, reservations, borrowing), filterable and printable as a PDF.
- **System settings.** Borrowing duration, maximum books at once, reservation pickup deadline and maximum active reservations.

---

## How borrowing works

1. A student **reserves** a book. It shows up as a pending request for the librarian.
2. The librarian **accepts** (a copy is held for the student) or **denies** the request. The student gets an alert either way.
3. An accepted reservation shows a **pickup QR code** in the student's Library tab. The student has a limited number of days to collect the book.
4. The librarian **scans the QR code** at the desk. The stock goes down and the borrowing starts with a due date.
5. If the last copy was taken, other pending requests for that book are dropped and those students are notified.
6. To return the book, the student shows a **return QR code**. The librarian scans it and the stock goes back up.
7. Every borrow and return is logged in the History tab and used by the reports.

Reservations that are not collected in time expire automatically when the librarian opens the Borrowing tab.

---

## Tech stack

| Area | Technology |
|---|---|
| App | Flutter (Dart), Material 3, Android |
| Sign-in | Firebase Authentication with Google Sign-In |
| Database | Cloud Firestore (live streams and transactions) |
| QR codes | `qr_flutter` (generate) and `mobile_scanner` (scan) |
| PDF export | `pdf` and `printing` |
| Images | `image_picker` and `image` (book covers) |
| Look and feel | `google_fonts` (Playfair Display and Inter), `flutter_svg` |

---

## Project structure

```
lib/
├── main.dart              App entry point
├── app_info.dart          App name and version
├── data/                  Fixed lists (genres)
├── models/                Plain data classes (users, books, reservations, ...)
├── services/              All Firestore and auth logic
├── theme/                 Colors and the dark theme
├── utils/                 Date ranges and formatting helpers
├── widgets/               Shared widgets (book cover, genre picker, QR sheet, ...)
└── screens/
    ├── student/           Menu, Search, Library, Alerts, Settings, History
    ├── librarian/         Dashboard, Books, QR Scanner, Borrowing, History
    └── superadmin/        Dashboard, Users, Reports, Audit, Settings
```

---

## Firestore data model

| Collection | What it stores |
|---|---|
| `users` | One document per account (the ID is the email): role, status, profile and preferred genres |
| `books` | The catalog: title, author, genres, `totalCopies`, `availableCopies`, `reservedCopies` |
| `bookCovers` | Cover pictures, kept in a separate collection so the catalog stays light |
| `counters` | Counter for book IDs (`BK-0001`, `BK-0002`, ...) |
| `settings` | System rules in `settings/system` (borrow days, limits, pickup deadline) |
| `reservations` | A student's request and its whole life: pending, accepted, picked up, returned, denied, expired, dropped, cancelled |
| `borrowings` | One document per borrow, with due date and return date |
| `transactions` | Borrow and return events, used by the History tab and the reports |
| `notifications` | In-app alerts for students |
| `auditLogs` | Who did what and when |

Access is controlled by Firestore security rules. Students can only read their own reservations and alerts, and only staff can change the catalog or handle borrowing.

---

## Known limitations

- Android only.
- Notifications are in-app only (no push notifications).
- Expired reservations are cleaned up when a librarian opens the Borrowing tab, because the project does not use Cloud Functions.
- There are no fines or overdue reminders yet. Overdue books are only flagged.

---

## License

Released under the [MIT License](LICENSE).

## Author

Built by **Denmark** ([@FBKFriend](https://github.com/FBKFriend)) as a capstone project for Granby Colleges.
