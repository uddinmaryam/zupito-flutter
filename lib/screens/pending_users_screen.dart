import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';

const String backendBaseUrl = "https://backend-bicycle-1.onrender.com";

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({Key? key}) : super(key: key);

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  List<dynamic> pendingUsers = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchPendingUsers();
  }

  Future<void> fetchPendingUsers() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final users = await AdminApiService.fetchPendingUsers();
      setState(() {
        pendingUsers = users;
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> verifyUser(String userId) async {
    try {
      await AdminApiService.approveUser(userId);
      fetchPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve user: ${e.toString()}')),
      );
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      await AdminApiService.rejectUser(userId);
      fetchPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject user: ${e.toString()}')),
      );
    }
  }

  // Build full citizenship image URL robustly
  String? getCitizenshipImageUrl(dynamic user) {
    if (user['citizenshipImage'] == null || user['citizenshipImage'].isEmpty)
      return null;
    final path = user['citizenshipImage'];
    // If path already starts with http, return as is
    if (path.startsWith('http')) return path;
    // Otherwise, prepend backendBaseUrl
    return backendBaseUrl + (path.startsWith('/') ? path : '/$path');
  }

  void showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget buildUserInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users Waiting for Verification')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : pendingUsers.isEmpty
                  ? const Center(child: Text('No pending users'))
                  : ListView.separated(
                      itemCount: pendingUsers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = pendingUsers[index];
                        final citizenshipImageUrl =
                            getCitizenshipImageUrl(user);
                        return Card(
                          margin: const EdgeInsets.all(10),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    citizenshipImageUrl != null
                                        ? GestureDetector(
                                            onTap: () => showImageDialog(
                                                citizenshipImageUrl),
                                            child: CircleAvatar(
                                              radius: 32,
                                              backgroundImage: NetworkImage(
                                                  citizenshipImageUrl),
                                              backgroundColor: Colors.grey[200],
                                            ),
                                          )
                                        : const Icon(Icons.person,
                                            size: 42, color: Colors.grey),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user['username'] ?? 'No Name',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                          Text(user['email'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.black87)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          tooltip: 'Approve',
                                          onPressed: () =>
                                              verifyUser(user['_id']),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          tooltip: 'Reject',
                                          onPressed: () =>
                                              rejectUser(user['_id']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // All user info
                                buildUserInfoRow(
                                  icon: Icons.phone,
                                  label: "Phone",
                                  value: user['phone'] ?? "N/A",
                                ),
                                buildUserInfoRow(
                                  icon: Icons.badge,
                                  label: "Role",
                                  value: user['role'] ?? "N/A",
                                ),
                                buildUserInfoRow(
                                  icon: Icons.credit_card,
                                  label: "Citizenship No",
                                  value: user['citizenshipNumber'] ?? "N/A",
                                ),
                                // Add more info if needed
                                // Large image preview
                                if (citizenshipImageUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12, bottom: 5),
                                    child: GestureDetector(
                                      onTap: () =>
                                          showImageDialog(citizenshipImageUrl),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          citizenshipImageUrl,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
