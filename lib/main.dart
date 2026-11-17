import 'package:flutter/material.dart';

import 'shared_preferences_helper.dart';

void main() {
  runApp(const MyApp());
}

/// 收支類型。程式內使用英文名稱，畫面上再顯示中文。
enum RecordType { income, expense }

/// AppBar 篩選選單的三種狀態。
enum RecordFilter { all, income, expense }

enum AppPage { home, addRecord, statistics, settings, about }

/// 一筆收支資料。
///
/// 題目提到要用 List 管理資料，因此多筆 Expense 會放在 List<Expense> 裡。
class Expense {
  const Expense({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.amount,
    required this.note,
    required this.date,
  });

  final String id;
  final RecordType type;
  final String category;
  final String title;
  final int amount;
  final String note;
  final DateTime date;

  /// 把物件轉成 Map，方便 helper 將資料存成 JSON。
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'category': category,
      'title': title,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  /// 把從 JSON 讀回來的 Map 還原成 Expense。
  factory Expense.fromMap(Map<String, dynamic> map) {
    final savedType = map['type'] as String?;
    final savedDate = DateTime.tryParse(map['date'] as String? ?? '');

    return Expense(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: savedType == RecordType.income.name
          ? RecordType.income
          : RecordType.expense,
      category: map['category'] as String? ?? '其他',
      title: map['title'] as String? ?? '未命名紀錄',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      note: map['note'] as String? ?? '',
      date: savedDate ?? DateTime.now(),
    );
  }
}

/// 收入與支出可以選擇的分類。
const List<String> incomeCategories = <String>['薪資', '獎金', '投資', '其他'];
const List<String> expenseCategories = <String>[
  '餐飲',
  '交通',
  '購物',
  '娛樂',
  '居家',
  '醫療',
  '其他',
];

List<String> categoriesFor(RecordType type) {
  return type == RecordType.income ? incomeCategories : expenseCategories;
}

