import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/delivery_api_service.dart';
import '../../theme/app_colors.dart';

class DeliveryManSelectionPage extends StatefulWidget {
  final int userId;
  final String userRole;
  final List<dynamic> selectedOrders;

  const DeliveryManSelectionPage({
    Key? key,
    required this.userId,
    required this.userRole,
    required this.selectedOrders,
  }) : super(key: key);

  @override
  State<DeliveryManSelectionPage> createState() => _DeliveryManSelectionPageState();
}

class _DeliveryManSelectionPageState extends State<DeliveryManSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  List<dynamic> _deliveryMen = [];
  Map<int, List<int>> _assignments = {}; // deliveryManId -> [orderIds]
  bool _isLoading = true;
  bool _isProcessing = false;
  String _assignmentMode = 'manual'; // 'manual' or 'auto'

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDeliveryMen();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  Future<void> _loadDeliveryMen() async {
    setState(() => _isLoading = true);

    try {
      // Pass distributor ID to fetch delivery men suitable for this distributor
      final response = await DeliveryApiService.getDeliveryMen(distributorId: widget.userId);
      final deliveryMen = response['deliveryMen'] ?? response['delivery_men'] ?? [];

      if (mounted) {
        setState(() {
          _deliveryMen = deliveryMen.where((dm) => dm['is_available'] == true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading delivery men: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load delivery personnel');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingScreen() : _buildSelectionContent(),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Assign Delivery Personnel',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) => setState(() => _assignmentMode = value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'manual',
              child: Row(
                children: [
                  Icon(Icons.touch_app, color: _assignmentMode == 'manual' ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Manual Assignment'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'auto',
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: _assignmentMode == 'auto' ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Smart Assignment'),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert, color: Colors.white),
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
          Text('Loading delivery personnel...'),
        ],
      ),
    );
  }

  Widget _buildSelectionContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          _buildOrderSummary(),
          _buildAssignmentModeToggle(),
          Expanded(
            child: _assignmentMode == 'manual' 
                ? _buildManualAssignment() 
                : _buildSmartAssignment(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders to Assign',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (widget.selectedOrders.isNotEmpty && _getTotalAssignedOrders() == 0)
                ElevatedButton.icon(
                  onPressed: () => _quickAssignAllOrders(),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Quick Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard('Orders', widget.selectedOrders.length.toString(), Icons.inventory_2, Colors.blue),
              const SizedBox(width: 12),
              _buildSummaryCard('Available Staff', _deliveryMen.length.toString(), Icons.person, Colors.green),
              const SizedBox(width: 12),
              _buildSummaryCard('Total Value', '\$${_calculateTotalValue().toInt()}', Icons.attach_money, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
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
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _assignmentMode = 'manual'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _assignmentMode == 'manual' ? AppColors.primary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: _assignmentMode == 'manual' ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manual',
                      style: TextStyle(
                        color: _assignmentMode == 'manual' ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _assignmentMode = 'auto'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _assignmentMode == 'auto' ? AppColors.primary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: _assignmentMode == 'auto' ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Smart AI',
                      style: TextStyle(
                        color: _assignmentMode == 'auto' ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualAssignment() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deliveryMen.length,
      itemBuilder: (context, index) {
        final deliveryMan = _deliveryMen[index];
        final assignedOrders = _assignments[deliveryMan['id']] ?? [];
        
        return _buildDeliveryManCard(deliveryMan, assignedOrders);
      },
    );
  }

  Widget _buildDeliveryManCard(Map<String, dynamic> deliveryMan, List<int> assignedOrders) {
    final deliveryManId = deliveryMan['id'];
    final name = deliveryMan['name'] ?? 'Unknown';
    final rating = double.tryParse(deliveryMan['rating']?.toString() ?? '0') ?? 0.0;
    final vehicleType = deliveryMan['vehicle_type'] ?? 'Vehicle';
    final phone = deliveryMan['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'D',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                Text(' $rating'),
                const SizedBox(width: 16),
                Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                Text(' $vehicleType'),
              ],
            ),
            if (assignedOrders.isNotEmpty)
              Text(
                '${assignedOrders.length} orders assigned',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phone.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(phone),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Orders:', style: TextStyle(fontWeight: FontWeight.w600)),
                    if (widget.selectedOrders.isNotEmpty && assignedOrders.length < widget.selectedOrders.length)
                      TextButton.icon(
                        onPressed: () => _assignRemainingOrdersToDeliveryMan(deliveryManId),
                        icon: const Icon(Icons.add_circle, size: 16),
                        label: const Text('Add All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedOrders.map((order) {
                    final orderId = order['id'];
                    final isAssigned = assignedOrders.contains(orderId);
                    
                    return GestureDetector(
                      onTap: () => _toggleOrderAssignment(deliveryManId, orderId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAssigned ? AppColors.primary : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAssigned ? AppColors.primary : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$orderId',
                              style: TextStyle(
                                color: isAssigned ? Colors.white : Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isAssigned) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check, size: 12, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartAssignment() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI-Powered Smart Assignment',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Our intelligent algorithm will automatically assign orders based on:\n\n• Delivery man location and capacity\n• Order priority and delivery zones\n• Historical performance data\n• Route optimization',
            style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _performSmartAssignment,
            icon: const Icon(Icons.smart_toy),
            label: const Text('Start Smart Assignment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final hasAssignments = _assignments.values.any((orders) => orders.isNotEmpty);
    
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
                    '${_getTotalAssignedOrders()} of ${widget.selectedOrders.length} orders assigned',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_assignments.keys.length} delivery personnel selected',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () => setState(() => _assignments.clear()),
              child: const Text('Clear All'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: hasAssignments && !_isProcessing ? _processAssignments : null,
              icon: _isProcessing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Assign Orders'),
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
  void _toggleOrderAssignment(int deliveryManId, int orderId) {
    setState(() {
      // Remove order from other delivery men first
      _assignments.forEach((key, orders) {
        orders.remove(orderId);
      });

      // Add to selected delivery man
      if (_assignments[deliveryManId] == null) {
        _assignments[deliveryManId] = [];
      }
      
      if (!_assignments[deliveryManId]!.contains(orderId)) {
        _assignments[deliveryManId]!.add(orderId);
      }
    });

    HapticFeedback.lightImpact();
  }

  void _assignRemainingOrdersToDeliveryMan(int deliveryManId) {
    setState(() {
      // Get all unassigned orders
      final allAssignedOrders = _assignments.values.expand((orders) => orders).toSet();
      final unassignedOrders = widget.selectedOrders
          .where((order) => !allAssignedOrders.contains(order['id']))
          .map((order) => order['id'] as int)
          .toList();

      // Add unassigned orders to this delivery man
      if (_assignments[deliveryManId] == null) {
        _assignments[deliveryManId] = [];
      }
      
      _assignments[deliveryManId]!.addAll(unassignedOrders);
    });

    HapticFeedback.mediumImpact();
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${widget.selectedOrders.length - _getTotalAssignedOrders() + _assignments[deliveryManId]!.length} orders to delivery person'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _quickAssignAllOrders() {
    if (_deliveryMen.isEmpty) {
      _showErrorSnackBar('No delivery personnel available');
      return;
    }

    setState(() {
      // Clear existing assignments
      _assignments.clear();
      
      // Distribute orders evenly among available delivery men
      final ordersPerPerson = (widget.selectedOrders.length / _deliveryMen.length).ceil();
      int orderIndex = 0;
      
      for (int i = 0; i < _deliveryMen.length && orderIndex < widget.selectedOrders.length; i++) {
        final deliveryManId = _deliveryMen[i]['id'];
        _assignments[deliveryManId] = [];
        
        // Assign orders to this delivery man
        for (int j = 0; j < ordersPerPerson && orderIndex < widget.selectedOrders.length; j++) {
          _assignments[deliveryManId]!.add(widget.selectedOrders[orderIndex]['id']);
          orderIndex++;
        }
      }
    });

    HapticFeedback.mediumImpact();
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Quick assigned ${widget.selectedOrders.length} orders to ${_deliveryMen.length} delivery personnel'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  int _getTotalAssignedOrders() {
    return _assignments.values.fold(0, (sum, orders) => sum + orders.length);
  }

  double _calculateTotalValue() {
    return widget.selectedOrders.fold(0.0, (sum, order) => sum + (double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0));
  }

  Future<void> _performSmartAssignment() async {
    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulate AI processing
      
      await DeliveryApiService.performSmartAssignment();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Smart assignment completed successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        
        // Go back to the smart assignment dashboard
        Navigator.pop(context, true); // Return true to indicate successful assignment
      }
    } catch (e) {
      _showErrorSnackBar('Smart assignment failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processAssignments() async {
    setState(() => _isProcessing = true);

    try {
      final assignments = <Map<String, int>>[];
      
      _assignments.forEach((deliveryManId, orderIds) {
        for (final orderId in orderIds) {
          assignments.add({
            'order_id': orderId,
            'delivery_man_id': deliveryManId,
          });
        }
      });

      await DeliveryApiService.bulkAssignOrders(assignments);
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully assigned ${assignments.length} orders'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        
        // Go back to the smart assignment dashboard
        Navigator.pop(context, true); // Return true to indicate successful assignment
      }
    } catch (e) {
      _showErrorSnackBar('Assignment failed: $e');
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
