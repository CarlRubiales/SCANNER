import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RecentScansScreen extends StatefulWidget {
  const RecentScansScreen({super.key});

  @override
  State<RecentScansScreen> createState() => _RecentScansScreenState();
}

class _RecentScansScreenState extends State<RecentScansScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentScans = [];
  ScannerStats? _stats;

  int _pendingCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Auto-attempt sync if connected
    await ApiService.syncOfflineScans();

    final recent = await ApiService.fetchRecentScans();
    final stats = await ApiService.fetchStats();
    final pending = await ApiService.getPendingOfflineCount();

    if (mounted) {
      setState(() {
        _recentScans = recent;
        _stats = stats;
        _pendingCount = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final count = await ApiService.syncOfflineScans();
    await _loadData();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '$count parcels synced to web sorting center!'
              : 'All scans are up to date with logistics.'),
          backgroundColor: AppTheme.plum,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Live Scan Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.orange,
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange),
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Offline pending sync banner
                  if (_pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, color: AppTheme.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_pendingCount offline scans waiting to sync',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              backgroundColor: AppTheme.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSyncing ? null : _syncNow,
                            child: Text(
                              _isSyncing ? 'Syncing...' : 'Sync Now',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Queue Metric Cards
                  if (_stats != null) _buildStatsSection(_stats!),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Barcode Scans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.plum,
                        ),
                      ),
                      Text(
                        '${_recentScans.length} recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_recentScans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 44, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No scans recorded today yet.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Point camera at parcel barcodes to begin intake.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._recentScans.map((scan) => _buildScanCard(scan)),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsSection(ScannerStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 18, color: AppTheme.plum),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Warehouse Sorting Pipeline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.plum,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Responsive 2x2 or 4x1 metric display to prevent ANY horizontal overflow
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildMiniMetric('Scanned Today', '${stats.scansToday}', AppTheme.orange),
                        const SizedBox(width: 8),
                        _buildMiniMetric('At Sorting', '${stats.scanned}', AppTheme.plum),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniMetric('Sorted Bins', '${stats.sorted}', Colors.indigo),
                        const SizedBox(width: 8),
                        _buildMiniMetric('Out for Deliv.', '${stats.inTransit}', AppTheme.success),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _buildMiniMetric('Scanned Today', '${stats.scansToday}', AppTheme.orange),
                  const SizedBox(width: 6),
                  _buildMiniMetric('At Sorting', '${stats.scanned}', AppTheme.plum),
                  const SizedBox(width: 6),
                  _buildMiniMetric('Sorted Bins', '${stats.sorted}', Colors.indigo),
                  const SizedBox(width: 6),
                  _buildMiniMetric('Out for Deliv.', '${stats.inTransit}', AppTheme.success),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    final status = (scan['status'] as String? ?? 'scanned').toLowerCase();
    final isDelivered = status == 'delivered';
    final isInTransit = status == 'out_for_delivery' || status == 'in_transit';

    Color badgeColor = AppTheme.orange;
    Color badgeBg = AppTheme.orangeLight;
    if (isDelivered) {
      badgeColor = AppTheme.success;
      badgeBg = AppTheme.successLight;
    } else if (isInTransit) {
      badgeColor = Colors.blue.shade700;
      badgeBg = Colors.blue.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: AppTheme.plum,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scan['parcel_number'] ?? scan['barcode'] ?? 'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppTheme.plum,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      scan['scanned_at'] ?? '',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${scan['recipient'] ?? 'Intake Package'} • ${scan['city'] ?? ''}, ${scan['province'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (scan['status'] as String? ?? 'scanned')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Area: ${scan['area_name'] ?? 'Pending'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
