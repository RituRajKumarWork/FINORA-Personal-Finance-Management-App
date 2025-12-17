// main.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() => runApp(const FinoraApp());

class FinoraApp extends StatefulWidget {
  const FinoraApp({super.key});
  @override
  State<FinoraApp> createState() => _FinoraAppState();
}

class _FinoraAppState extends State<FinoraApp> {
  ThemeMode _mode = ThemeMode.dark;
  void toggleTheme() =>
      setState(() => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.poppinsTextTheme();
    return MaterialApp(
      title: 'Finora',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: baseText.apply(bodyColor: Colors.black87),
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black87),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        textTheme: baseText.apply(bodyColor: Colors.white),
        scaffoldBackgroundColor: const Color(0xFF071028),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white),
      ),
      home: HomeShell(themeMode: _mode, onToggleTheme: toggleTheme),
    );
  }
}

// -------------------- Models --------------------

// Made fields non-final so items are editable.
class TransactionItem {
  String title;
  String category;
  DateTime date;
  double amount;
  bool isIncome;
  TransactionItem(this.title, this.category, this.date, this.amount, this.isIncome);

  // Helper to produce CSV row (escaping commas)
  String toCsvRow() {
    String escape(String s) => '"${s.replaceAll('"', '""')}"';
    return '${escape(title)},${escape(category)},${date.toIso8601String()},${amount.toStringAsFixed(2)},${isIncome ? "Income" : "Expense"}';
  }
}

// -------------------- Currency helpers --------------------

enum Currency { usd, inr, eur }

Currency currentCurrency = Currency.usd;

String currencyLabel(Currency c) {
  switch (c) {
    case Currency.usd:
      return 'US Dollar (\$)';
    case Currency.inr:
      return 'Indian Rupee (₹)';
    case Currency.eur:
      return 'Euro (€)';
  }
}

String currencyShort(Currency c) {
  switch (c) {
    case Currency.usd:
      return 'USD';
    case Currency.inr:
      return 'INR';
    case Currency.eur:
      return 'EUR';
  }
}

String get currencySymbol {
  switch (currentCurrency) {
    case Currency.usd:
      return '\$';
    case Currency.inr:
      return '₹';
    case Currency.eur:
      return '€';
  }
}

// Very simple demo conversion rates (base = USD)
double get currencyRate {
  switch (currentCurrency) {
    case Currency.usd:
      return 1.0;
    case Currency.inr:
      return 83.0; // approx
    case Currency.eur:
      return 0.92; // approx
  }
}

String formatAmount(double amount, {int fractionDigits = 2}) {
  final converted = amount * currencyRate;
  return '$currencySymbol${converted.toStringAsFixed(fractionDigits)}';
}

// -------------------- Home Shell --------------------

