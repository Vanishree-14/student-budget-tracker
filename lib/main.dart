import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class Expense {
  final String title;
  final double amount;
  final String category;
  Expense(this.title, this.amount, this.category);

  Map<String, dynamic> toMap() =>
      {'title': title, 'amount': amount, 'category': category};

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        m['title'] as String,
        (m['amount'] as num).toDouble(),
        m['category'] as String,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> expenses = [];
  final List<String> categories = ['Food', 'Travel', 'Books', 'Entertainment', 'Other'];
  double budget = 5000;

  final Map<String, Color> colors = {
    'Food': Colors.orange,
    'Travel': Colors.blue,
    'Books': Colors.green,
    'Entertainment': Colors.purple,
    'Other': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Read saved data when the app opens
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('expenses');
    final savedBudget = prefs.getDouble('budget');

    setState(() {
      if (saved != null) {
        final list = jsonDecode(saved) as List;
        expenses
          ..clear()
          ..addAll(list.map((e) => Expense.fromMap(e as Map<String, dynamic>)));
      }
      if (savedBudget != null) budget = savedBudget;
    });
  }

  // Save data after every change
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'expenses',
      jsonEncode(expenses.map((e) => e.toMap()).toList()),
    );
    await prefs.setDouble('budget', budget);
  }

  double get total => expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get categoryTotals {
    final Map<String, double> map = {};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  void editBudgetDialog() {
    final ctrl = TextEditingController(text: budget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set monthly budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Budget amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v == null || v <= 0) return;
              setState(() => budget = v);
              saveData();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void addExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = categories[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (titleCtrl.text.isEmpty || amount == null) return;
                setState(() {
                  expenses.add(Expense(titleCtrl.text, amount, category));
                });
                saveData();
                Navigator.pop(ctx);

                // Warning if the budget is crossed
                if (total > budget) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        'Warning! You are over budget by ₹${(total - budget).toStringAsFixed(0)}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBudgetCard() {
    final bool over = total > budget;
    final double fraction = budget <= 0 ? 0 : (total / budget).clamp(0.0, 1.0);
    final Color color = over ? Colors.red : Colors.teal;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
  child: Text('Monthly budget', style: TextStyle(fontSize: 16)),
),
                TextButton(
                  onPressed: editBudgetDialog,
                  child: const Text('Edit'),
                ),
              ],
            ),
            Text(
              '₹${total.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Over budget by ₹${(total - budget).toStringAsFixed(0)}'
                  : '₹${(budget - total).toStringAsFixed(0)} left',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChart() {
    final totals = categoryTotals;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: totals.entries.map((e) {
                    return PieChartSectionData(
                      value: e.value,
                      color: colors[e.key] ?? Colors.grey,
                      title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: totals.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: colors[e.key] ?? Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('${e.key}: ₹${e.value.toStringAsFixed(0)}'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget Tracker')),
      body: Column(
        children: [
          buildBudgetCard(),
          if (expenses.isNotEmpty) buildChart(),
          const SizedBox(height: 8),
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('No expenses yet. Tap + to add.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: expenses.length,
                    itemBuilder: (context, i) {
                      final e = expenses[i];
                      return ListTile(
                        title: Text(e.title),
                        subtitle: Text(e.category),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${e.amount.toStringAsFixed(0)}'),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() => expenses.removeAt(i));
                                saveData();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}