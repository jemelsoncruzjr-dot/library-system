import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/loading_view.dart';
import 'admin_dashboard_page.dart';
import 'dashboard_page.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AuthService().userStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorView(
              message: '${snapshot.error}',
              onSignOut: () => AuthService().logout(),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: LoadingView());
        }
        final data = snapshot.data!.data();
        final role = data?['role'];
        if (data != null && (role == 'admin' || role == 'librarian')) {
          return AdminDashboardPage(adminUid: uid, adminData: data);
        }
        return const DashboardPage();
      },
    );
  }
}
