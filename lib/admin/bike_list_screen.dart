import 'package:flutter/material.dart';
// Corrected import path for AdminApiService
import 'package:zupito/services/admin_api_service.dart';
// Corrected import path for BikeCard
import 'package:zupito/widgets/bike_card.dart';
// Import the Bike model (will be defined next)
import 'package:zupito/models/bike.dart';

class BikeListScreen extends StatefulWidget {
  const BikeListScreen({super.key});

  @override
  State<BikeListScreen> createState() => _BikeListScreenState();
}

class _BikeListScreenState extends State<BikeListScreen> {
  List<Bike> _bikes = []; // Use the Bike model for type safety
  bool _isLoading = true;
  String? _error; // Added an error state

  @override
  void initState() {
    super.initState();
    _fetchBikes();
  }

  Future<void> _fetchBikes() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    try {
      final List<dynamic> bikeData = await AdminApiService.fetchBikes();
      setState(() {
        // Map the raw JSON data to a list of Bike objects
        _bikes = bikeData.map((json) => Bike.fromJson(json)).toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch bikes: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Error fetching bikes: $e'); // Log the error for debugging
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to handle bike deletion
  Future<void> _deleteBike(String bikeId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this bike?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true; // Show loading while deleting
      });
      try {
        await AdminApiService.deleteBike(bikeId);
        _fetchBikes(); // Refresh the list after deletion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bike deleted successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete bike: ${e.toString().replaceFirst('Exception: ', '')}')));
        }
        print('Error deleting bike: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to show Add Bike dialog
  Future<void> _showAddBikeDialog() async {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog UI
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Bike'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'Bike Code'),
                    ),
                    TextField(
                      controller: latController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: lngController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: TextInputType.number,
                    ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() { dialogError = null; }); // Clear dialog error
                    final code = codeController.text.trim();
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());

                    if (code.isEmpty || lat == null || lng == null) {
                      setState(() {
                        dialogError = 'Please fill all fields with valid data.';
                      });
                      return;
                    }

                    try {
                      await AdminApiService.addBike({
                        'code': code,
                        'isAvailable': true, // Default to true when adding
                        'location': {'lat': lat, 'lng': lng},
                        // 'assignedStation': null, // Backend handles default or can be added here if needed
                      });
                      _fetchBikes(); // Refresh list
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bike added successfully!')));
                      }
                      Navigator.pop(context); // Close dialog
                    } catch (e) {
                      setState(() {
                        dialogError = 'Failed to add bike: ${e.toString().replaceFirst('Exception: ', '')}';
                      });
                      print('Error adding bike: $e');
                    }
                  },
                  child: const Text('Add Bike'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // Removed AppBar as it's handled by AdminHomeScreen
    return RefreshIndicator( // Added RefreshIndicator for pull-to-refresh
      onRefresh: _fetchBikes,
      child: Stack( // Use Stack to position the FloatingActionButton
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _fetchBikes,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _bikes.isEmpty
                      ? const Center(
                          child: Text(
                            'No bikes found. Click + to add one.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _bikes.length,
                          itemBuilder: (context, index) {
                            final bike = _bikes[index];
                            return BikeCard(
                              bike: bike,
                              onDelete: () => _deleteBike(bike.id), // Pass delete callback
                            );
                          },
                        ),
          // Floating Action Button for adding bikes
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddBikeDialog,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
