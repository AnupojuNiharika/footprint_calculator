import 'package:flutter/material.dart';

import '../models/app_activity.dart';
import '../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _search = TextEditingController();
  late Future<AdminDashboardData> _dashboard;
  int _section = 0;
  String _query = '';
  String _userRoleFilter = 'ALL';

  static const _sections = [
    ('Overview', Icons.space_dashboard_outlined),
    ('Users', Icons.people_alt_outlined),
    ('Calculations', Icons.co2_outlined),
    ('Activity', Icons.receipt_long_outlined),
    ('Database', Icons.storage_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _dashboard = AuthService.instance.loadAdminDashboard();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _dashboard = AuthService.instance.loadAdminDashboard());
  }

  void _selectSection(int value) {
    setState(() {
      _section = value;
      _query = '';
      _userRoleFilter = 'ALL';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        _sections[_section].$1,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<AdminDashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message: snapshot.error is AuthException
                ? (snapshot.error as AuthException).message
                : 'The local database could not be accessed. Check its availability and retry.',
            onRetry: _reload,
          );
        }

        final data = snapshot.requireData;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = _buildSection(data, constraints.maxWidth);
            if (!wide) {
              return Column(
                children: [
                  Expanded(child: content),
                  NavigationBar(
                    selectedIndex: _section,
                    onDestinationSelected: _selectSection,
                    destinations: [
                      for (final section in _sections)
                        NavigationDestination(
                          icon: Icon(section.$2),
                          label: section.$1,
                        ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _section,
                  onDestinationSelected: _selectSection,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  destinations: [
                    for (final section in _sections)
                      NavigationRailDestination(
                        icon: Icon(section.$2),
                        label: Text(section.$1),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _buildSection(AdminDashboardData data, double availableWidth) {
    switch (_section) {
      case 0:
        return _overview(data, availableWidth);
      case 1:
        return _users(data);
      case 2:
        return _calculations(data);
      case 3:
        return _activities(data);
      case 4:
        return _database(data);
    }
    return const SizedBox.shrink();
  }

  Widget _overview(AdminDashboardData data, double availableWidth) {
    final theme = Theme.of(context);
    final metrics = [
      _Metric('Registered users', '${data.userCount}', Icons.people_outline),
      _Metric(
        'Administrators',
        '${data.adminCount}',
        Icons.admin_panel_settings_outlined,
      ),
      _Metric(
        'Saved calculations',
        '${data.calculationCount}',
        Icons.co2_outlined,
      ),
      _Metric(
        'Recorded activities',
        '${data.activityCount}',
        Icons.bolt_outlined,
      ),
      _Metric(
        'Emissions calculated',
        '${data.totalEmissions.toStringAsFixed(2)} tCO2e',
        Icons.eco_outlined,
      ),
    ];
    final cardWidth = availableWidth >= 1160 ? 205.0 : 240.0;
    return _SectionBody(
      title: 'People and impact',
      subtitle: 'A current view of records in this local Lumen database.',
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(metric: metric),
              ),
          ],
        ),
        const SizedBox(height: 28),
        _Panel(
          title: 'Database status',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'SQLite is accessible. Data shown here is stored on this device or browser.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Recent application activity',
          child: data.activities.isEmpty
              ? const _EmptyState(
                  title: 'No activity recorded yet',
                  message:
                      'Successful account and calculation events will appear here.',
                )
              : Column(
                  children: data.activities
                      .take(5)
                      .map((activity) => _ActivityListTile(activity: activity))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _users(AdminDashboardData data) {
    final query = _query.trim().toLowerCase();
    final users = data.users.where((user) {
      final matchesRole =
          _userRoleFilter == 'ALL' ||
          (_userRoleFilter == 'ADMIN' && user.isAdmin) ||
          (_userRoleFilter == 'USER' && !user.isAdmin);
      final matchesQuery =
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          (user.isAdmin ? 'admin' : 'user').contains(query);
      return matchesRole && matchesQuery;
    }).toList();
    return _SectionBody(
      title: 'User management',
      subtitle: 'Account details only; credentials are never included.',
      children: [
        _searchField('Search name, email, or role'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final role in ['ALL', 'USER', 'ADMIN'])
              FilterChip(
                label: Text(role == 'ALL' ? 'All roles' : role),
                selected: role == _userRoleFilter,
                onSelected: (_) => setState(() => _userRoleFilter = role),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (data.users.isEmpty)
          const _EmptyState(
            title: 'No registered users',
            message: 'Accounts will appear here after successful registration.',
          )
        else if (users.isEmpty)
          const _EmptyState(
            title: 'No matching users',
            message: 'Change the search or role filter and try again.',
          )
        else
          _DataTableCard(
            height: 480,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Registered')),
            ],
            rows: users
                .map(
                  (user) => DataRow(
                    cells: [
                      DataCell(Text(user.name)),
                      DataCell(Text(user.email)),
                      DataCell(_RoleBadge(isAdmin: user.isAdmin)),
                      DataCell(Text(_formatDate(user.registeredAt))),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _calculations(AdminDashboardData data) {
    final query = _query.trim().toLowerCase();
    final calculations = data.calculations.where((item) {
      final calculation = item.calculation;
      return query.isEmpty ||
          (item.userName ?? 'unassigned').toLowerCase().contains(query) ||
          (item.userEmail ?? '').toLowerCase().contains(query) ||
          calculation.date.toLowerCase().contains(query);
    }).toList();
    return _SectionBody(
      title: 'Carbon calculations',
      subtitle:
          'Owner information is shown when present; older unassociated records remain unassigned.',
      children: [
        _searchField('Search user or calculation date'),
        const SizedBox(height: 14),
        if (data.calculations.isEmpty)
          const _EmptyState(
            title: 'No saved calculations',
            message: 'Saved carbon estimates will appear here.',
          )
        else if (calculations.isEmpty)
          const _EmptyState(
            title: 'No matching calculations',
            message: 'Try a different user or date.',
          )
        else
          _DataTableCard(
            height: 500,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Date / time')),
              DataColumn(label: Text('Transport')),
              DataColumn(label: Text('Home energy')),
              DataColumn(label: Text('Food')),
              DataColumn(label: Text('Travel (stored)')),
              DataColumn(label: Text('Total')),
            ],
            rows: calculations
                .map(
                  (record) => DataRow(
                    cells: [
                      DataCell(Text(record.userName ?? 'Unassigned')),
                      DataCell(Text(record.userEmail ?? 'Unavailable')),
                      DataCell(
                        Text(_formatCalculationDate(record.calculation.date)),
                      ),
                      DataCell(
                        Text(_emission(record.calculation.transportEmission)),
                      ),
                      DataCell(
                        Text(_emission(record.calculation.electricityEmission)),
                      ),
                      DataCell(
                        Text(_emission(record.calculation.foodEmission)),
                      ),
                      DataCell(
                        Text(_emission(record.calculation.travelEmission)),
                      ),
                      DataCell(
                        Text(
                          '${record.calculation.totalEmission.toStringAsFixed(2)} tCO2e',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _activities(AdminDashboardData data) {
    final query = _query.trim().toLowerCase();
    final activities = data.activities.where((activity) {
      return query.isEmpty ||
          activity.eventType.toLowerCase().contains(query) ||
          (activity.userName ?? '').toLowerCase().contains(query) ||
          (activity.userEmail ?? '').toLowerCase().contains(query) ||
          (activity.details ?? '').toLowerCase().contains(query);
    }).toList();
    return _SectionBody(
      title: 'Application activity',
      subtitle: 'Successful events recorded by this app installation.',
      children: [
        _searchField('Search event, user, or details'),
        const SizedBox(height: 14),
        if (data.activities.isEmpty)
          const _EmptyState(
            title: 'No application activity',
            message: 'Events are recorded when supported actions succeed.',
          )
        else if (activities.isEmpty)
          const _EmptyState(
            title: 'No matching activity',
            message: 'Try another event type, user, or detail.',
          )
        else
          _DataTableCard(
            height: 500,
            columns: const [
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Timestamp')),
              DataColumn(label: Text('Details')),
            ],
            rows: activities
                .map(
                  (activity) => DataRow(
                    cells: [
                      DataCell(Text(_eventLabel(activity.eventType))),
                      DataCell(Text(activity.userName ?? 'Unavailable')),
                      DataCell(Text(activity.userEmail ?? 'Unavailable')),
                      DataCell(Text(_formatDateTime(activity.occurredAt))),
                      DataCell(Text(activity.details ?? '—')),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _database(AdminDashboardData data) => _SectionBody(
    title: 'Database status',
    subtitle: 'SQLite records available to this local installation.',
    children: [
      _Panel(
        title: 'Connection',
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.databaseAccessible
                    ? 'Database connection is available.'
                    : 'Database connection is unavailable.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _DataTableCard(
        height: 260,
        columns: const [
          DataColumn(label: Text('Table')),
          DataColumn(label: Text('Records')),
          DataColumn(label: Text('Purpose')),
        ],
        rows: [
          DataRow(
            cells: [
              const DataCell(Text('users')),
              DataCell(Text('${data.userCount}')),
              const DataCell(Text('Account profile and role')),
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('carbon_calculations')),
              DataCell(Text('${data.calculationCount}')),
              const DataCell(Text('Saved footprint estimates')),
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('activity_logs')),
              DataCell(Text('${data.activityCount}')),
              const DataCell(Text('Successful app events')),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'Password salts and hashes are deliberately excluded from dashboard queries. Browser SQLite is local to this browser profile; it is not a shared server database.',
        style: TextStyle(color: Colors.black54),
      ),
    ],
  );

  Widget _searchField(String hint) => TextField(
    controller: _search,
    onChanged: (value) => setState(() => _query = value),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
    ),
  );

  String _emission(double value) => '${value.toStringAsFixed(2)} tCO2e';
}

class _Metric {
  const _Metric(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: .06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(metric.icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(
          metric.value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(metric.title, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _DataTableCard extends StatelessWidget {
  const _DataTableCard({
    required this.columns,
    required this.rows,
    required this.height,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: .06)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              Theme.of(context).scaffoldBackgroundColor,
            ),
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? const Color(0xFF1E4620) : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'USER',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActivityListTile extends StatelessWidget {
  const _ActivityListTile({required this.activity});

  final AppActivity activity;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.bolt_outlined),
    title: Text(_eventLabel(activity.eventType)),
    subtitle: Text(
      [
        activity.userName ?? 'Unavailable',
        _formatDateTime(activity.occurredAt),
        if (activity.details != null) activity.details!,
      ].join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 34),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storage_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _eventLabel(String eventType) => switch (eventType) {
  'registration_succeeded' => 'Registration',
  'login_succeeded' => 'Login',
  'logout' => 'Logout',
  'calculation_completed' => 'Calculation completed',
  'calculation_saved' => 'Calculation saved',
  'calculation_deleted' => 'Calculation deleted',
  _ => eventType,
};

String _formatDate(DateTime? date) {
  if (date == null) return 'Unavailable';
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Unavailable';
  return _formatCalculationDate(date.toIso8601String());
}

String _formatCalculationDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final local = date.toLocal();
  final datePart =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final timePart =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$datePart $timePart';
}