String formatAmount(int amount) {
  // 以逗號分隔千位數，例如 5000 會顯示成 5,000。
  return amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

String formatMoney(int amount) => 'NT\$ ${formatAmount(amount)}';

String typeLabel(RecordType type) {
  return type == RecordType.income ? '收入' : '支出';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SharedPreferencesHelper _storage = SharedPreferencesHelper.instance;

  /// ValueNotifier 裡面放整份紀錄清單；資料改變時，相關畫面會自動更新。
  final ValueNotifier<List<Expense>> _records =
      ValueNotifier<List<Expense>>(<Expense>[]);

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = true;
  String? _loadError;
  String _userName = '訪客';
  int _monthlyBudget = 20000;
  AppPage _currentPage = AppPage.home;
  RecordFilter _recordFilter = RecordFilter.all;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  /// 開啟 APP 時，先讀取手機裡儲存的資料。
  Future<void> _loadSavedData() async {
    try {
      final savedMaps = await _storage.readRecords();
      late final List<Expense> loadedRecords;

      if (savedMaps == null) {
        // 只有第一次使用（還沒有存檔）才放入題目指定的六筆測試資料。
        loadedRecords = _makeTestRecords();
        await _saveRecordsToPhone(loadedRecords);
      } else {
        // 已有存檔時直接讀取；即使清單是空的，也不會重新塞入測試資料。
        loadedRecords = savedMaps.map(Expense.fromMap).toList();
      }

      final savedName = await _storage.readUserName();
      final savedBudget = await _storage.readMonthlyBudget();

      _records.value = loadedRecords;
      if (!mounted) return;
      setState(() {
        _userName = savedName == null || savedName.trim().isEmpty
            ? '訪客'
            : savedName;
        _monthlyBudget = savedBudget ?? 20000;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Expense> _makeTestRecords() {
    final now = DateTime.now();
    return <Expense>[
      Expense(
        id: 'test_1',
        type: RecordType.expense,
        category: '餐飲',
        title: '早餐',
        amount: 80,
        note: '',
        date: now,
      ),
      Expense(
        id: 'test_2',
        type: RecordType.expense,
        category: '交通',
        title: '公車',
        amount: 30,
        note: '',
        date: now,
      ),
      Expense(
        id: 'test_3',
        type: RecordType.expense,
        category: '購物',
        title: '文具用品',
        amount: 150,
        note: '',
        date: now,
      ),
      Expense(
        id: 'test_4',
        type: RecordType.income,
        category: '薪資',
        title: '兼職薪水',
        amount: 5000,
        note: '',
        date: now,
      ),
      Expense(
        id: 'test_5',
        type: RecordType.expense,
        category: '娛樂',
        title: '電影票',
        amount: 320,
        note: '',
        date: now,
      ),
      Expense(
        id: 'test_6',
        type: RecordType.expense,
        category: '餐飲',
        title: '晚餐',
        amount: 180,
        note: '',
        date: now,
      ),
    ];
  }

  Future<void> _saveRecordsToPhone(List<Expense> records) {
    final maps = records.map((record) => record.toMap()).toList();
    return _storage.saveRecords(maps);
  }

  Future<void> _addRecord(Expense newRecord) async {
    // 建立新的 List，不直接修改舊 List，ValueNotifier 才會通知畫面更新。
    _records.value = <Expense>[..._records.value, newRecord];

    var savedSuccessfully = true;
    try {
      await _saveRecordsToPhone(_records.value);
    } catch (_) {
      savedSuccessfully = false;
    }

    if (!mounted) return;
    setState(() {
      _currentPage = AppPage.home;
    });

    _showMessage(
      savedSuccessfully
          ? '新增完成，資料已儲存。'
          : '紀錄已新增到畫面，但本次未能存入手機。',
    );
  }

  Future<void> _deleteRecord(Expense record) async {
    _records.value = _records.value
        .where((savedRecord) => savedRecord.id != record.id)
        .toList();

    try {
      await _saveRecordsToPhone(_records.value);
      _showMessage('已刪除「${record.title}」。');
    } catch (_) {
      _showMessage('畫面已刪除紀錄，但本次未能更新手機存檔。');
    }
  }

  Future<void> _saveProfile(String name, int budget) async {
    try {
      await _storage.saveUserName(name);
      await _storage.saveMonthlyBudget(budget);
      if (!mounted) return;

      setState(() {
        _userName = name;
        _monthlyBudget = budget;
      });
      _showMessage('個人設定已儲存。');
    } catch (_) {
      _showMessage('設定未能存入手機，請再試一次。');
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _pageTitle {
    switch (_currentPage) {
      case AppPage.home:
        return '我的智慧記帳';
      case AppPage.addRecord:
        return '新增紀錄';
      case AppPage.statistics:
        return '收支統計';
      case AppPage.settings:
        return '個人設定';
      case AppPage.about:
        return '關於 APP';
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case AppPage.home:
        return HomePage(
          records: _records,
          userName: _userName,
          filter: _recordFilter,
          onDelete: _deleteRecord,
        );
      case AppPage.addRecord:
        return AddRecordPage(onSave: _addRecord);
      case AppPage.statistics:
        return StatisticsPage(records: _records);
      case AppPage.settings:
        return SettingsPage(
          records: _records,
          userName: _userName,
          monthlyBudget: _monthlyBudget,
          onSave: _saveProfile,
        );
      case AppPage.about:
        return const AboutPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的智慧記帳',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: _buildHomeShell(),
    );
  }

  Widget _buildHomeShell() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的智慧記帳')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('讀取資料時發生問題。'),
                const SizedBox(height: 8),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _loadSavedData();
                  },
                  child: const Text('重新讀取'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: <Widget>[
          PopupMenuButton<RecordFilter>(
            tooltip: '篩選首頁紀錄',
            initialValue: _recordFilter,
            icon: const Icon(Icons.filter_list),
            onSelected: (RecordFilter filter) {
              setState(() {
                _recordFilter = filter;
              });
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<RecordFilter>>[
              PopupMenuItem<RecordFilter>(
                value: RecordFilter.all,
                child: Text('全部紀錄'),
              ),
              PopupMenuItem<RecordFilter>(
                value: RecordFilter.income,
                child: Text('只看收入'),
              ),
              PopupMenuItem<RecordFilter>(
                value: RecordFilter.expense,
                child: Text('只看支出'),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildCurrentPage(),
      floatingActionButton: _currentPage == AppPage.home
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _currentPage = AppPage.addRecord),
              icon: const Icon(Icons.add),
              label: const Text('新增紀錄'),
            )
          : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(_userName),
              accountEmail: const Text('我的智慧記帳 APP'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _drawerItem(Icons.home_outlined, '記帳首頁', AppPage.home),
                  _drawerItem(Icons.add_circle_outline, '新增紀錄', AppPage.addRecord),
                  _drawerItem(Icons.bar_chart, '收支統計', AppPage.statistics),
                  _drawerItem(Icons.person_outline, '個人設定', AppPage.settings),
                  _drawerItem(Icons.info_outline, '關於 APP', AppPage.about),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('資料儲存在這台裝置上'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, AppPage page) {
    return Builder(
      builder: (BuildContext drawerContext) {
        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          selected: _currentPage == page,
          onTap: () {
            Navigator.of(drawerContext).pop(); // 關閉 Drawer。
            setState(() {
              _currentPage = page;
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _records.dispose();
    super.dispose();
  }
}

/// 首頁：收入、支出、餘額由 List 裡的資料即時計算。
class HomePage extends StatelessWidget {
  const HomePage({
    required this.records,
    required this.userName,
    required this.filter,
    required this.onDelete,
    super.key,
  });

  final ValueListenable<List<Expense>> records;
  final String userName;
  final RecordFilter filter;
  final Future<void> Function(Expense record) onDelete;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Expense>>(
      valueListenable: records,
      builder: (BuildContext context, List<Expense> allRecords, Widget? child) {
        final totalIncome = allRecords
            .where((Expense record) => record.type == RecordType.income)
            .fold<int>(0, (int sum, Expense record) => sum + record.amount);
        final totalExpense = allRecords
            .where((Expense record) => record.type == RecordType.expense)
            .fold<int>(0, (int sum, Expense record) => sum + record.amount);
        final balance = totalIncome - totalExpense;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '你好，$userName！',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('以下金額會隨著你的紀錄自動更新。'),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SummaryCard(
                      title: '總收入',
                      amount: totalIncome,
                      color: Colors.green,
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: '總支出',
                      amount: totalExpense,
                      color: Colors.redAccent,
                      icon: Icons.north_east,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: '剩餘金額',
                      amount: balance,
                      color: Colors.blue,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '最近的收支紀錄',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(_filterLabel(filter)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 390,
                child: AnimatedRecordList(
                  records: records,
                  filter: filter,
                  limit: 8,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _filterLabel(RecordFilter filter) {
    switch (filter) {
      case RecordFilter.all:
        return '全部紀錄';
      case RecordFilter.income:
        return '只看收入';
      case RecordFilter.expense:
        return '只看支出';
    }
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    super.key,
  });

  final String title;
  final int amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.09),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 用 AnimatedList 顯示紀錄。
///
/// ValueNotifier 有新增、刪除或篩選條件改變時，這個元件會同步清單，
/// 新增與刪除都會有簡單的尺寸/淡入淡出動畫。
class AnimatedRecordList extends StatefulWidget {
  const AnimatedRecordList({
    required this.records,
    required this.filter,
    required this.onDelete,
    this.limit,
    super.key,
  });

  final ValueListenable<List<Expense>> records;
  final RecordFilter filter;
  final int? limit;
  final Future<void> Function(Expense record) onDelete;

  @override
  State<AnimatedRecordList> createState() => _AnimatedRecordListState();
}

class _AnimatedRecordListState extends State<AnimatedRecordList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<Expense> _items;

  @override
  void initState() {
    super.initState();
    _items = _getVisibleItems();
    widget.records.addListener(_syncFromNotifier);
  }

  @override
  void didUpdateWidget(covariant AnimatedRecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      oldWidget.records.removeListener(_syncFromNotifier);
      widget.records.addListener(_syncFromNotifier);
    }

    if (oldWidget.records != widget.records ||
        oldWidget.filter != widget.filter ||
        oldWidget.limit != widget.limit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromNotifier();
      });
    }
  }

  List<Expense> _getVisibleItems() {
    final filtered = widget.records.value.where((Expense record) {
      if (widget.filter == RecordFilter.income) {
        return record.type == RecordType.income;
      }
      if (widget.filter == RecordFilter.expense) {
        return record.type == RecordType.expense;
      }
      return true;
    }).toList()
      ..sort((Expense first, Expense second) => second.date.compareTo(first.date));

    if (widget.limit != null && filtered.length > widget.limit!) {
      return filtered.take(widget.limit!).toList();
    }
    return filtered;
  }

  void _syncFromNotifier() {
    final nextItems = _getVisibleItems();
    final animatedList = _listKey.currentState;
    var didChange = false;

    // 先從後面往前移除，這樣刪除一個項目不會影響還沒檢查的索引。
    for (var index = _items.length - 1; index >= 0; index--) {
      final stillExists = nextItems.any(
        (Expense item) => item.id == _items[index].id,
      );
      if (!stillExists) {
        final removedItem = _items.removeAt(index);
        didChange = true;
        animatedList?.removeItem(
          index,
          (BuildContext context, Animation<double> animation) =>
              _animatedTile(removedItem, animation, isRemoving: true),
          duration: const Duration(milliseconds: 280),
        );
      }
    }

    // 再依照新清單順序插入資料。新紀錄通常會出現在清單最前面。
    for (var index = 0; index < nextItems.length; index++) {
      final nextItem = nextItems[index];
      if (index < _items.length && _items[index].id == nextItem.id) {
        _items[index] = nextItem;
        continue;
      }

      final existingIndex = _items.indexWhere(
        (Expense item) => item.id == nextItem.id,
      );
      if (existingIndex == -1) {
        _items.insert(index, nextItem);
        didChange = true;
        animatedList?.insertItem(
          index,
          duration: const Duration(milliseconds: 280),
        );
      } else {
        // 若日期順序改變，使用移除再插入的方式同步位置。
        final movedItem = _items.removeAt(existingIndex);
        animatedList?.removeItem(
          existingIndex,
          (BuildContext context, Animation<double> animation) =>
              _animatedTile(movedItem, animation, isRemoving: true),
          duration: const Duration(milliseconds: 180),
        );
        _items.insert(index, nextItem);
        animatedList?.insertItem(
          index,
          duration: const Duration(milliseconds: 180),
        );
        didChange = true;
      }
    }

    while (_items.length > nextItems.length) {
      final lastIndex = _items.length - 1;
      final removedItem = _items.removeLast();
      animatedList?.removeItem(
        lastIndex,
        (BuildContext context, Animation<double> animation) =>
            _animatedTile(removedItem, animation, isRemoving: true),
      );
      didChange = true;
    }

    if (didChange && mounted) {
      setState(() {});
    }
  }

  Widget _animatedTile(
    Expense item,
    Animation<double> animation, {
    bool isRemoving = false,
  }) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: animation,
        child: RecordTile(
          key: ValueKey<String>(item.id),
          record: item,
          onDelete: widget.onDelete,
          allowDelete: !isRemoving,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedList(
          key: _listKey,
          initialItemCount: _items.length,
          padding: const EdgeInsets.only(bottom: 8),
          itemBuilder: (BuildContext context, int index, Animation<double> animation) {
            if (index >= _items.length) return const SizedBox.shrink();
            return _animatedTile(_items[index], animation);
          },
        ),
        if (_items.isEmpty)
          const Center(child: Text('目前沒有符合條件的紀錄。')),
      ],
    );
  }

  @override
  void dispose() {
    widget.records.removeListener(_syncFromNotifier);
    super.dispose();
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({
    required this.record,
    required this.onDelete,
    this.allowDelete = true,
    super.key,
  });

  final Expense record;
  final Future<void> Function(Expense record) onDelete;
  final bool allowDelete;

  Future<void> _askBeforeDelete(BuildContext context) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除這筆紀錄？'),
          content: Text('確定要刪除「${record.title}」嗎？刪除後無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await onDelete(record);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = record.type == RecordType.income;
    final recordColor = isIncome ? Colors.green : Colors.redAccent;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: recordColor.withOpacity(0.12),
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: recordColor,
          ),
        ),
        title: Text(record.title),
        subtitle: Text(
          '${record.category}・${typeLabel(record.type)}・${record.date.month}/${record.date.day}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${isIncome ? '+' : '-'}${formatMoney(record.amount)}',
              style: TextStyle(
                color: recordColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (allowDelete)
              IconButton(
                tooltip: '刪除紀錄',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _askBeforeDelete(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// 新增收入或支出的表單。
class AddRecordPage extends StatefulWidget {
  const AddRecordPage({required this.onSave, super.key});

  final Future<void> Function(Expense record) onSave;

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  RecordType? _type;
  String? _category;
  String? _errorMessage;
  bool _isSaving = false;

  Future<void> _checkAndSave() async {
    final title = _titleController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());

    if (_type == null) {
      setState(() => _errorMessage = '請選擇收入或支出。');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = '請輸入項目名稱。');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = '金額必須是大於 0 的整數。');
      return;
    }
    if (_category == null || _category!.isEmpty) {
      setState(() => _errorMessage = '請選擇一個分類。');
      return;
    }

    setState(() => _errorMessage = null);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認新增紀錄'),
          content: Text(
            '類型：${typeLabel(_type!)}\n'
            '項目：$title\n'
            '金額：${formatMoney(amount)}\n'
            '分類：$_category',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('返回修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('確認儲存'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final newRecord = Expense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type!,
      category: _category!,
      title: title,
      amount: amount,
      note: _noteController.text.trim(),
      date: DateTime.now(),
    );

    setState(() => _isSaving = true);
    await widget.onSave(newRecord);
    // 儲存後主畫面會切回首頁，所以這個畫面通常已經離開。
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == null ? <String>[] : categoriesFor(_type!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('選擇收支類型', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: <Widget>[
              Expanded(
                child: RadioListTile<RecordType>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('收入'),
                  value: RecordType.income,
                  groupValue: _type,
                  onChanged: (RecordType? value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      _category = null;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<RecordType>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('支出'),
                  value: RecordType.expense,
                  groupValue: _type,
                  onChanged: (RecordType? value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      _category = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '項目名稱',
              hintText: '例如：午餐、薪水',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '金額',
              hintText: '請輸入大於 0 的整數',
              border: OutlineInputBorder(),
              prefixText: 'NT\$ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: '分類',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                hint: const Text('請選擇分類'),
                isExpanded: true,
                items: categories
                    .map(
                      (String category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _type == null
                    ? null
                    : (String? value) {
                        if (value != null) setState(() => _category = value);
                      },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '備註（可不填）',
              hintText: '想補充的內容可以寫在這裡',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _checkAndSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('檢查並儲存'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('小提醒：項目名稱不能空白，金額要大於 0。'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

/// 統計頁使用 TabBar 與 TabBarView 分別查看支出、收入分類。
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({required this.records, super.key});

  final ValueListenable<List<Expense>> records;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Expense>>(
      valueListenable: records,
      builder: (BuildContext context, List<Expense> allRecords, Widget? child) {
        final now = DateTime.now();
        final thisMonth = allRecords.where((Expense record) {
          return record.date.year == now.year && record.date.month == now.month;
        }).toList();
        final income = thisMonth
            .where((Expense record) => record.type == RecordType.income)
            .fold<int>(0, (int sum, Expense record) => sum + record.amount);
        final expense = thisMonth
            .where((Expense record) => record.type == RecordType.expense)
            .fold<int>(0, (int sum, Expense record) => sum + record.amount);

        return DefaultTabController(
          length: 2,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${now.year} 年 ${now.month} 月',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SummaryCard(
                            title: '本月收入',
                            amount: income,
                            color: Colors.green,
                            icon: Icons.south_west,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SummaryCard(
                            title: '本月支出',
                            amount: expense,
                            color: Colors.redAccent,
                            icon: Icons.north_east,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SummaryCard(
                            title: '本月結餘',
                            amount: income - expense,
                            color: Colors.blue,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: <Widget>[
                  Tab(text: '支出分類', icon: Icon(Icons.shopping_bag_outlined)),
                  Tab(text: '收入分類', icon: Icon(Icons.savings_outlined)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    CategoryBreakdown(
                      records: thisMonth
                          .where((Expense r) => r.type == RecordType.expense)
                          .toList(),
                      emptyMessage: '本月還沒有支出。',
                    ),
                    CategoryBreakdown(
                      records: thisMonth
                          .where((Expense r) => r.type == RecordType.income)
                          .toList(),
                      emptyMessage: '本月還沒有收入。',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    required this.records,
    required this.emptyMessage,
    super.key,
  });

  final List<Expense> records;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final record in records) {
      totals[record.category] = (totals[record.category] ?? 0) + record.amount;
      counts[record.category] = (counts[record.category] ?? 0) + 1;
    }

    final entries = totals.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final largestAmount = entries.first.value;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        final progress = largestAmount == 0 ? 0.0 : entry.value / largestAmount;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatMoney(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${counts[entry.key]} 筆紀錄'),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 個人設定：姓名、每月預算都會存入 SharedPreferences。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.records,
    required this.userName,
    required this.monthlyBudget,
    required this.onSave,
    super.key,
  });

  final ValueListenable<List<Expense>> records;
  final String userName;
  final int monthlyBudget;
  final Future<void> Function(String name, int budget) onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _budgetController =
        TextEditingController(text: widget.monthlyBudget.toString());
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    final budget = int.tryParse(_budgetController.text.trim());

    if (name.isEmpty) {
      setState(() => _errorMessage = '請輸入使用者名稱。');
      return;
    }
    if (budget == null || budget <= 0) {
      setState(() => _errorMessage = '每月預算必須是大於 0 的整數。');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });
    await widget.onSave(name, budget);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Expense>>(
      valueListenable: widget.records,
      builder: (BuildContext context, List<Expense> allRecords, Widget? child) {
        final now = DateTime.now();
        final spent = allRecords
            .where((Expense record) =>
                record.type == RecordType.expense &&
                record.date.year == now.year &&
                record.date.month == now.month)
            .fold<int>(0, (int sum, Expense record) => sum + record.amount);
        final progress = widget.monthlyBudget <= 0
            ? 0.0
            : (spent / widget.monthlyBudget).clamp(0.0, 1.0).toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('設定你的基本資料與每月花費目標。'),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '使用者名稱',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每月預算',
                  border: OutlineInputBorder(),
                  prefixText: 'NT\$ ',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存設定'),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (spent > widget.monthlyBudget
                          ? Colors.redAccent
                          : Colors.green)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('本月預算使用進度',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, minHeight: 10),
                    const SizedBox(height: 8),
                    Text(
                      '${formatMoney(spent)} / ${formatMoney(widget.monthlyBudget)}'
                      '${spent > widget.monthlyBudget ? '（已超出預算）' : ''}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('進度條最多顯示到 100%；支出金額仍會照實列出。'),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.account_balance_wallet_outlined, size: 56),
          SizedBox(height: 16),
          Text(
            '我的智慧記帳 APP',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '這是一個 Flutter 練習作品，可以新增、查看、篩選與刪除收入和支出，'
            '並將紀錄與個人設定保存在本機。',
          ),
          SizedBox(height: 16),
          Text('練習使用：List、ValueNotifier、TabBar、Drawer、'
              'PopupMenuButton、AnimatedList 與 SharedPreferences。'),
        ],
      ),
    );
  }
}