class HomeShell extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  const HomeShell({super.key, required this.themeMode, required this.onToggleTheme});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  Currency _currency = currentCurrency;

  final List<TransactionItem> _transactions = [
    TransactionItem('Salary', 'Income', DateTime.now().subtract(const Duration(days: 3)), 2553.0, true),
    TransactionItem('Groceries', 'Food', DateTime.now().subtract(const Duration(days: 1)), 64.25, false),
    TransactionItem('Electricity', 'Bills', DateTime.now().subtract(const Duration(days: 5)), 56.40, false),
    TransactionItem('Movie', 'Entertainment', DateTime.now().subtract(const Duration(days: 2)), 12.99, false),
  ];

  void _addTransaction(TransactionItem t) => setState(() => _transactions.insert(0, t));
  void _updateTransaction(int index, TransactionItem updated) => setState(() => _transactions[index] = updated);
  void _deleteTransaction(int index) => setState(() => _transactions.removeAt(index));

  void _onNavTap(int idx) => setState(() => _selectedIndex = idx);

  Map<String, double> get categoryTotals {
    final m = {'Food': 0.0, 'Travel': 0.0, 'Bills': 0.0, 'Entertainment': 0.0, 'Others': 0.0};
    for (final t in _transactions) {
      if (t.isIncome) {
        continue;
      }
      final s = t.category.toLowerCase();
      if (s.contains('food') || s.contains('grocery')) {
        m['Food'] = m['Food']! + t.amount;
      } else if (s.contains('travel')) {
        m['Travel'] = m['Travel']! + t.amount;
      } else if (s.contains('bill')) {
        m['Bills'] = m['Bills']! + t.amount;
      } else if (s.contains('movie')) {
        m['Entertainment'] = m['Entertainment']! + t.amount;
      } else {
        m['Others'] = m['Others']! + t.amount;
      }
    }
    return m;
  }

  double get totalBalance =>
      _transactions.fold(0.0, (p, t) => p + (t.isIncome ? t.amount : -t.amount));
  double get incomeTotal =>
      _transactions.where((t) => t.isIncome).fold(0.0, (p, t) => p + t.amount);
  double get expenseTotal =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (p, t) => p + t.amount);

  @override
  Widget build(BuildContext context) {
    // keep global in sync so all widgets use it
    currentCurrency = _currency;

    final pages = [
      HomePageView(
        transactions: _transactions,
        totalBalance: totalBalance,
        income: incomeTotal,
        expense: expenseTotal,
        categoryTotals: categoryTotals,
        onEditTransaction: (idx) => _showEditTransactionSheet(context, idx),
      ),
      AnalyticsPage(categoryTotals: categoryTotals, transactions: _transactions),
      WalletPage(transactions: _transactions),
      SettingsPage(
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
        onExportData: _exportCsvDialog,
        currency: _currency,
        onCurrencyChanged: (c) {
          setState(() {
            _currency = c;
            currentCurrency = c;
          });
        },
      ),
    ];

    final titles = ['Finora', 'Analytics', 'Wallet', 'Settings'];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.wb_sunny : Icons.dark_mode),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : Colors.black12,
              child: const Icon(Icons.person),
            ),
          )
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add transaction',
        onPressed: () => _showAddTransactionSheet(context),
        backgroundColor: const Color(0xFF6D28D9),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: BottomNav(selectedIndex: _selectedIndex, onTap: _onNavTap),
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(onAdd: (t) {
        _addTransaction(t);
        Navigator.of(context).pop();
      }),
    );
  }

  void _showEditTransactionSheet(BuildContext context, int index) {
    final item = _transactions[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTransactionSheet(
        original: item,
        onSave: (updated) {
          _updateTransaction(index, updated);
          Navigator.of(context).pop();
        },
        onDelete: () {
          _deleteTransaction(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // Export CSV: show a dialog with generated CSV and button to copy it.
  void _exportCsvDialog() {
    final header = '"Title","Category","Date","Amount","Type"';
    final rows = _transactions.map((t) => t.toCsvRow()).toList();
    final csv = [header, ...rows].join('\n');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Export transactions (CSV)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(csv),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              Navigator.of(c).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard. Paste it into a file.')));
            },
            child: const Text('Copy CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(c).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// -------------------- Home Page (Responsive + Scrollable) --------------------

class HomePageView extends StatelessWidget {
  final List<TransactionItem> transactions;
  final double totalBalance, income, expense;
  final Map<String, double> categoryTotals;
  final void Function(int index) onEditTransaction;

  const HomePageView({
    super.key,
    required this.transactions,
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.categoryTotals,
    required this.onEditTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(context, wide: isWide),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 3 : 5,
                    child: Column(
                      children: [
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CategorySummary(
                                categoryTotals: categoryTotals, expenseTotal: expense),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const GlassCard(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: WalletPreview())),
                      ],
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildTransactionsList()),
                  ],
                ],
              ),
              if (!isWide) ...[
                const SizedBox(height: 16),
                _buildTransactionsList(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Fixed top row: stacks vertically when not wide ----------
  Widget _buildTopRow(BuildContext context, {required bool wide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // left card
    final leftCard = GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            formatAmount(totalBalance),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: wide ? 32 : 26,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SummaryStat(label: 'Income', amount: income, positive: true),
            SummaryStat(label: 'Expenses', amount: expense, positive: false),
            SummaryStat(
                label: 'Net', amount: income - expense, positive: income >= expense),
          ])
        ]),
      ),
    );

    final rightCard = GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Spending', style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, c) {
            final h = wide ? 150.0 : 130.0;
            return SizedBox(
              height: h,
              child: Row(
                children: [
                  Flexible(
                      flex: 2,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                              width: h * 0.9,
                              height: h * 0.9,
                              child: CategoryPie(categoryTotals: categoryTotals)))),
                  const SizedBox(width: 8),
                  Flexible(flex: 2, child: _legendList()),
                ],
              ),
            );
          }),
        ]),
      ),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(flex: 2, child: leftCard),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: rightCard),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftCard,
          const SizedBox(height: 12),
          rightCard,
        ],
      );
    }
  }

  Widget _legendList() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categoryTotals.entries.map((e) {
        final color = CategoryPie.palette[
            categoryTotals.keys.toList().indexOf(e.key) % CategoryPie.palette.length];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(e.key, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              formatAmount(e.value, fractionDigits: 0),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ]),
        );
      }).toList());

  Widget _buildTransactionsList() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) => TransactionTile(
              transactions[idx],
              onTap: () => onEditTransaction(idx),
              onDelete: null, // deletion handled in edit sheet
            ),
          ),
        ],
      );
}

