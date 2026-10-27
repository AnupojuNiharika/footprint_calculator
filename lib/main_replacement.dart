import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'widgets/eco_illustration.dart';

const ink = Color.fromARGB(255, 95, 6, 43);
const coral = Color.fromARGB(255, 113, 97, 255);
const gold = Color(0xFFF59E0B);
const paper = Color(0xFFF4F9F6);
const muted = Color.fromARGB(255, 182, 35, 145);

void main() => runApp(const CarbonApp());

class CarbonApp extends StatelessWidget {
  const CarbonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lumen Footprint',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: coral),
      fontFamily: 'Arial',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ink.withValues(alpha: .08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: coral, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: coral.withValues(alpha: .10),
      ),
    ),
    home: const PortfolioPage(),
  );
}

class FootprintRecord {
  FootprintRecord({
    required this.name,
    required this.total,
    required this.date,
    this.id,
  });

  final int? id;
  final String name;
  final double total;
  final String date;

  Map<String, Object?> toMap() => {'name': name, 'total': total, 'date': date};
}

class FootprintRepository {
  Database? _database;
  final List<FootprintRecord> _fallback = [
    FootprintRecord(name: 'Demo household', total: 4.8, date: 'Sep 16, 2026'),
  ];

  Future<Database?> get database async {
    if (_database != null) return _database;
    try {
      _database = await openDatabase(
        p.join(await getDatabasesPath(), 'lumen_footprint.db'),
        version: 1,
        onCreate: (db, version) => db.execute(
          'CREATE TABLE calculations(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, total REAL, date TEXT)',
        ),
      );
      return _database;
    } catch (_) {
      return null;
    }
  }

  Future<List<FootprintRecord>> all() async {
    final db = await database;
    if (db == null) return List.of(_fallback.reversed);
    final rows = await db.query('calculations', orderBy: 'id DESC');
    if (rows.isEmpty) {
      await add(_fallback.first);
      final refreshed = await db.query('calculations', orderBy: 'id DESC');
      return refreshed.map((row) => FootprintRecord(
        name: row['name'] as String,
        total: (row['total'] as num).toDouble(),
        date: row['date'] as String,
        id: row['id'] as int,
      )).toList();
    }
    return rows.map((row) => FootprintRecord(
      name: row['name'] as String,
      total: (row['total'] as num).toDouble(),
      date: row['date'] as String,
      id: row['id'] as int,
    )).toList();
  }

  Future<void> add(FootprintRecord record) async {
    final db = await database;
    if (db == null) {
      _fallback.add(record);
      return;
    }
    await db.insert('calculations', record.toMap());
  }
}

