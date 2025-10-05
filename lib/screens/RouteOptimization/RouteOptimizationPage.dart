import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/route_optimization_service.dart';
import '../../services/api_service.dart';
import '../../widgets/integrated_map_widget.dart';

class RouteOptimizationPage extends StatefulWidget {
  const RouteOptimizationPage({Key? key}) : super(key: key);

  @override
  State<RouteOptimizationPage> createState() => _RouteOptimizationPageState();
}

class _RouteOptimizationPageState extends State<RouteOptimizationPage> {
  bool _isLoading = false;
  bool _isLoadingOrders = false;
  List<Map<String, dynamic>> _ordersForOptimization = [];
  Map<String, dynamic>? _currentDeliveryMan;
  Map<String, dynamic>? _currentSession;
  Map<String, dynamic>? _optimizationResults;
  String _selectedAlgorithm = 'nearest_neighbor';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Get current logged-in delivery man
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;
      
      // Create delivery man profile immediately (no API call needed)
      final currentDeliveryMan = {
        'id': userId,
        'name': 'Current User',
        'rating': 4.5,
        'phone': 'N/A',
        'current_orders': 0,
      };
      
      setState(() {
        _currentDeliveryMan = currentDeliveryMan;
        _isLoading = false; // Stop main loading immediately
      });
      
      // Try to load delivery men details in background (non-blocking)
      _loadDeliveryManDetailsInBackground(userId);
      