// -------------------- Analytics, Wallet, Settings --------------------

class AnalyticsPage extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final List<TransactionItem> transactions;
  const AnalyticsPage({super.key, required this.categoryTotals, required this.transactions});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monthly Overview',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Text(
                            '${formatAmount(transactions.where((t) => !t.isIncome).fold(0.0, (p, t) => p + (t.amount)))} spent',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          )
                        ]))),
            const SizedBox(height: 12),
            GlassCard(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        children: [
                          SizedBox(height: 180, child: CategoryPie(categoryTotals: categoryTotals)),
                          const SizedBox(height: 8),
                          Column(
                              children: categoryTotals.entries.map((e) {
                            final color = CategoryPie.palette[
                                categoryTotals.keys.toList().indexOf(e.key) %
                                    CategoryPie.palette.length];
                            final pct = (e.value /
                                    (categoryTotals.values.fold(0.0, (p, n) => p + n) + 0.0001) *
                                    100)
                                .toStringAsFixed(0);
                            return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(3))),
                                        const SizedBox(width: 8),
                                        Text(e.key),
                                      ]),
                                      Text('$pct%')
                                    ]));
                          }).toList())
                        ]))),
            const SizedBox(height: 100)
          ],
        ),
      );
}

class WalletPage extends StatelessWidget {
  final List<TransactionItem> transactions;
  const WalletPage({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) => Center(
        child: GlassCard(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Wallets', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    WalletCard(name: 'Cash', amount: 120.0),
                    SizedBox(width: 12),
                    WalletCard(name: 'Bank', amount: 2500.0),
                  ]),
                ]))),
      );
}

class SettingsPage extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onExportData;
  final Currency currency;
  final ValueChanged<Currency> onCurrencyChanged;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onExportData,
    required this.currency,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          GlassCard(
            child: ListTile(
              title: const Text('Currency'),
              subtitle: Text(currencyLabel(currency)),
              trailing: DropdownButton<Currency>(
                value: currency,
                underline: const SizedBox.shrink(),
                onChanged: (c) {
                  if (c != null) onCurrencyChanged(c);
                },
                items: Currency.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(currencyShort(c)),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
              child: ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
                  trailing:
                      Switch(value: themeMode == ThemeMode.dark, onChanged: (_) => onToggleTheme()))),
          const SizedBox(height: 12),
          GlassCard(
            child: ListTile(
              title: const Text('Export Data'),
              trailing: const Icon(Icons.download),
              onTap: onExportData,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: ListTile(
              title: const Text('About Finora'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Finora',
                  applicationVersion: '1.0.0',
                  children: [const Text('Personal finance demo')],
                );
              },
            ),
          ),
        ]),
      );
}

