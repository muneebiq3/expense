import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Tracker',
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
  // ignore: library_private_types_in_public_api
  _BudgetHomePageState createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {

  String _drawerHeader = "Menu";
  bool _showExpenses = false;
  bool _showSavings = false;
  bool _isButtonEnabled = false;
  bool _backArrow = false;
  double _budget = 0.0;
  double _currentTotalExpenses = 0.0;
  double _currentRemainingBudget = 0.0;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _expenses = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _increaseBudgetController = TextEditingController();
  final TextEditingController _decreaseBudgetController = TextEditingController();
  final List<Map<String, dynamic>> _budgetIncreases = []; // To store budget increases
  
  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  void _showAddBudgetDialog() {
    TextEditingController descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now(); // Default to today's date

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Budget Increase'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text("Date: ${DateFormat.yMMMd().format(selectedDate)}"), // Show selected date
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          // Open date picker
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000), // Minimum date
                            lastDate: DateTime(2100), // Maximum date
                          );
                          if (pickedDate != null && pickedDate != selectedDate) {
                            setState(() {
                              selectedDate = pickedDate; // Update selected date
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    String description = descriptionController.text.trim();
                    if (description.isNotEmpty) {
                      // Pass the selected date along with description to _increaseBudgetWithDescription
                      _increaseBudgetWithDescription(description, selectedDate);
                    }
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), // Close the dialog
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _increaseBudgetWithDescription(String description, DateTime selectedDate) {

    double increaseAmount = double.tryParse(_increaseBudgetController.text) ?? 0.0;
    String selectedMonthKey = DateFormat('MMMM yyyy').format(_selectedMonth);

    if (increaseAmount > 0) {
      setState(() {
        _currentRemainingBudget += increaseAmount;
        _budget += increaseAmount;

        // Add the increase to the _budgetIncreases list with the selected date
        _budgetIncreases.add({
          'amount': increaseAmount,
          'date': selectedDate.toIso8601String(), // Use selected date here
          'description': description,
          'type': 'increase', // Tag as a budget increase
        });

        // Sort the budget increases by date (most recent first)
        _budgetIncreases.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

        // Update the budget in the _monthlyBudgets map
        _monthlyBudgets[selectedMonthKey] = _budget;

        _increaseBudgetController.clear(); // Clear input field
      });

      // Save data and update metrics
      _saveBudgetData();
      _updateMonthMetrics(selectedMonthKey);
    }
  }

  void _deleteBudgetIncrease(int index) {
    // Get the month-year key for the budget increase
    String increaseMonthKey = DateFormat('MMMM yyyy').format(DateTime.parse(_budgetIncreases[index]['date']));

    setState(() {
      // Update the remaining budget by subtracting the budget increase amount
      _currentRemainingBudget -= _budgetIncreases[index]['amount'];

      // Remove the budget increase from the list
      _budgetIncreases.removeAt(index);

      // Update the metrics for the month from which the increase was deleted
      _updateMonthMetrics(increaseMonthKey);

      // Save the updated data
      _saveBudgetData();
    });
  }

  void _decreaseBudget() {
    setState(() {
      double decreaseAmount = double.tryParse(_decreaseBudgetController.text) ?? 0.0;
      if (decreaseAmount > 0) {
        // Decrease the current remaining budget and budget
        _currentRemainingBudget -= decreaseAmount;
        _budget -= decreaseAmount;

        // Get the selected month key
        String selectedMonthKey = DateFormat('MMMM yyyy').format(_selectedMonth);

        // Update the budget in the _monthlyBudgets map
        _monthlyBudgets[selectedMonthKey] = _budget;

        // Clear the input field
        _decreaseBudgetController.clear();

        // Save the updated budget data
        _saveBudgetData();

        // Recalculate the metrics for the selected month
        _updateMonthMetrics(selectedMonthKey);
      }
    });
  }

  void _loadBudgetData() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load monthly budgets
      String? budgetsJson = prefs.getString('monthlyBudgets');
      if (budgetsJson != null) {
        Map<String, dynamic> savedBudgets = json.decode(budgetsJson);
        _monthlyBudgets = savedBudgets.map((key, value) => MapEntry(key, value.toDouble()));
      }

      // Load monthly savings
      String? savingsJson = prefs.getString('monthlySavings');
      if (savingsJson != null) {
        Map<String, dynamic> savedSavings = json.decode(savingsJson);
        _monthlySavings = savedSavings.map((key, value) => MapEntry(key, value.toDouble()));
      }

      // Load expenses (same as before)
      String? expensesJson = prefs.getString('expenses');
      List<dynamic> jsonList = expensesJson != null ? json.decode(expensesJson) : [];
      _expenses = jsonList.map((e) => e as Map<String, dynamic>).toList();

      // Update the UI with the selected month's data
      _updateSelectedMonthData();
    });

  }

  void _saveBudgetData() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Batch saving data to avoid multiple disk writes
    await prefs.setString('monthlyBudgets', json.encode(_monthlyBudgets));
    await prefs.setString('monthlySavings', json.encode(_monthlySavings));
    await prefs.setString('expenses', json.encode(_expenses));
    await prefs.setString('budgetIncreases', json.encode(_budgetIncreases)); // Save the increases

  }

  // Update budget and expenses for the selected month
  void _updateSelectedMonthData() {
    String selectedMonthKey = DateFormat('MMMM yyyy').format(_selectedMonth);

    // Get budget for the selected month
    _budget = _monthlyBudgets[selectedMonthKey] ?? 0.0;

    // Get expenses for the selected month
    List<Map<String, dynamic>> selectedMonthExpenses = _expenses
        .where((expense) => DateFormat('MMMM yyyy').format(DateTime.parse(expense['date'])) == selectedMonthKey)
        .toList();

    _currentTotalExpenses = selectedMonthExpenses.fold(0.0, (sum, expense) => sum + expense['amount']);
    _currentRemainingBudget = _budget - _currentTotalExpenses;

    // Store savings for the selected month
    _monthlySavings[selectedMonthKey] = _currentRemainingBudget;

    // Calculate previous months' savings
    _calculatePreviousMonthSavings();

    // Save everything
    _saveBudgetData();
  }

  void _calculatePreviousMonthSavings() {

    String selectedMonthKey = DateFormat('MMMM yyyy').format(_selectedMonth);

    // Group expenses by month
    Map<String, List<Map<String, dynamic>>> groupedExpenses = _groupExpensesByMonth();

    // Calculate savings for each previous month
    for (String monthYear in groupedExpenses.keys) {
      if (monthYear != selectedMonthKey) {
        List<Map<String, dynamic>> monthExpenses = groupedExpenses[monthYear]!;

        double totalExpensesForMonth = monthExpenses.fold(0.0, (sum, expense) => sum + expense['amount']);
        double budgetForMonth = _monthlyBudgets[monthYear] ?? 0.0;
        double savingsForMonth = budgetForMonth - totalExpensesForMonth;

        // Save the savings for the month
        _monthlySavings[monthYear] = savingsForMonth;
      }
    }
  }

  void _setMonthlyBudget() {
    setState(() {
      _monthlyBudgets[DateFormat('MMMM yyyy').format(_selectedMonth)] =
          double.tryParse(_budgetController.text) ?? 0.0;
      _updateSelectedMonthData();
      _saveBudgetData();
      _budgetController.clear();
    });
  }

  void _addExpense() {
    setState(() {
      double expenseAmount = double.tryParse(_expenseController.text) ?? 0.0;
      String description = _descriptionController.text.trim();

      if (expenseAmount > 0) {
        // Use the date of the expense (_selectedDate) to determine the month
        String expenseMonthKey = DateFormat('MMMM yyyy').format(_selectedDate);

        // Add the expense
        _expenses.add({
          'amount': expenseAmount,
          'date': _selectedDate.toIso8601String(),
          'description': description,
        });

        // Sort by date
        _expenses.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

        // Update the metrics for the correct month based on the expense date
        _updateMonthMetrics(expenseMonthKey);

        // Clear input fields
        _expenseController.clear();
        _descriptionController.clear();

        // Save updated data
        _saveBudgetData();
      }
    });
  }

  void _updateMonthMetrics(String monthKey) {
    // Get the budget for the specified month
    double monthBudget = _monthlyBudgets[monthKey] ?? 0.0;

    // Filter expenses for the specified month
    List<Map<String, dynamic>> monthExpenses = _expenses
        .where((expense) => DateFormat('MMMM yyyy').format(DateTime.parse(expense['date'])) == monthKey)
        .toList();

    // Calculate total expenses for the specified month
    double totalExpensesForMonth = monthExpenses.fold(0.0, (sum, expense) => sum + expense['amount']);

    // Filter increases for the specified month
    List<Map<String, dynamic>> monthIncreases = _budgetIncreases
        .where((increase) => DateFormat('MMMM yyyy').format(DateTime.parse(increase['date'])) == monthKey)
        .toList();

    // Calculate total budget increases for the specified month
    double totalIncreasesForMonth = monthIncreases.fold(0.0, (sum, increase) => sum + increase['amount']);

    // Update the budget and remaining budget for the month
    _currentRemainingBudget = monthBudget + totalIncreasesForMonth - totalExpensesForMonth;

    // If the month being updated is the currently selected month, update the UI
    if (monthKey == DateFormat('MMMM yyyy').format(_selectedMonth)) {
      _currentTotalExpenses = totalExpensesForMonth;
      _budget = monthBudget + totalIncreasesForMonth; // Reflect total budget after increase
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      // Only show month/year selection
      helpText: "Select month",
      initialDatePickerMode: DatePickerMode.year, // Show year first
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _updateSelectedMonthData(); // Refresh data for the selected month
      });
    }
  }

  void _deleteExpense(int index) {
    String expenseMonthKey = DateFormat('MMMM yyyy').format(DateTime.parse(_expenses[index]['date']));

    setState(() {
      // Update the budget for the month of the deleted expense, not just the selected month
      _currentRemainingBudget += _expenses[index]['amount'];

      // Remove the expense from the list
      _expenses.removeAt(index);

      // Update the month metrics for the month from which the expense was deleted
      _updateMonthMetrics(expenseMonthKey);

      // Save the updated data
      _saveBudgetData();
    });
  }
  void _editExpense(int index) {
    // Retrieve the current expense details
    var expense = _expenses[index];

    // Store the original month before changes
    String oldMonthKey = DateFormat('MMMM yyyy').format(DateTime.parse(expense['date']));

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
              onPressed: () => setState(() {
                // Calculate the new expense amount
                double newExpenseAmount = double.tryParse(_expenseController.text) ?? 0.0;

                // Store the new month key (in case the date changes)
                String newMonthKey = DateFormat('MMMM yyyy').format(_selectedDate);

                // Adjust the total expenses for the old month
                _currentTotalExpenses -= expense['amount'];

                // If the expense moves to a different month, update the old month metrics
                if (oldMonthKey != newMonthKey) {
                  _updateMonthMetrics(oldMonthKey);
                }

                // Update the expense details
                _expenses[index] = {
                  'amount': newExpenseAmount,
                  'description': _descriptionController.text.isNotEmpty
                      ? _descriptionController.text
                      : expense['description'],
                  'date': _selectedDate.toIso8601String(),
                };

                // Update the total expenses and remaining budget for the new month
                _currentTotalExpenses += newExpenseAmount;
                _currentRemainingBudget = _budget - _currentTotalExpenses;

                // Update the metrics for the new month
                _updateMonthMetrics(newMonthKey);

                // Save the updated data
                _saveBudgetData();

                Navigator.of(context).pop(); // Close the dialog
              }),
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close the dialog
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _refreshMonth() {
    setState(() {
      // Get the selected month key
      String selectedMonthKey = DateFormat('MMMM yyyy').format(_selectedMonth);

      // Remove all expenses for the selected month
      _expenses.removeWhere((expense) =>
        DateFormat('MMMM yyyy').format(DateTime.parse(expense['date'])) == selectedMonthKey);

      // Reset budget, total expenses, remaining budget, and savings for the selected month
      _budget = 0.0;
      _currentTotalExpenses = 0.0;
      _currentRemainingBudget = 0.0;
      _monthlyBudgets[selectedMonthKey] = _budget;
      _monthlySavings[selectedMonthKey] = _currentRemainingBudget;

      // Clear any input controllers related to the budget
      _budgetController.clear();

      // Save the updated data
      _saveBudgetData();

      // Recalculate metrics for the selected month (which should now be 0)
      _updateMonthMetrics(selectedMonthKey);

      // Optionally disable the button if needed
      _enableButton();
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

  Map<String, List<Map<String, dynamic>>> _groupExpensesByMonth() {

    Map<String, List<Map<String, dynamic>>> groupedItems = {};

    for (var expense in _expenses) {
      DateTime date = DateTime.parse(expense['date']);
      String monthYear = DateFormat('MMMM yyyy').format(date); // e.g., "January 2024"

      // Initialize the list for the month if it doesn't exist
      if (!groupedItems.containsKey(monthYear)) {
        groupedItems[monthYear] = [];
      }

      // Add the expense to the corresponding month
      groupedItems[monthYear]!.add({
        ...expense,
        'type': 'expense', // Mark it as an expense
      });
    }

    // Group budget increases by month
    for (var increase in _budgetIncreases) {
      DateTime date = DateTime.parse(increase['date']);
      String monthYear = DateFormat('MMMM yyyy').format(date); // e.g., "January 2024"

      // Initialize the list for the month if it doesn't exist
      if (!groupedItems.containsKey(monthYear)) {
        groupedItems[monthYear] = [];
      }

      // Add the increase to the corresponding month with a 'type' tag
      groupedItems[monthYear]!.add({
        ...increase,
        'type': 'increase', // Mark it as a budget increase
      });
    }

    return groupedItems;
  }

  Map<String, double> _monthlyBudgets = {};
  Map<String, double> _monthlySavings = {};  // Track savings for each month
  DateTime _selectedMonth = DateTime.now();

  void _enableButton() {
    setState(() {
      _isButtonEnabled = true;
    });
  }

  Widget _buildExpensesWidget() {
    return _expenses.isEmpty && _budgetIncreases.isEmpty
    ? const Padding(
      padding: EdgeInsets.all(16.0),
        child: Text(
          'No expenses or budget increases added yet.',
          style: TextStyle(fontSize: 16),
        ),
    )
    : FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: Future.value(_groupExpensesByMonth()), // Use the new method
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } 
        else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } 
        else {
          final groupedItems = snapshot.data!;

          return Flexible(
            child: ListView(
              children: groupedItems.entries.map(
                (entry) {
                  String monthYear = entry.key;
                  List<Map<String, dynamic>> items = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          monthYear,
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      ...items.asMap().entries.map(
                        (entry) {
                          int index = entry.key;
                          Map<String, dynamic> item = entry.value;

                          bool isExpense = item['type'] == 'expense';
                          return Card(
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isExpense
                                      ? 'PKR ${item['amount']}' // For expenses: normal amount
                                      : 'PKR +${item['amount']}', // For increases: add "+" before the amount
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['description']}', // Display description for both
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                DateFormat.yMMMd().format(DateTime.parse(item['date'])),
                                style: const TextStyle(fontSize: 15),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isExpense)
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editExpense(index), // Pass the correct expense index
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => isExpense
                                        ? _deleteExpense(index) // Pass the correct index for the expense
                                        : _deleteBudgetIncrease(index), // Pass the correct index for the increase
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ).toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildSavingsList() {
    // If there are no previous months' savings, show a message
    if (_monthlySavings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: Text(
          'No savings for previous months.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    // Otherwise, display the savings for each previous month
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _monthlySavings.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            '${entry.key}: PKR ${entry.value.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Budget Tracker'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: "Menu",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMonth,
            tooltip: "New Month"
          )
        ],
      ),
      drawer: Drawer( 
        child: Column(  // Use Column instead of ListView
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Row(
                    children: [
                      Visibility(
                        visible: _backArrow,
                        child: IconButton(
                          color: Colors.black,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() {
                            _drawerHeader = "Menu";
                            _backArrow = false;
                            _showExpenses = false;
                            _showSavings = false;
                          }),
                          tooltip: "Back to Menu",
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            _drawerHeader,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 21,
                            ),
                          ),
                        ),
                      )
                    ]
                  )
                ],
              ),
            ),

            if(!_showExpenses && !_showSavings) ...[
              ListTile(
                title: const Text("Expenses"),
                onTap: () => setState(() {
                    
                  _drawerHeader = "Expenses History";
                  _backArrow = true;
                  _showExpenses = true;
                  _showSavings = false;
                    
                }),
              ),

              ListTile(
                title: const Text("Savings"),
                onTap: () => setState(() {
                    
                  _drawerHeader = "Savings History";
                  _backArrow = true;
                  _showExpenses = false;
                  _showSavings = true;
                    
                }),
              ),
            ],
            
            if (_showExpenses) _buildExpensesWidget(), // Show expenses widget when _showExpenses is true
            if (_showSavings) _buildSavingsList()
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectMonth(context)
                  )
                ],
              ),
              const SizedBox(height: 10),
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
                  labelText: "Enter monthly budget (PKR)",
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)
                  ),
                ),
              ),
              SizedBox(
                width: screenWidth * 1,
                child: ElevatedButton(
                  onPressed: _isButtonEnabled
                  ? () {
                    _setMonthlyBudget();
                  }
                  : null,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white
                  ),
                  child: const Text("Set Monthly Budget")
                ),
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
                          onPressed: _showAddBudgetDialog,
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