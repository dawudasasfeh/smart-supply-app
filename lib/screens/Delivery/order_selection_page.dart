import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/delivery_api_service.dart';
import '../../theme/app_colors.dart';
import 'delivery_man_selection_page.dart';

class OrderSelectionPage extends StatefulWidget {
  final int userId;
  final String userRole;

  const OrderSelectionPage({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<OrderSelectionPage> createState() => _OrderSelectionPageState();
}

class _OrderSelectionPageState extends State<OrderSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _filterController;
  late AnimationController _selectionController;
  late Animation<double> _filterAnimation;
  late Animation<double> _selectionAnimation;

  // Data variables
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  Set<int> _selectedOrders = {};

  // Filter variables
  bool _showFilters = false;
  String _searchQuery = '';
  double _minAmount = 0;
  double _maxAmount = 1000;
  DateTime? _selectedDate;

  // Loading states
  bool _isLoading = true;
  bool _isProcessing = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadOrders();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _selectionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _filterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filterController,
      curve: Curves.easeInOut,
    ));

    _selectionAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _selectionController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      // Get pending orders for the logged-in distributor
      final response = await DeliveryApiService.getPendingOrders(distributorId: widget.userId);
      final pendingOrders = response['data'] ?? response['orders'] ?? [];

      if (mounted) {
        setState(() {
          _allOrders = pendingOrders;
          _filteredOrders = List.from(pendingOrders);
          _isLoading = false;
        });
        _updateMaxAmount();
      }
    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load orders: $e');
      }
    }
  }

  void _updateMaxAmount() {
    if (_allOrders.isNotEmpty) {
      final amounts = _allOrders
          .map((order) => double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0)
          .toList();
      setState(() {
        _maxAmount = amounts.reduce((a, b) => a > b ? a : b);
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
          final orderId = order['id'].toString();
          final address = (order['delivery_address'] ?? '').toString().toLowerCase();
          
          if (!customerName.contains(searchLower) && 
              !orderId.contains(searchLower) && 
              !address.contains(searchLower)) {
            return false;
          }
        }

        // Amount filter
        final amount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
        if (amount < _minAmount || amount > _maxAmount) {
          return false;
        }

        // Date filter
        if (_selectedDate != null) {
          final orderDate = DateTime.parse(order['created_at'] ?? '');
          if (!_isSameDay(orderDate, _selectedDate!)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildOrderSelectionContent(),
      bottomNavigationBar: _selectedOrders.isNotEmpty ? _buildBottomActionBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Select Orders',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () {
            setState(() => _showFilters = !_showFilters);
            if (_showFilters) {
              _filterController.forward();
            } else {
              _filterController.reverse();
            }
          },
          icon: AnimatedRotation(
            turns: _showFilters ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ),
        IconButton(
          onPressed: _loadOrders,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading orders...'),
        ],
      ),
    );
  }

  Widget _buildOrderSelectionContent() {
    return Column(
      children: [
        _buildSearchBar(),
        if (_showFilters) _buildFilterPanel(),
        _buildOrderStats(),
        Expanded(child: _buildOrdersList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search orders, customers, or addresses...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedBuilder(
      animation: _filterAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _filterAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAmountRangeFilter(),
                const SizedBox(height: 16),
                _buildDateFilter(),
                const SizedBox(height: 16),
                _buildFilterActions(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Amount Range: \$${_minAmount.toInt()} - \$${_maxAmount.toInt()}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(_minAmount, _maxAmount),
          min: 0,
          max: _allOrders.isNotEmpty 
              ? _allOrders.map((o) => double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0).reduce((a, b) => a > b ? a : b)
              : 1000,
          divisions: 20,
          labels: RangeLabels(
            '\$${_minAmount.toInt()}',
            '\$${_maxAmount.toInt()}',
          ),
          onChanged: (values) {
            setState(() {
              _minAmount = values.start;
              _maxAmount = values.end;
            });
            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _selectedDate != null
                ? 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                : 'All Dates',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 7)),
            );
            if (date != null) {
              setState(() => _selectedDate = date);
              _applyFilters();
            }
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Select Date'),
        ),
        if (_selectedDate != null)
          IconButton(
            onPressed: () {
              setState(() => _selectedDate = null);
              _applyFilters();
            },
            icon: const Icon(Icons.clear, size: 16),
          ),
      ],
    );
  }

  Widget _buildFilterActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _minAmount = 0;
                _maxAmount = _allOrders.isNotEmpty 
                    ? _allOrders.map((o) => double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0).reduce((a, b) => a > b ? a : b)
                    : 1000;
                _selectedDate = null;
                _searchQuery = '';
                _searchController.clear();
              });
              _applyFilters();
            },
            child: const Text('Clear Filters'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() => _showFilters = false);
              _filterController.reverse();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              'Total Orders',
              _filteredOrders.length.toString(),
              Icons.inventory_2,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatChip(
              'Selected',
              _selectedOrders.length.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatChip(
              'Total Value',
              '\$${_calculateSelectedValue().toInt()}',
              Icons.attach_money,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        final orderId = order['id'] ?? 0;
        final isSelected = _selectedOrders.contains(orderId);

        return AnimatedBuilder(
          animation: _selectionAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? _selectionAnimation.value : 1.0,
              child: _buildOrderCard(order, isSelected),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isSelected) {
    final orderId = order['id'] ?? 0;
    final customerName = order['customer_name'] ?? 'Unknown Customer';
    final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
    final deliveryAddress = order['delivery_address'] ?? 'No address';
    final createdAt = order['created_at'] ?? '';

    return GestureDetector(
      onTap: () => _toggleOrderSelection(orderId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.shopping_bag,
                      color: isSelected ? AppColors.primary : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\$${totalAmount.toInt()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      deliveryAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DeliveryApiService.formatTimeAgo(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _minAmount = 0;
                _maxAmount = _allOrders.isNotEmpty 
                    ? _allOrders.map((o) => double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0).reduce((a, b) => a > b ? a : b)
                    : 1000;
                _selectedDate = null;
                _searchQuery = '';
                _searchController.clear();
              });
              _applyFilters();
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All Filters'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedOrders.length} orders selected',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Total: \$${_calculateSelectedValue().toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _selectedOrders.clear());
              },
              child: const Text('Clear'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _proceedToDeliverySelection,
              icon: _isProcessing 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  void _toggleOrderSelection(int orderId) {
    setState(() {
      if (_selectedOrders.contains(orderId)) {
        _selectedOrders.remove(orderId);
      } else {
        _selectedOrders.add(orderId);
      }
    });

    // Trigger selection animation
    _selectionController.forward().then((_) {
      _selectionController.reverse();
    });

    HapticFeedback.lightImpact();
  }

  double _calculateSelectedValue() {
    return _filteredOrders
        .where((order) => _selectedOrders.contains(order['id']))
        .fold(0.0, (sum, order) => sum + (double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0));
  }

  Future<void> _proceedToDeliverySelection() async {
    if (_selectedOrders.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Get selected orders data
      final selectedOrdersData = _filteredOrders
          .where((order) => _selectedOrders.contains(order['id']))
          .toList();

      await Future.delayed(const Duration(milliseconds: 500)); // Simulate processing

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryManSelectionPage(
              userId: widget.userId,
              userRole: widget.userRole,
              selectedOrders: selectedOrdersData,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to proceed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