// -------------------- Reusable Widgets --------------------

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const BottomNav({super.key, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.black12;
    final activeColor = isDark ? const Color.fromARGB(255, 0, 0, 0) : Colors.black87;
    final inactiveColor = isDark ? const Color.fromARGB(130, 0, 4, 255) : Colors.black54;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  item(
                      icon: Icons.home,
                      idx: 0,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor),
                  item(
                      icon: Icons.bar_chart,
                      idx: 1,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor),
                  const SizedBox(width: 48),
                  item(
                      icon: Icons.account_balance_wallet,
                      idx: 2,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor),
                  item(
                      icon: Icons.settings,
                      idx: 3,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget item({required IconData icon, required int idx, required Color activeColor, required Color inactiveColor}) {
    final active = idx == selectedIndex;
    return GestureDetector(
      onTap: () => onTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: active
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Icon(icon, color: active ? activeColor : inactiveColor),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  const GlassCard({super.key, required this.child, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.8);
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.black12;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: Stack(
        children: [
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Container()),
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: borderRadius ?? BorderRadius.circular(14),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class SummaryStat extends StatelessWidget {
  final String label;
  final double amount;
  final bool positive;
  const SummaryStat({super.key, required this.label, required this.amount, required this.positive});

  @override
  Widget build(BuildContext context) {
    final clr = positive ? Colors.greenAccent : Colors.redAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, color: clr, size: 16),
          const SizedBox(width: 6),
          Text(
            formatAmount(amount),
            style: TextStyle(color: clr, fontWeight: FontWeight.w700),
          )
        ]),
      ],
    );
  }
}

// -------------------- Transaction Tile (now tappable for edit) --------------------

class TransactionTile extends StatelessWidget {
  final TransactionItem t;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const TransactionTile(this.t, {this.onTap, this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    final color = t.isIncome ? Colors.greenAccent : Colors.redAccent;
    final formatted = formatAmount(t.amount);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(iconForCategory(t.category), color: color, size: 18),
          ),
          title: Row(
            children: [
              Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: Colors.grey),
            ],
          ),
          subtitle: Text('${t.category} • ${shortDate(t.date)}'),
          trailing: Text(
            '${t.isIncome ? '+' : '-'} $formatted',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  IconData iconForCategory(String c) {
    final s = c.toLowerCase();
    if (s.contains('food')) {
      return Icons.fastfood;
    }
    if (s.contains('travel') || s.contains('flight')) {
      return Icons.flight;
    }
    if (s.contains('bill') || s.contains('electric')) {
      return Icons.receipt_long;
    }
    if (s.contains('movie')) {
      return Icons.movie;
    }
    if (s.contains('salary') || s.contains('income')) {
      return Icons.attach_money;
    }
    return Icons.category;
  }

  String shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// -------------------- WalletCard / Pie / CategorySummary --------------------

class WalletCard extends StatelessWidget {
  final String name;
  final double amount;
  const WalletCard({super.key, required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black87;
    return GlassCard(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 6),
            Text(
              formatAmount(amount),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryPie extends StatelessWidget {
  final Map<String, double> categoryTotals;
  static const palette = [
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.orangeAccent,
    Colors.amberAccent,
    Colors.lightBlueAccent
  ];

  const CategoryPie({super.key, required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList();
    final total = entries.fold(0.0, (p, e) => p + e.value);
    final sections = <PieChartSectionData>[];

    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final pct = total <= 0 ? 0.0 : (value / total) * 100;
      final color = palette[i % palette.length];
      if (value <= 0) {
        sections.add(PieChartSectionData(
            value: 0.0001, color: color.withOpacity(0.15), radius: 18, showTitle: false));
      } else {
        sections.add(PieChartSectionData(
          value: value,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 34,
          titleStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          color: color,
        ));
      }
    }

    return PieChart(PieChartData(
        sections: sections,
        centerSpaceRadius: 18,
        sectionsSpace: 6,
        borderData: FlBorderData(show: false)));
  }
}

class CategorySummary extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final double expenseTotal;
  const CategorySummary({super.key, required this.categoryTotals, required this.expenseTotal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spending by category', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          '${formatAmount(expenseTotal)} spent',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 120, child: CategoryPie(categoryTotals: categoryTotals)),
      ],
    );
  }
}

// -------------------- Add Transaction Sheet --------------------

class AddTransactionSheet extends StatefulWidget {
  final void Function(TransactionItem) onAdd;
  const AddTransactionSheet({super.key, required this.onAdd});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final amount0 = TextEditingController();
  String category = 'Others';
  bool isIncome = false;

  @override
  void dispose() {
    title.dispose();
    amount0.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final amount = double.tryParse(amount0.text) ?? 0.0;
    final item = TransactionItem(title.text.trim(), category, DateTime.now(), amount, isIncome);
    widget.onAdd(item);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration:
                  BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Add transaction', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))
            ]),
            const SizedBox(height: 8),
            TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter title' : null),
            const SizedBox(height: 8),
            TextFormField(
              controller: amount0,
              decoration: InputDecoration(labelText: 'Amount', prefixText: currencySymbol),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: category,
                items: ['Food', 'Travel', 'Bills', 'Entertainment', 'Others']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? 'Others'),
                decoration: const InputDecoration(labelText: 'Category'),
              )),
              const SizedBox(width: 12),
              Column(children: [
                const Text('Income'),
                Switch(value: isIncome, onChanged: (v) => setState(() => isIncome = v))
              ])
            ]),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: submit,
                    child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12), child: Text('Add')))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// -------------------- Edit Transaction Sheet --------------------