      // Load orders for this delivery man in background (non-blocking)
      // We'll load orders after the delivery man details are loaded
    } catch (e) {
      _showErrorSnackBar('Failed to load initial data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliveryManDetailsInBackground(int userId) async {
    try {
      // Try to get delivery man details with timeout
      final deliveryMen = await ApiService.getAvailableDeliveryMen().timeout(
        const Duration(seconds: 10),
        onTimeout: () => <Map<String, dynamic>>[],
      );
      
      // Try to find the current delivery man by user ID
      try {
        final foundDeliveryMan = deliveryMen.firstWhere(
          (dm) => dm['user_id'] == userId || dm['id'] == userId,
        );
        
        // Update with real data if found
        setState(() {
          _currentDeliveryMan = foundDeliveryMan;
        });
        
        // Load orders for this delivery man using the correct delivery man ID
        _loadOrdersForDeliveryMan(foundDeliveryMan['id']);
      } catch (e) {
        // If not found, fallback to first available active delivery man to avoid empty state
        if (deliveryMen.isNotEmpty) {
          final fallbackDeliveryMan = deliveryMen.first;
          setState(() {
            _currentDeliveryMan = fallbackDeliveryMan;
          });
          _loadOrdersForDeliveryMan(fallbackDeliveryMan['id']);
        } else {
          // Keep the fallback profile, log for debugging
          print('Delivery man not found and list is empty. Using fallback profile');
        }
      }
    } catch (e) {
      // Keep the fallback profile, no need to update
      print('Failed to load delivery man details: $e');
    }
  }

  Future<void> _loadOrdersForDeliveryMan(int deliveryManId) async {
    if (_currentDeliveryMan == null) return;
    
    setState(() => _isLoadingOrders = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final distributorId = prefs.getInt('distributor_id') ?? 4; // Default distributor ID
      
      // Load orders with timeout
      final orders = await RouteOptimizationService.getOrdersForOptimization(
        deliveryManId: deliveryManId,
        distributorId: distributorId,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => <Map<String, dynamic>>[],
      );
      
      setState(() {
        _ordersForOptimization = orders;
      });
    } catch (e) {
      print('Failed to load orders: $e');
      // Set empty orders list instead of showing error
      setState(() {
        _ordersForOptimization = [];
      });
    } finally {
      setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _createOptimizationSession() async {
    if (_currentDeliveryMan == null) {
      _showErrorSnackBar('Delivery man not found. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final distributorId = prefs.getInt('distributor_id') ?? 4; // Default distributor ID
      
      final session = await RouteOptimizationService.createOptimizationSession(
        sessionName: 'Route Optimization - ${_currentDeliveryMan!['name']}',
        deliveryManId: _currentDeliveryMan!['id'], // This is now the correct delivery_men.id
        distributorId: distributorId,
        algorithm: _selectedAlgorithm,
      );
      
      setState(() {
        _currentSession = session;
      });
      
      _showSuccessSnackBar('Optimization session created successfully');
      
    } catch (e) {
      print('Session creation failed: $e');
      _showErrorSnackBar('Failed to create session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _optimizeRoute() async {
    if (_currentSession == null || _currentDeliveryMan == null) {
      _showErrorSnackBar('Please create a session first');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final distributorId = prefs.getInt('distributor_id') ?? 4; // Default distributor ID
      
      final results = await RouteOptimizationService.optimizeRoute(
        sessionId: _currentSession!['id'],
        deliveryManId: _currentDeliveryMan!['id'], // This is now the correct delivery_men.id
        distributorId: distributorId,
        algorithm: _selectedAlgorithm,
      );
      
      setState(() {
        _optimizationResults = results;
      });
      
      _showSuccessSnackBar('Route optimized successfully!');
      
      // Show results dialog
      _showOptimizationResultsDialog(results);
    } catch (e) {
      print('Route optimization failed: $e');
      _showErrorSnackBar('Failed to optimize route: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showOptimizationResultsDialog(Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route Optimization Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              _buildResultRow('Total Distance', RouteOptimizationService.formatDistance(results['optimizationResults']['totalDistance'])),
              _buildResultRow('Total Duration', RouteOptimizationService.formatDuration(results['optimizationResults']['totalDuration'])),
              _buildResultRow('Fuel Cost', 'EGP ${(results['optimizationResults']['fuelCost'] is num ? results['optimizationResults']['fuelCost'] : double.tryParse(results['optimizationResults']['fuelCost']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}'),
              _buildResultRow('Optimization Score', '${(results['optimizationResults']['optimizationScore'] is num ? results['optimizationResults']['optimizationScore'] : double.tryParse(results['optimizationResults']['optimizationScore']?.toString() ?? '0') ?? 0.0).toStringAsFixed(1)}/100'),
              _buildResultRow('Orders Count', '${(results['optimizationResults']['waypoints'] ?? results['optimizationResults']['optimizedRoute'] ?? []).length}'),
              const SizedBox(height: 16),
              const Text('Optimized Route:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(results['optimizationResults']['waypoints'] ?? results['optimizationResults']['optimizedRoute'] ?? []).map<Widget>((waypoint) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${waypoint['sequence'] ?? '•'}. ',
                        style: TextStyle(
                          color: waypoint['type'] == 'depot' ? Colors.blue : Colors.black87,
                          fontWeight: waypoint['type'] == 'depot' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${waypoint['address'] ?? waypoint['deliveryCode'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: waypoint['type'] == 'depot' ? Colors.blue : Colors.black87,
                            fontWeight: waypoint['type'] == 'depot' ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              // Open integrated map with route information
              _openIntegratedMap(results);
            },
            icon: const Icon(Icons.map),
            label: const Text('View Route on Map'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openIntegratedMap(Map<String, dynamic> results) {
    // Extract location information from results
    String? address;
    double? latitude;
    double? longitude;

    // Try to get location from optimized route or delivery locations
    if (results['optimizedRoute'] != null && results['optimizedRoute'].isNotEmpty) {
      final firstLocation = results['optimizedRoute'][0];
      address = firstLocation['address'];
      latitude = firstLocation['latitude']?.toDouble();
      longitude = firstLocation['longitude']?.toDouble();
    } else if (results['deliveryLocations'] != null && results['deliveryLocations'].isNotEmpty) {
      final firstLocation = results['deliveryLocations'][0];
      address = firstLocation['address'];
      latitude = firstLocation['latitude']?.toDouble();
      longitude = firstLocation['longitude']?.toDouble();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedMapWidget(
          address: address,
          latitude: latitude,
          longitude: longitude,
          title: 'Optimized Route',
          showNavigationButton: true,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Route Optimization',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.help_outline,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  
                  // Current Delivery Man Info
                  _buildCurrentDeliveryManInfo(),
                  const SizedBox(height: 20),
                  
                  // Algorithm Selection
                  _buildAlgorithmSelection(),
                  const SizedBox(height: 20),
                  
                  // Orders Preview
                  if (_currentDeliveryMan != null) _buildOrdersPreview(),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  _buildActionButtons(),
                  
                  const SizedBox(height: 20),
                  
                  // Current Session Info
                  if (_currentSession != null) _buildSessionInfo(),
                  
                  const SizedBox(height: 20),
                  
                  // Optimization Results
                  if (_optimizationResults != null) _buildOptimizationResults(),
                  
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentDeliveryManInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Current Delivery Man',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentDeliveryMan == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delivery man information not available. Please log in again.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    _currentDeliveryMan!['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentDeliveryMan!['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating: ${_currentDeliveryMan!['rating'] is num ? _currentDeliveryMan!['rating'].toStringAsFixed(1) : _currentDeliveryMan!['rating']?.toString() ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${_currentDeliveryMan!['phone'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlgorithmSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Optimization Algorithm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAlgorithm,
            decoration: InputDecoration(
              labelText: 'Choose optimization method',
              labelStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: const [
              DropdownMenuItem(
                value: 'nearest_neighbor',
                child: Row(
                  children: [
                    Icon(Icons.near_me, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Nearest Neighbor'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'genetic',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Genetic Algorithm'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'simulated_annealing',
                child: Row(
                  children: [
                    Icon(Icons.thermostat, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('Simulated Annealing'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedAlgorithm = value!;
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.purple.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getAlgorithmDescription(_selectedAlgorithm),
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAlgorithmDescription(String algorithm) {
    switch (algorithm) {
      case 'nearest_neighbor':
        return 'Fast and simple algorithm that finds the nearest unvisited location at each step.';
      case 'genetic':
        return 'Advanced algorithm that uses evolutionary principles to find near-optimal solutions.';
      case 'simulated_annealing':
        return 'Probabilistic algorithm that can escape local optima to find better solutions.';
      default:
        return '';
    }
  }

  Widget _buildOrdersPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Orders for Optimization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_isLoadingOrders)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          if (_currentDeliveryMan != null) {
                            _loadOrdersForDeliveryMan(_currentDeliveryMan!['id']);
                          }
                        },
                        tooltip: 'Refresh orders',
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_ordersForOptimization.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingOrders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading orders...'),
                    ],
                  ),
                ),
              )
            else if (_ordersForOptimization.isEmpty)
              const Text('No orders available for optimization')
            else
              Column(
                children: [
                  ..._ordersForOptimization.take(5).map((order) => 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order['delivery_address'] ?? 'Unknown Address',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            'EGP ${order['total_amount'] is num ? order['total_amount'].toStringAsFixed(2) : order['total_amount']?.toString() ?? '0.00'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                  if (_ordersForOptimization.length > 5)
                    Text(
                      '... and ${_ordersForOptimization.length - 5} more orders',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Optimization Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentDeliveryMan != null && _currentSession == null ? _createOptimizationSession : null,
                  icon: Icon(_currentSession == null ? Icons.add_circle_outline : Icons.check_circle),
                  label: Text(_currentSession == null ? 'Create Session' : 'Session Active'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentSession == null ? Colors.green.shade600 : Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentSession != null && _optimizationResults == null ? _optimizeRoute : null,
                  icon: Icon(_currentSession != null ? Icons.rocket_launch : Icons.lock),
                  label: Text(_currentSession != null ? 'Optimize Route' : 'Create Session First'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentSession != null ? Colors.blue.shade600 : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          if (_currentDeliveryMan == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Loading delivery man information...',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Session',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Session Name', _currentSession!['sessionName'] ?? 'Unknown'),
            _buildInfoRow('Status', _currentSession!['status'] ?? 'Unknown'),
            _buildInfoRow('Algorithm', _currentSession!['algorithm'] ?? 'Unknown'),
            _buildInfoRow('Created', _formatDateTime(_currentSession!['created_at'])),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationResults() {
    final results = _optimizationResults!['optimizationResults'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optimization Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Total Distance', RouteOptimizationService.formatDistance(results['totalDistance'])),
            _buildInfoRow('Total Duration', RouteOptimizationService.formatDuration(results['totalDuration'])),
            _buildInfoRow('Fuel Cost', 'EGP ${results['fuelCost'] is num ? results['fuelCost'].toStringAsFixed(2) : results['fuelCost']?.toString() ?? '0.00'}'),
            _buildInfoRow('Optimization Score', '${results['optimizationScore'] is num ? results['optimizationScore'].toStringAsFixed(1) : results['optimizationScore']?.toString() ?? '0.0'}/100'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Open integrated map with optimization results
                  _openIntegratedMap(_optimizationResults!);
                },
                icon: const Icon(Icons.map),
                label: const Text('Open in Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Route Optimization...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we prepare your optimization tools',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.route,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Route Optimization',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart algorithm-powered optimization',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Optimize your delivery routes to save time, reduce fuel costs, and improve customer satisfaction with our smart routing algorithms.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildHeaderFeature('Time Saving', Icons.timer, Colors.white),
              _buildHeaderFeature('Fuel Efficient', Icons.local_gas_station, Colors.white),
              _buildHeaderFeature('Google Maps', Icons.map, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFeature(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

}
