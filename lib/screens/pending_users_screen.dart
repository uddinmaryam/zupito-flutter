import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';

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

  Future<void> approveUser(String userId) async {
    try {
      await AdminApiService.approveUser(userId);
      fetchPendingUsers(); // Refresh list after approval
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve user: ${e.toString()}')),
      );
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      await AdminApiService.rejectUser(userId);
      fetchPendingUsers(); // Refresh list after rejection
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject user: ${e.toString()}')),
      );
    }
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
                        return ListTile(
                          leading: (user['citizenshipImage'] != null &&
                                  user['citizenshipImage'] != "")
                              ? CircleAvatar(
                                  radius: 26,
                                  backgroundImage:
                                      NetworkImage(user['citizenshipImage']),
                                  backgroundColor: Colors.grey[200],
                                )
                              : const Icon(Icons.person, size: 32),
                          title: Text(user['username'] ?? 'No Name'),
                          subtitle: Text(user['email'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: 'Approve',
                                onPressed: () => approveUser(user['_id']),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                tooltip: 'Reject',
                                onPressed: () => rejectUser(user['_id']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
