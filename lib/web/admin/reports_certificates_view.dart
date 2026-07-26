import 'package:flutter/material.dart';

class ReportsCertificatesView extends StatelessWidget {
  const ReportsCertificatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports & Certificates',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Review and issue safety certification documents',
                  style: TextStyle(color: Colors.white38, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 40),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 3.5,
            children: [
              _ReportActionCard(
                title: 'Generate Monthly Report',
                icon: Icons.summarize_rounded,
                color: const Color(0xFF1B5E20),
                onTap: () {},
              ),
              _ReportActionCard(
                title: 'Issue Safety Certificate',
                icon: Icons.verified_rounded,
                color: const Color(0xFFFF5722),
                onTap: () {},
              ),
              _ReportActionCard(
                title: 'Compliance Audit',
                icon: Icons.analytics_rounded,
                color: Colors.blueAccent,
                onTap: () {},
              ),
              _ReportActionCard(
                title: 'Archive Documents',
                icon: Icons.archive_rounded,
                color: Colors.white38,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text('Recent Certificates Issued',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
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
                  itemCount: 3,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                    ),
                    title: Text('CERT-2024-00${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Issued to Green Tower Plaza', style: TextStyle(color: Colors.white38)),
                    trailing: TextButton.icon(
                      onPressed: () {}, 
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('DOWNLOAD'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
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

class _ReportActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(title, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