class EditTransactionSheet extends StatefulWidget {
  final TransactionItem original;
  final void Function(TransactionItem) onSave;
  final VoidCallback onDelete;
  const EditTransactionSheet({super.key, required this.original, required this.onSave, required this.onDelete});

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController title;
  late TextEditingController amount0;
  late String category;
  late bool isIncome;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.original.title);
    amount0 = TextEditingController(text: widget.original.amount.toStringAsFixed(2));
    category = widget.original.category;
    isIncome = widget.original.isIncome;
    date = widget.original.date;
  }

  @override
  void dispose() {
    title.dispose();
    amount0.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final amount = double.tryParse(amount0.text) ?? 0.0;
    final updated = TransactionItem(title.text.trim(), category, date, amount, isIncome);
    widget.onSave(updated);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration:
                  BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Edit transaction', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))
            ]),
            const SizedBox(height: 8),
            TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter title' : null),
            const SizedBox(height: 8),
            TextFormField(
              controller: amount0,
              decoration: InputDecoration(labelText: 'Amount', prefixText: currencySymbol),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: category,
                items: ['Food', 'Travel', 'Bills', 'Entertainment', 'Others', 'Income']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? 'Others'),
                decoration: const InputDecoration(labelText: 'Category'),
              )),
            const SizedBox(width: 12),
              Column(children: [
                const Text('Income'),
                Switch(value: isIncome, onChanged: (v) => setState(() => isIncome = v))
              ])
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Date: ${date.day}/${date.month}/${date.year}'),
                const SizedBox(width: 12),
                TextButton(onPressed: pickDate, child: const Text('Change date'))
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                      onPressed: submit,
                      child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12), child: Text('Save'))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    // confirm delete
                    showDialog(
                        context: context,
                        builder: (d) => AlertDialog(
                              title: const Text('Delete transaction?'),
                              content: const Text('This action cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(d).pop();
                                      widget.onDelete();
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ));
                  },
                  child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12), child: Text('Delete')),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// -------------------- WalletPreview --------------------

class WalletPreview extends StatelessWidget {
  const WalletPreview({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wallets', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        WalletCard(name: 'Main', amount: 2435.75),
        SizedBox(height: 8),
        WalletCard(name: 'Personal', amount: 120.0),
      ],
    );
  }
}