final repository = FootprintRepository();

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(child: Container(color: ink)),
        Positioned(right: -80, top: -60, child: _orb(240, coral.withValues(alpha: .22))),
        Positioned(left: -90, bottom: -100, child: _orb(260, gold.withValues(alpha: .16))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Brand(color: Colors.white),
                    SizedBox(height: wide ? 100 : 64),
                    FadeTransition(
                      opacity: _intro,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .12), end: Offset.zero).animate(
                          CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic),
                        ),
                        child: wide ? _wideHero(context) : _compactHero(context),
                      ),
                    ),
                    const SizedBox(height: 68),
                    const Text(
                      'A clearer view of your impact',
                      style: TextStyle(color: Colors.white, fontSize: 15, letterSpacing: .4),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _Feature(icon: Icons.insights_rounded, title: 'See the pattern', text: 'Turn everyday choices into a useful picture.'),
                        _Feature(icon: Icons.auto_awesome_rounded, title: 'Make one change', text: 'Small shifts become visible and achievable.'),
                        _Feature(icon: Icons.lock_outline_rounded, title: 'Keep it yours', text: 'Your history stays in your local database.'),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'LUMEN / 2026',
                      style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 11, letterSpacing: 2),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _wideHero(BuildContext context) => Row(
    children: [
      Expanded(child: _heroCopy(context)),
      const SizedBox(width: 48),
      const Expanded(child: _HeroImage()),
    ],
  );

  Widget _compactHero(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heroCopy(context),
      const SizedBox(height: 36),
      const _HeroImage(),
    ],
  );

  Widget _heroCopy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'YOUR FOOTPRINT,\nIN FOCUS.',
        style: TextStyle(
          color: Colors.white,
          fontSize: MediaQuery.sizeOf(context).width > 760 ? 58 : 43,
          height: .98,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
      ),
      const SizedBox(height: 22),
      Text(
        'A thoughtful way to understand the carbon behind your everyday life. No judgement. Just a little more clarity.',
        style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 17, height: 1.5),
      ),
      const SizedBox(height: 32),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => _openAuth(context, false),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Start exploring'),
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            ),
          ),
          OutlinedButton(
            onPressed: () => _openAuth(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .3)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            ),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    ],
  );

  void _openAuth(BuildContext context, bool login) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AuthPage(showLogin: login)),
  );

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.blur_on_rounded, color: coral, size: 30),
      const SizedBox(width: 10),
      Text(
        'lumen',
        style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: 1.5),
      ),
      const Spacer(),
      Text(
        'CARBON COMPANION',
        style: TextStyle(color: color.withValues(alpha: .5), fontSize: 10, letterSpacing: 2),
      ),
    ],
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 218,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: gold, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(
                text,
                style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) => Container(
    height: 290,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const EcoIllustration(scene: EcoScene.landscape),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: ink.withValues(alpha: .42),
          ),
        ),
        const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text(
              'Notice the world\naround you.',
              style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w700, height: 1.05),
            ),
          ),
        ),
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.showLogin = true});
  final bool showLogin;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool login = widget.showLogin;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(height: 26),
                const _Brand(color: ink),
                const SizedBox(height: 24),
                SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: EcoIllustration(scene: login ? EcoScene.landscape : EcoScene.food),
                  ),
                ),
                const SizedBox(height: 50),
                Text(
                  login ? 'Welcome back.' : 'Make it count.',
                  style: const TextStyle(color: ink, fontSize: 38, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  login ? 'Your personal footprint, right where you left it.' : 'Create a private space to track your progress.',
                  style: const TextStyle(color: muted, fontSize: 16),
                ),
                const SizedBox(height: 32),
                if (!login) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => DashboardPage(userName: name.text.isEmpty ? 'Alex' : name.text)),
                    ),
                    style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.symmetric(vertical: 17)),
                    child: Text(login ? 'Log in' : 'Create account'),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => login = !login),
                    child: Text(login ? 'New here? Create an account' : 'Already have an account? Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.userName});
  final String userName;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int tab = 0;
  List<FootprintRecord> records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    records = await repository.all();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _Overview(name: widget.userName, records: records, onCalculate: () => setState(() => tab = 1)),
      CalculatorPage(onSaved: _load),
      HistoryPage(records: records, onRefresh: _load),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: const _Brand(color: ink),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.add_chart_outlined), selectedIcon: Icon(Icons.add_chart_rounded), label: 'Calculate'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.name, required this.records, required this.onCalculate});
  final String name;
  final List<FootprintRecord> records;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    final latest = records.isEmpty ? 0.0 : records.first.total;
    final average = records.isEmpty ? 0.0 : records.fold<double>(0, (sum, item) => sum + item.total) / records.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good to see you, $name.', style: const TextStyle(color: ink, fontSize: 27, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Here is the shape of your impact today.', style: TextStyle(color: muted, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: const EcoIllustration(scene: EcoScene.landscape),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 142,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: const EcoIllustration(scene: EcoScene.landscape),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('YOUR LATEST FOOTPRINT', style: TextStyle(color: gold, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(latest.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, left: 8),
                    child: Text('tCO₂e / year', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: (latest / 8).clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFF35405A), color: coral),
              ),
              const SizedBox(height: 12),
              const Text('A strong baseline for your sustainable choices.', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _Metric(title: 'Calculations', value: '${records.length}', icon: Icons.receipt_long_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _Metric(title: 'Average', value: average == 0 ? '0.0' : average.toStringAsFixed(1), icon: Icons.bar_chart_rounded)),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onCalculate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Run a new calculation'),
          style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.symmetric(vertical: 17)),
        ),
        const SizedBox(height: 30),
        const Text('HOW IT WORKS', style: TextStyle(color: muted, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        const _Step(number: '01', title: 'Answer a few questions', text: 'Travel, home energy and diet are all part of your footprint.'),
        const _Step(number: '02', title: 'See your baseline', text: 'Review the yearly estimate before saving it to history.'),
        const _Step(number: '03', title: 'Track your progress', text: 'Return anytime to compare changes and keep learning.'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: coral),
        const SizedBox(height: 15),
        Text(value, style: const TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
        Text(title, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});
  final String number, title, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: const TextStyle(color: coral, fontWeight: FontWeight.w800)),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: muted, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

enum TravelMode { car, bike, bus, train, walk }
enum DietType { vegetarian, mixed, meat }

class CarbonInput {
  const CarbonInput({
    required this.travelMode,
    required this.dailyDistanceKm,
    required this.monthlyElectricityUnits,
    required this.dietType,
  });

  final TravelMode travelMode;
  final double dailyDistanceKm;
  final double monthlyElectricityUnits;
  final DietType dietType;
}

class CarbonBreakdown {
  CarbonBreakdown({
    required this.transportEmission,
    required this.electricityEmission,
    required this.foodEmission,
  });

  final double transportEmission;
  final double electricityEmission;
  final double foodEmission;

  double get totalEmission => transportEmission + electricityEmission + foodEmission;
}

class CarbonCalculatorService {
  CarbonBreakdown calculate(CarbonInput input) {
    final transport = _calculateTransport(input.travelMode, input.dailyDistanceKm);
    final electricity = _calculateElectricity(input.monthlyElectricityUnits);
    final food = _calculateFood(input.dietType);
    return CarbonBreakdown(
      transportEmission: transport,
      electricityEmission: electricity,
      foodEmission: food,
    );
  }

  double _calculateTransport(TravelMode mode, double distanceKm) {
    final safeDistance = distanceKm.clamp(0.0, 200.0);
    switch (mode) {
      case TravelMode.car:
        return (safeDistance * 365.0 * 0.00019).clamp(0.0, 12.0);
      case TravelMode.bike:
        return 0.08;
      case TravelMode.bus:
        return (safeDistance * 365.0 * 0.00010).clamp(0.0, 8.0);
      case TravelMode.train:
        return (safeDistance * 365.0 * 0.00013).clamp(0.0, 8.0);
      case TravelMode.walk:
        return 0.03;
    }
  }

  double _calculateElectricity(double monthlyUnits) {
    final safeUsage = monthlyUnits.clamp(0.0, 5000.0);
    return (safeUsage * 12.0 * 0.00095).clamp(0.0, 20.0);
  }

  double _calculateFood(DietType diet) {
    switch (diet) {
      case DietType.vegetarian:
        return 0.9;
      case DietType.mixed:
        return 1.6;
      case DietType.meat:
        return 2.8;
    }
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.onSaved});
  final Future<void> Function() onSaved;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final CarbonCalculatorService _calculator = CarbonCalculatorService();
  final distanceController = TextEditingController(text: '10');
  final electricityController = TextEditingController(text: '150');

  int step = 0;
  TravelMode? selectedTravelMode;
  DietType? selectedDiet;
  CarbonBreakdown? currentBreakdown;
  bool saving = false;

  @override
  void dispose() {
    distanceController.dispose();
    electricityController.dispose();
    super.dispose();
  }

  double _parseDistance() {
    final value = double.tryParse(distanceController.text.trim());
    return value ?? -1;
  }

  double _parseElectricity() {
    final value = double.tryParse(electricityController.text.trim());
    return value ?? -1;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: ink),
    );
  }

  void _validateAndMoveNext() {
    if (step == 0) {
      if (selectedTravelMode == null) {
        _showError('Please choose your usual travel method.');
        return;
      }
      if (_parseDistance() <= 0) {
        _showError('Please enter your daily travel distance.');
        return;
      }
      setState(() => step = 1);
      return;
    }

    if (step == 1) {
      if (_parseElectricity() <= 0) {
        _showError('Please enter your electricity usage.');
        return;
      }
      setState(() => step = 2);
      return;
    }

    if (selectedDiet == null) {
      _showError('Please select your usual diet.');
      return;
    }

    _calculateResult();
  }

  void _calculateResult() {
    final travelMode = selectedTravelMode;
    final diet = selectedDiet;
    if (travelMode == null || diet == null) {
      _showError('Please complete all required answers before calculating.');
      return;
    }

    final input = CarbonInput(
      travelMode: travelMode,
      dailyDistanceKm: _parseDistance(),
      monthlyElectricityUnits: _parseElectricity(),
      dietType: diet,
    );

    setState(() {
      currentBreakdown = _calculator.calculate(input);
      step = 3;
    });
  }

  Future<void> _saveEstimate() async {
    final result = currentBreakdown;
    if (result == null) return;

    setState(() => saving = true);
    await repository.add(
      FootprintRecord(
        name: 'Baseline estimate',
        total: result.totalEmission,
        date: _formatDate(DateTime.now()),
      ),
    );
    await widget.onSaved();
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to your local history.'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        if (step < 3) ...[
          const Text('Let’s understand your footprint', style: TextStyle(color: ink, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Answer a few simple questions to estimate your yearly carbon impact.', style: TextStyle(color: muted, fontSize: 15)),
          const SizedBox(height: 24),
          _ProgressHeader(currentStep: step, totalSteps: 3),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _buildStep(step),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _validateAndMoveNext,
              style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(step == 2 ? 'Calculate my footprint' : 'Continue'),
            ),
          ),
        ] else ...[
          _ResultCard(
            breakdown: currentBreakdown ?? CarbonBreakdown(transportEmission: 0, electricityEmission: 0, foodEmission: 0),
            onSave: _saveEstimate,
            saving: saving,
          ),
        ],
      ],
    );
  }

  Widget _buildStep(int index) {
    switch (index) {
      case 0:
        return _TravelStep(
          key: const ValueKey('travel'),
          selectedMode: selectedTravelMode,
          onModeSelected: (mode) => setState(() => selectedTravelMode = mode),
          distanceController: distanceController,
        );
      case 1:
        return _HomeStep(
          key: const ValueKey('home'),
          controller: electricityController,
        );
      case 2:
        return _FoodStep(
          key: const ValueKey('food'),
          selectedDiet: selectedDiet,
          onDietSelected: (diet) => setState(() => selectedDiet = diet),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Step ${currentStep + 1} of $totalSteps', style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .4)),
      const SizedBox(height: 12),
      Row(
        children: List.generate(totalSteps, (index) {
          final active = index <= currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.only(right: 6),
              height: 6,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: active ? coral : const Color(0xFFE6EDE7)),
            ),
          );
        }),
      ),
    ],
  );
}

