import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/supermarket_bottom_nav.dart';
import 'BrowseProduct_Page.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({Key? key}) : super(key: key);

  @override
  _OffersPageState createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  @override
  void initState() {
    super.initState();
    // Navigate to browse products with offers filter enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToBrowseProductsWithOffers();
    });
  }

  void _navigateToBrowseProductsWithOffers() {
    // Use pushReplacement to replace the loading screen with the actual offers page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BrowseProductsPage(
          enableOffersFilter: true,
          showBottomNav: true,
          currentNavIndex: 1, // Browse Products index (offers is a filtered view)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading offers...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SuperMarketBottomNav(
        currentIndex: 3,
        onTap: (index) {
          Navigator.pushReplacementNamed(
            context,
            '/supermarket',
            arguments: {'initialIndex': index},
          );
        },
      ),
    );
  }
}
