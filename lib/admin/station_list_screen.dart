import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/station_card.dart';
import 'package:zupito/models/station.dart';

class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  List<Station> _stations = []; // Use the Station model for type safety
  bool _isLoading = true;
  String? _error; // Added an error state

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    try {
      final List<dynamic> stationData = await AdminApiService.fetchStations();
      setState(() {
        _stations = stationData
            .where((json) => json is Map<String, dynamic>)
            .map((json) => Station.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to fetch stations: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Error fetching stations: $e'); // Log the error for debugging
      if (mounted) {
        // Check if the widget is still in the tree
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to handle station deletion
  Future<void> _deleteStation(String stationId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this station?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true; // Show loading while deleting
      });
      try {
        await AdminApiService.deleteStation(stationId);
        _fetchStations(); // Refresh the list after deletion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Station deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete station: ${e.toString().replaceFirst('Exception: ', '')}',
              ),
            ),
          );
        }
        print('Error deleting station: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to show Add Station dialog
  Future<void> _showAddStationDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    final TextEditingController capacityController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update dialog UI
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Station'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Station Name',
                      ),
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
                    TextField(
                      controller: capacityController,
                      decoration: const InputDecoration(labelText: 'Capacity'),
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
                    setState(() {
                      dialogError = null;
                    }); // Clear dialog error
                    final name = nameController.text.trim();
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    final capacity = int.tryParse(
                      capacityController.text.trim(),
                    );

                    if (name.isEmpty ||
                        lat == null ||
                        lng == null ||
                        capacity == null) {
                      setState(() {
                        dialogError = 'Please fill all fields with valid data.';
                      });
                      return;
                    }

                    try {
                      await AdminApiService.addStation({
                        'name': name,
                        'latitude': lat,
                        'longitude': lng,
                        'capacity': capacity,
                      });
                      _fetchStations(); // Refresh list
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Station added successfully!'),
                          ),
                        );
                      }
                      Navigator.pop(context); // Close dialog
                    } catch (e) {
                      setState(() {
                        dialogError =
                            'Failed to add station: ${e.toString().replaceFirst('Exception: ', '')}';
                      });
                      print('Error adding station: $e');
                    }
                  },
                  child: const Text('Add Station'),
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
    return RefreshIndicator(
      onRefresh: _fetchStations,
      child: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _fetchStations,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _stations.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                      height: 320,
                      child: Center(
                        child: Text(
                          'No stations found. Click + to add one.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: _stations.length,
                  itemBuilder: (context, index) {
                    final station = _stations[index];
                    return StationCard(
                      station: station,
                      onDelete: () => _deleteStation(station.id),
                    );
                  },
                ),
          // Floating Action Button for adding stations
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddStationDialog,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
