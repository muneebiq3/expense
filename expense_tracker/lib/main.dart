import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(BudgetApp());
}

class BudgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monthly Expense Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: BudgetHomePage(),
    );
  }
}

class BudgetHomePage extends StatefulWidget {
  @override
  _BudgetHomePageState createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  double _budget = 0.0;
  double _currentTotalExpenses = 0.0;
  double _currentRemainingBudget = 0.0;
  List<Map<String, dynamic>> _expenses = [];
  TextEditingController _budgetController = TextEditingController();
  TextEditingController _expenseController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _increaseBudgetController = TextEditingController();
  TextEditingController _decreaseBudgetController = TextEditingController();
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
      if (expensesJson != null) {
        List<dynamic> jsonList = json.decode(expensesJson);
        _expenses = jsonList.map((e) => e as Map<String, dynamic>).toList();
      }
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
          title: Text("Edit Expense"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseController,
                decoration: InputDecoration(labelText: "Expense Amount"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: "Description"),
              ),
              Row(
                children: [
                  Text("Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
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
              child: Text("Save"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
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
        title: Text('Monthly Expense Tracker'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          tooltip: "Expense History",
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshMonth,
            tooltip: "New Month")
        ],
      ),
      drawer: Drawer(
        child: Column(  // Use Column instead of ListView
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Expense History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.05,
                ),
              ),
            ),
            Expanded(  // Wrap the ListView with Expanded to avoid unbounded height
              child: _expenses.isEmpty? 
              Padding(
                padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No expenses added yet.',
                    style: TextStyle(fontSize: screenWidth * 0.04),
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
                        style: TextStyle(fontSize: screenWidth * 0.04),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().format(DateTime.parse(expense['date'])),
                        style: TextStyle(fontSize: screenWidth * 0.035),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _editExpense(index),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Budget: PKR ${_budget.toStringAsFixed(2)}',
              style: TextStyle(fontSize: screenWidth * 0.05)),
            SizedBox(height: 10),
            Text(
              'Total Expenses: PKR ${_currentTotalExpenses.toStringAsFixed(2)}',
              style: TextStyle(fontSize: screenWidth * 0.05),
            ),
            SizedBox(height: 10),
            Text(
              'Remaining: PKR ${_currentRemainingBudget.toStringAsFixed(2)}',
              style: TextStyle(fontSize: screenWidth * 0.05),
            ),
            Divider(height: 20),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter this month's budget (PKR)",
                labelStyle: TextStyle(fontSize: screenWidth * 0.04),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addbudget,
              child: Text("Define"),
            ),
            SizedBox(height: 20),
            Flexible(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _increaseBudgetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Increase Budget (PKR)",
                            labelStyle:
                              TextStyle(fontSize: screenWidth * 0.04)
                          ),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _increaseBudget,
                          child: Text("Add to total")
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _decreaseBudgetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Decrease Budget (PKR)",
                            labelStyle:
                              TextStyle(fontSize: screenWidth * 0.04)),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _decreaseBudget,
                          child: Text("Reduce from total")
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Divider(height: 30),
            TextField(
              controller: _expenseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter expense amount (PKR)',
                labelStyle: TextStyle(fontSize: screenWidth * 0.04),
              ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Enter description',
                labelStyle: TextStyle(fontSize: screenWidth * 0.04),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Selected date: ${DateFormat.yMMMd().format(_selectedDate)}',
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text('Select Date'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addExpense,
              child: Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}