class _TravelStep extends StatelessWidget {
  const _TravelStep({super.key, required this.selectedMode, required this.onModeSelected, required this.distanceController});
  final TravelMode? selectedMode;
  final ValueChanged<TravelMode> onModeSelected;
  final TextEditingController distanceController;

  @override
  Widget build(BuildContext context) {
    final options = [
      _ChoiceOption(icon: '🚗', title: 'Car', value: TravelMode.car),
      _ChoiceOption(icon: '🏍', title: 'Bike', value: TravelMode.bike),
      _ChoiceOption(icon: '🚌', title: 'Bus', value: TravelMode.bus),
      _ChoiceOption(icon: '🚆', title: 'Train', value: TravelMode.train),
      _ChoiceOption(icon: '🚶', title: 'Walk', value: TravelMode.walk),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionHeader(icon: '🚗', title: 'Getting around'),
        const SizedBox(height: 18),
        const Text('How do you usually travel?', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: options.map((option) {
            final selected = selectedMode == option.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: selected ? coral.withValues(alpha: .10) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? coral : const Color(0xFFE4E9E5), width: selected ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onModeSelected(option.value),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(option.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(option.title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('How far do you travel per day?', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(
          controller: distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Daily travel distance', suffixText: 'km'),
        ),
        const SizedBox(height: 8),
        const Text('Approximate daily distance is enough.', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 18),
        SizedBox(height: 116, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: const EcoIllustration(scene: EcoScene.travel))),
      ],
    );
  }
}

class _HomeStep extends StatelessWidget {
  const _HomeStep({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _QuestionHeader(icon: '🏠', title: 'At home'),
      const SizedBox(height: 18),
      const Text('How much electricity do you use?', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Monthly electricity usage', suffixText: 'units/month'),
      ),
      const SizedBox(height: 8),
      const Text('Check your electricity bill for an approximate value.', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      SizedBox(height: 140, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: const EcoIllustration(scene: EcoScene.home))),
    ],
  );
}

class _FoodStep extends StatelessWidget {
  const _FoodStep({super.key, required this.selectedDiet, required this.onDietSelected});
  final DietType? selectedDiet;
  final ValueChanged<DietType> onDietSelected;

  @override
  Widget build(BuildContext context) {
    final options = [
      _DietOption(icon: '🥗', title: 'Mostly vegetarian', description: 'Vegetables, grains and plant-based foods', value: DietType.vegetarian),
      _DietOption(icon: '🍲', title: 'Mixed diet', description: 'A combination of plant and animal foods', value: DietType.mixed),
      _DietOption(icon: '🥩', title: 'Meat frequently', description: 'Meat is included regularly', value: DietType.meat),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionHeader(icon: '🍴', title: 'What you eat'),
        const SizedBox(height: 18),
        const Text('What best describes your usual diet?', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        ...options.map((option) {
          final selected = selectedDiet == option.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: selected ? gold.withValues(alpha: .12) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? gold : const Color(0xFFE4E9E5), width: selected ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onDietSelected(option.value),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(option.icon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(option.description, style: const TextStyle(color: muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        SizedBox(height: 120, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: const EcoIllustration(scene: EcoScene.food))),
      ],
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.icon, required this.title});
  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _ChoiceOption {
  const _ChoiceOption({required this.icon, required this.title, required this.value});
  final String icon;
  final String title;
  final TravelMode value;
}

class _DietOption {
  const _DietOption({required this.icon, required this.title, required this.description, required this.value});
  final String icon;
  final String title;
  final String description;
  final DietType value;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.breakdown, required this.onSave, required this.saving});
  final CarbonBreakdown breakdown;
  final Future<void> Function() onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CategoryResultCard(title: '🚗 Getting around', value: breakdown.transportEmission),
      _CategoryResultCard(title: '🏠 At home', value: breakdown.electricityEmission),
      _CategoryResultCard(title: '🍴 What you eat', value: breakdown.foodEmission),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Your baseline', style: TextStyle(color: ink, fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text("Here's a snapshot of the things that shape your footprint.", style: TextStyle(color: muted, fontSize: 15)),
        const SizedBox(height: 24),
        ...cards,
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: gold.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your estimate', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    AnimatedNumber(value: breakdown.totalEmission, suffix: 'tonnes per year'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 64, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: const EcoIllustration(scene: EcoScene.landscape))),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: saving ? null : () async => onSave(),
            style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(saving ? 'Saving...' : 'Save this estimate'),
          ),
        ),
      ],
    );
  }
}

class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber({super.key, required this.value, required this.suffix});
  final double value;
  final String suffix;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _animation = Tween<double>(begin: 0, end: widget.value).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) => Text(
      '${_animation.value.toStringAsFixed(1)} ${widget.suffix}',
      style: const TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
    ),
  );
}

