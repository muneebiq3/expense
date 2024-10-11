import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monthly Expense Tracker',
      debugShowCheckedModeBanner: false,
      home: const BudgetHomePage(),
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
    );
  }
}

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({super.key});

  @override
  _BudgetHomePageState createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  double _budget = 0.0;
  double _currentTotalExpenses = 0.0;
  double _currentRemainingBudget = 0.0;
  List<Map<String, dynamic>> _expenses = [];
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _increaseBudgetController = TextEditingController();
  final TextEditingController _decreaseBudgetController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  void _increaseBudget() {
    setState(() {
      double increaseAmount = double.tryParse(_increaseBudgetController.text) ?? 0.0;
      if (increaseAmount > 0) {
        _currentRemainingBudget += increaseAmount;
        _budget += increaseAmount;
        _increaseBudgetController.clear();
        _saveBudgetData();
      }
    });
  }

  void _decreaseBudget() {
    setState(() {
      double decreaseAmount = double.tryParse(_decreaseBudgetController.text) ?? 0.0;
      if (decreaseAmount > 0) {
        _currentRemainingBudget -= decreaseAmount;
        _budget -= decreaseAmount;
        _decreaseBudgetController.clear();
        _saveBudgetData();
      }
    });
  }

  void _loadBudgetData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _budget = prefs.getDouble('budget') ?? 0.0;
      String? expensesJson = prefs.getString('expenses');
      List<dynamic> jsonList = json.decode(expensesJson!);
      _expenses = jsonList.map((e) => e as Map<String, dynamic>).toList();
          _currentTotalExpenses = prefs.getDouble('currentTotalExpenses') ?? 0.0;
      _currentRemainingBudget = prefs.getDouble('currentRemainingBudget') ?? _budget;
    });
  }

  void _saveBudgetData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('budget', _budget);
    prefs.setString('expenses', json.encode(_expenses));
    prefs.setDouble('currentTotalExpenses', _currentTotalExpenses);
    prefs.setDouble('currentRemainingBudget', _currentRemainingBudget);
  }

  void _addbudget() {
    setState(() {
      _budget = double.tryParse(_budgetController.text) ?? 0.0;
      _currentRemainingBudget = _budget; // Update remaining budget to match the defined budget
      _budgetController.clear();
      _saveBudgetData();
    });
  }

  void _addExpense() {
    setState(() {
      double expenseAmount = double.tryParse(_expenseController.text) ?? 0.0;
      String description = _descriptionController.text.trim();

      if (expenseAmount > 0) {
        _expenses.add({
          'amount': expenseAmount,
          'date': _selectedDate.toIso8601String(),
          'description': description,
        });

        _expenses.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

        _currentTotalExpenses += expenseAmount;
        _currentRemainingBudget = _budget - _currentTotalExpenses;
      }
      _expenseController.clear();
      _descriptionController.clear();
      _saveBudgetData();
    });
  }

  void _deleteExpense(int index) {
    setState(() {
      _currentTotalExpenses -= _expenses[index]['amount'];
      _currentRemainingBudget = _budget - _currentTotalExpenses;
      _expenses.removeAt(index);
      _saveBudgetData();
    });
  }
  void _editExpense(int index) {
    // Retrieve the current expense details
    var expense = _expenses[index];

    // Set text controllers to current values
    _expenseController.text = expense['amount'].toString();
    _descriptionController.text = expense['description'];
    _selectedDate = DateTime.parse(expense['date']);

    // Show a dialog to edit expense details
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Expense"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseController,
                decoration: const InputDecoration(labelText: "Expense Amount"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              Row(
                children: [
                  Text("Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  // Update the expense details
                  _expenses[index] = {
                    'amount': double.tryParse(_expenseController.text) ?? expense['amount'],
                    'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : expense['description'],
                    'date': _selectedDate.toIso8601String(),
                  };
                  _saveBudgetData(); // Save updated data
                });
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _refreshMonth() {
    setState(() {
      _budget = 0.0;
      _budgetController.clear();
      _currentTotalExpenses = 0.0;
      _currentRemainingBudget = 0.0;
      _saveBudgetData();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Monthly Expense Tracker'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          tooltip: "Expense History",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMonth,
            tooltip: "New Month")
        ],
      ),
      drawer: Drawer(
        child: Column(  // Use Column instead of ListView
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Text(
                'Expense History',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(  // Wrap the ListView with Expanded to avoid unbounded height
              child: _expenses.isEmpty? 
              const Padding(
                padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No expenses added yet.',
                    style: TextStyle(fontSize: 16),
                  ),
              ): 
              ListView.builder(
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${expense['description']} - PKR ${expense['amount']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().format(DateTime.parse(expense['date'])),
                        style: const TextStyle(fontSize: 15),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editExpense(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteExpense(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Budget: PKR ${_budget.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18)
              ),
              const SizedBox(height: 10),
              Text(
                'Total Expenses: PKR ${_currentTotalExpenses.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'Remaining: PKR ${_currentRemainingBudget.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18),
              ),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  labelText: "Enter this month's budget (PKR)",
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addbudget,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white
                ),
                child: const Text("Define"),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _increaseBudgetController,
                          keyboardType: TextInputType.number,
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: "Increase Budget (PKR)",
                            labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _increaseBudget,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white
                          ),
                          child: const Text("Add to total"),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _decreaseBudgetController,
                          keyboardType: TextInputType.number,
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: "Decrease Budget (PKR)",
                            labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _decreaseBudget,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white
                          ),
                          child: const Text("Reduce from total")
                        ),
                      ],
                    ),
                  )
                ],
              ),
              TextField(
                controller: _expenseController,
                keyboardType: TextInputType.number,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  labelText: 'Enter expense amount (PKR)',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)
                  ),
                ),
              ),
              TextField(
                controller: _descriptionController,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  labelText: 'Enter description',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Selected date: ${DateFormat.yMMMd().format(_selectedDate)}',
                style: const TextStyle(fontSize: 16),
              ),
              ElevatedButton(
                onPressed: () => _selectDate(context),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white
                ),
                child: const Text('Select Date'),
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: screenWidth * 1,
                child: ElevatedButton(
                  onPressed: _addExpense,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white
                  ),
                  child: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}