import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../core/widgets/confirm_dialog.dart';

class ExportBackupDialog extends StatefulWidget {
  final PetRepository petRepository;
  final VoidCallback onDataChanged;

  const ExportBackupDialog({
    super.key,
    required this.petRepository,
    required this.onDataChanged,
  });

  static void show({
    required BuildContext context,
    required PetRepository petRepository,
    required VoidCallback onDataChanged,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ExportBackupDialog(
        petRepository: petRepository,
        onDataChanged: onDataChanged,
      ),
    );
  }

  @override
  State<ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<ExportBackupDialog> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  final _importJsonController = TextEditingController();

  @override
  void dispose() {
    _importJsonController.dispose();
    super.dispose();
  }

  Future<void> _handleExportCopy() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final data = await widget.petRepository.exportData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      setState(() {
        _isLoading = false;
        _isError = false;
        _statusMessage = 'JSON backup copied to clipboard!';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _statusMessage = 'Export failed: $e';
      });
    }
  }

  Future<void> _handleImport() async {
    final text = _importJsonController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please paste JSON data to import.';
      });
      return;
    }

    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object with "pets" array');
      }
      parsed = decoded;
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Invalid JSON: $e';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final count = await widget.petRepository.importData(parsed);
      widget.onDataChanged();
      _importJsonController.clear();
      setState(() {
        _isLoading = false;
        _isError = false;
        _statusMessage = 'Successfully imported $count pet(s)!';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _statusMessage = 'Import failed: $e';
      });
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Reset All Data',
      message: 'Are you sure you want to delete all pets and medications from your account?',
      warningText: 'This action is permanent and cannot be undone.',
      confirmLabel: 'Yes, Clear All Data',
      isDestructive: true,
    );

    if (confirmed) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });

      try {
        await widget.petRepository.resetAllData();
        widget.onDataChanged();
        setState(() {
          _isLoading = false;
          _isError = false;
          _statusMessage = 'All pet data has been cleared.';
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _statusMessage = 'Reset failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Backup & Data Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? (isDark ? const Color(0x26EF4444) : const Color(0xFFFEE2E2))
                        : (isDark ? const Color(0x2610B981) : const Color(0xFFD1FAE5)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isError
                          ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                          : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Export
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Export / Backup',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Generate a complete JSON backup of all your pets, medications, weight logs, and history.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleExportCopy,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Export & Copy Backup JSON'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Import
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Import Data',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paste your JSON backup payload below to restore pets and medications.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _importJsonController,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              decoration: const InputDecoration(
                                hintText: '{"version": "1.0", "pets": [...]}',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleImport,
                              icon: const Icon(Icons.file_upload_outlined, size: 16),
                              label: const Text('Import Backup JSON'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 3: Reset
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1AEF4444) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reset Database',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Permanently clear all pets and medications to start fresh with a clean slate.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isLoading ? null : _handleReset,
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const Text('Clear All Data'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