class _CategoryResultCard extends StatelessWidget {
  const _CategoryResultCard({required this.title, required this.value});
  final String title;
  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value / 8.0).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6EDE7))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15))),
              Text('${value.toStringAsFixed(1)} tCO₂e', style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 8,
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFFE8EFEA)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: percent * 260,
                  height: 8,
                  decoration: const BoxDecoration(color: coral),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.records, required this.onRefresh});
  final List<FootprintRecord> records;
  final Future<void> Function() onRefresh;

  Future<void> _deleteRecord(BuildContext context, FootprintRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete estimate'),
        content: const Text('This saved record will be removed from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: coral), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || record.id == null) return;
    final db = await repository.database;
    await db?.delete('calculations', where: 'id = ?', whereArgs: [record.id]);
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estimate deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
    children: [
      const Text('History', style: TextStyle(color: ink, fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('Your saved estimates stay private and available on this device.', style: TextStyle(color: muted)),
      const SizedBox(height: 25),
      if (records.isEmpty)
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Column(
            children: [
              SizedBox(height: 140, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: const EcoIllustration(scene: EcoScene.history))),
              const SizedBox(height: 16),
              const Text('No saved estimates yet', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Your first Baseline estimate will appear here.', style: TextStyle(color: muted)),
            ],
          ),
        )
      else ...[
        ...records.map((record) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: coral.withValues(alpha: .12), shape: BoxShape.circle),
                child: const Icon(Icons.eco_outlined, color: coral),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.date, style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${record.total.toStringAsFixed(1)} tonnes CO₂e/year', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              IconButton(onPressed: () => _deleteRecord(context, record), icon: const Icon(Icons.delete_outline_rounded, color: ink)),
            ],
          ),
        )),
      ],
    ],
  );
}
