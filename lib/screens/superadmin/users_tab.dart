import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/status_chip.dart';
import 'user_detail_screen.dart';
import 'user_forms.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _search = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          actions: [
            IconButton(
              tooltip: 'Add authorized account',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showAddLibrarianSheet(context),
            ),
            if (kDebugMode)
              IconButton(
                tooltip: 'Add sample students (testing)',
                icon: const Icon(Icons.science_outlined),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await UserService.instance.seedSampleStudents();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Added sample students')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Seeding failed: $e')),
                    );
                  }
                },
              ),
          ],
          bottom: const TabBar(
            dividerColor: AppColors.border,
            tabs: [
              Tab(text: 'Students'),
              Tab(text: 'Librarians'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search name, email, or student ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterDropdown(
                  label: 'Status',
                  value: _statusFilter,
                  options: const {
                    'all': 'All',
                    'pending': 'Pending',
                    'active': 'Active',
                    'suspended': 'Suspended',
                  },
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _UserList(
                    role: 'student',
                    statusFilter: _statusFilter,
                    query: _query,
                  ),
                  _UserList(
                    role: 'librarian',
                    statusFilter: _statusFilter,
                    query: _query,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatefulWidget {
  final String role;
  final String statusFilter;
  final String query;
  const _UserList({
    required this.role,
    required this.statusFilter,
    required this.query,
  });

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<AppUser>> _stream = UserService.instance
      .watchUsersByRole(widget.role);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Could not load users.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data!;
        final q = widget.query.trim().toLowerCase();
        final users = all.where((u) {
          final statusOk =
              widget.statusFilter == 'all' || u.status == widget.statusFilter;
          final textOk =
              q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.studentId ?? '').toLowerCase().contains(q);
          return statusOk && textOk;
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Text(
              all.isEmpty
                  ? 'No ${widget.role}s yet'
                  : 'No ${widget.role}s match your search',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _UserCard(user: users[i]),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = user.name.isEmpty ? user.email : user.name;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDetailScreen(email: user.email),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background,
                child: Text(
                  title.characters.first.toUpperCase(),
                  style: const TextStyle(color: AppColors.gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(status: user.status),
            ],
          ),
        ),
      ),
    );
  }
}
