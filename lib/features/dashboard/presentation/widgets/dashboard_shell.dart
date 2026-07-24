import 'package:flutter/material.dart';
import 'dashboard_sidebar.dart';

class DevDeskDashboardShell extends StatelessWidget {
  final Widget body;
  final String selectedRoute;
  final ValueChanged<String> onRouteSelected;

  const DevDeskDashboardShell({
    super.key,
    required this.body,
    required this.selectedRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1200;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                DashboardSidebar(
                  selectedRoute: selectedRoute,
                  onRouteSelected: onRouteSelected,
                ),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.developer_mode_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('DevDesk'),
              ],
            ),
          ),
          drawer: Drawer(
            child: DashboardSidebar(
              selectedRoute: selectedRoute,
              onRouteSelected: (route) {
                Navigator.pop(context);
                onRouteSelected(route);
              },
            ),
          ),
          body: body,
        );
      },
    );
  }
}
