import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _operatorController = TextEditingController();
  bool _continuousMode = true;
  bool _isTesting = false;
  bool _isConnected = false;
  String? _statusMessage;

  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final operatorName = await ApiService.getOperatorName();
    final continuous = await ApiService.getContinuousMode();
    final ok = await ApiService.testConnection();

    if (mounted) {
      setState(() {
        _operatorController.text = operatorName;
        _continuousMode = continuous;
        _isConnected = ok;
      });
    }
  }

  Future<void> _saveSettings() async {
    final op = _operatorController.text.trim();
    if (op.isNotEmpty) {
      await ApiService.setOperatorName(op);
    }
    await ApiService.setContinuousMode(_continuousMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanner profile saved.'),
          backgroundColor: AppTheme.plum,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testLiveConnection() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final ok = await ApiService.testConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isConnected = ok;
        _statusMessage = ok
            ? '✓ Connected live to Sorting Desk! Scans update immediately over Wi-Fi.'
            : '✗ Cannot reach laptop. Ensure your phone and laptop are on the same Wi-Fi (192.168.86.23).';
      });
    }
  }

  void _onSecretTap() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showHiddenDeveloperDialog();
    }
  }

  void _showHiddenDeveloperDialog() async {
    final currentUrl = await ApiService.getBaseUrl();
    final textCtrl = TextEditingController(text: currentUrl);
    String? testStatus;
    bool isTesting = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Developer Host Settings', style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hidden config for network debugging:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.x.x:8000',
                    filled: true,
                    fillColor: AppTheme.creamBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    InkWell(
                      onTap: () => setDialogState(() => textCtrl.text = 'http://192.168.86.23:8000'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.plum.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.plum.withValues(alpha: 0.2)),
                        ),
                        child: const Text('192.168.86.23:8000', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    InkWell(
                      onTap: () => setDialogState(() => textCtrl.text = 'http://10.0.2.2:8000'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.plum.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.plum.withValues(alpha: 0.2)),
                        ),
                        child: const Text('10.0.2.2:8000', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            setDialogState(() {
                              isTesting = true;
                              testStatus = null;
                            });
                            final ok = await ApiService.testConnection(customUrl: textCtrl.text.trim());
                            setDialogState(() {
                              isTesting = false;
                              testStatus = ok ? '✓ Connection Successful' : '✗ Connection Failed';
                            });
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 16),
                    label: Text(isTesting ? 'Testing...' : 'Test Connection'),
                  ),
                ),
                if (testStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    testStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: testStatus!.startsWith('✓') ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = textCtrl.text.trim();
                if (val.isNotEmpty) {
                  await ApiService.setBaseUrl(val);
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                _loadSettings();
              },
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _operatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Scanner Profile'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wireless Direct Operation Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_rounded,
                      color: AppTheme.success, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Direct Wireless Transmission',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.plum,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Every parcel scan updates the sorting desk immediately over Wi-Fi without USB cables.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Direct Live Link Card
          const Text(
            'DIRECT LOGISTICS LINK',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isConnected ? AppTheme.success : AppTheme.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected
                              ? 'Live to Web Logistics'
                              : 'Reconnecting to Laptop...',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _isConnected ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isConnected ? 'Direct Mode' : 'Check Wi-Fi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.plum,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isTesting ? null : _testLiveConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 18),
                    label: Text(_isTesting ? 'Testing Connection...' : 'Test Connection to Laptop'),
                  ),
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusMessage!.startsWith('✓') ? Colors.green.shade800 : Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Station Identifier
          const Text(
            'STATION PROFILE',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _operatorController,
                  decoration: InputDecoration(
                    labelText: 'Intake Station Name',
                    hintText: 'e.g. Intake Scanner Unit #1',
                    filled: true,
                    fillColor: AppTheme.creamBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Continuous Rapid Scanning',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Auto-resumes camera for next parcel after 3 seconds',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    activeThumbColor: AppTheme.orange,
                    value: _continuousMode,
                    onChanged: (val) {
                      setState(() => _continuousMode = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Changes
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.plum,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveSettings,
              child: const Text('Save Scanner Profile'),
            ),
          ),
          const SizedBox(height: 20),

          // About & Discrete Developer trigger (tap 5 times to reveal hidden URL debug)
          GestureDetector(
            onTap: _onSecretTap,
            child: Center(
              child: Column(
                children: const [
                  Text(
                    'Lumora Logistics Scanner v2.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Official Warehouse Intake Terminal',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
