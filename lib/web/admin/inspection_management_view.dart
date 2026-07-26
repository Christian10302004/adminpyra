import 'package:flutter/material.dart';

class InspectionManagementView extends StatelessWidget {
  const InspectionManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inspection Management',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('Schedule and track fire safety audits',
                      style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('ASSIGN INSPECTION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Search & Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by location or client...',
                      hintStyle: TextStyle(color: Colors.white24),
                      prefixIcon: Icon(Icons.search, color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF1A1A1A),
                    value: 'All Status',
                    style: const TextStyle(color: Colors.white70),
                    items: ['All Status', 'Pending', 'In Progress', 'Completed']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // List Area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: 5,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business_rounded, color: Color(0xFFFF5722), size: 24),
                    ),
                    title: Text('Location ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: const Text('Assigned to Inspector Sarah', style: TextStyle(color: Colors.white38)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
                      ),
                      child: const Text('PENDING', 
                        style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
