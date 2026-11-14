import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'user_forms.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/status_chip.dart';
import 'user_detail_screen.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _statusFilter = 'all';

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
              child: Row(
                children: [
                  Text('Status', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'suspended',
                            child: Text('Suspended'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'all'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _UserList(role: 'student', statusFilter: _statusFilter),
                  _UserList(role: 'librarian', statusFilter: _statusFilter),
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
  const _UserList({required this.role, required this.statusFilter});

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
        final users = widget.statusFilter == 'all'
            ? all
            : all.where((u) => u.status == widget.statusFilter).toList();
        if (users.isEmpty) {
          return Center(
            child: Text(
              widget.statusFilter == 'all'
                  ? 'No ${widget.role}s yet'
                  : 'No ${widget.statusFilter} ${widget.role}s',
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
