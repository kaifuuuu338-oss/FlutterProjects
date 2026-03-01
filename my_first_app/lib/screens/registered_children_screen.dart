import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/navigation/navigation_state_service.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class RegisteredChildrenScreen extends StatefulWidget {
  const RegisteredChildrenScreen({super.key});

  @override
  State<RegisteredChildrenScreen> createState() =>
      _RegisteredChildrenScreenState();
}

class _RegisteredChildrenScreenState extends State<RegisteredChildrenScreen> {
  final APIService _api = APIService();
  final AuthService _auth = AuthService();
  final LocalDBService _localDb = LocalDBService();
  final ScrollController _tableScrollController = ScrollController();
  final Set<String> _selectedChildIds = <String>{};

  late Future<List<Map<String, dynamic>>> _childrenFuture;
  String _loggedInAwcCode = '';
  bool _deletingChildren = false;

  @override
  void initState() {
    super.initState();
    NavigationStateService.instance.saveState(
      screen: NavigationStateService.screenRegisteredChildren,
    );
    _loadChildren();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  void _loadChildren() {
    _selectedChildIds.clear();
    _childrenFuture = _fetchChildren();
  }

  Future<List<Map<String, dynamic>>> _fetchChildren() async {
    await _localDb.initialize();
    final savedAwcCode =
        (_loggedInAwcCode.isNotEmpty ? _loggedInAwcCode : (await _auth.getLoggedInAwcCode() ?? '')).trim().toUpperCase();
    _loggedInAwcCode = savedAwcCode;

    List<Map<String, dynamic>> backendChildren = const <Map<String, dynamic>>[];
    try {
      backendChildren = await _api.getRegisteredChildren(
        limit: 1000,
        awcCode: savedAwcCode.isEmpty ? null : savedAwcCode,
      );
      
      // Ensure all required fields are present
      for (var child in backendChildren) {
        // Handle missing or different field names for date of birth
        // Backend sends 'dob', frontend expects 'date_of_birth'
        if (!child.containsKey('date_of_birth') || ((child['date_of_birth'] as String?)?.isEmpty ?? true)) {
          if (child.containsKey('dob') && ((child['dob'] as String?)?.isNotEmpty ?? false)) {
            child['date_of_birth'] = child['dob'];
          } else if (child.containsKey('dateOfBirth') && ((child['dateOfBirth'] as String?)?.isNotEmpty ?? false)) {
            child['date_of_birth'] = child['dateOfBirth'];
          }
        }
        
        // Calculate age_months from date_of_birth if it's 0 or missing
        int ageMonths = (child['age_months'] as num?)?.toInt() ?? 0;
        if (ageMonths == 0) {
          final dobStr = child['date_of_birth'] ?? child['dob'];
          if (dobStr != null && dobStr.toString().isNotEmpty) {
            try {
              final dob = DateTime.parse(dobStr.toString());
              final now = DateTime.now();
              ageMonths = (now.year - dob.year) * 12 + (now.month - dob.month);
              child['age_months'] = ageMonths;
              } catch (_) {
                // Keep row without computed age if DOB parse fails.
              }
            }
          }
        }
    } catch (e) {
      // Fallback to local DB
    }

    if (backendChildren.isNotEmpty) {
      return backendChildren;
    }

    final localChildren = _localDb
        .getAllChildren()
        .where(
          (c) => savedAwcCode.isEmpty || _awcCodesMatch(c.awcCode, savedAwcCode),
        )
        .map((child) => {
          'child_id': child.childId,
          'child_name': child.childName,
          'date_of_birth': child.dateOfBirth.toIso8601String().split('T')[0],
          'age_months': child.ageMonths,
          'gender': child.gender,
          'awc_code': child.awcCode,
          'district': child.district,
          'mandal': child.mandal,
          'assessment_cycle': 'Baseline',
        })
        .toList();

    return localChildren;
  }

  bool _awcCodesMatch(String code1, String code2) {
    return code1.trim().toUpperCase() == code2.trim().toUpperCase();
  }

  Future<void> _deleteSelectedChildren(
    List<Map<String, dynamic>> children,
  ) async {
    if (_selectedChildIds.isEmpty || _deletingChildren) return;

    final selectedIds = children
        .map((child) => (child['child_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty && _selectedChildIds.contains(id))
        .toList();
    if (selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected children?'),
        content: Text(
          'This will delete ${selectedIds.length} selected child record(s) from PostgreSQL and app data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingChildren = true);
    int deletedCount = 0;
    final failedIds = <String>[];
    final awcCode = _loggedInAwcCode.trim().toUpperCase();
    for (final childId in selectedIds) {
      try {
        await _api.deleteChild(
          childId,
          awcCode: awcCode.isEmpty ? null : awcCode,
        );
        await _localDb.deleteChild(childId);
        deletedCount += 1;
      } catch (_) {
        failedIds.add(childId);
      }
    }

    if (!mounted) return;
    setState(() {
      _deletingChildren = false;
      _selectedChildIds
        ..clear()
        ..addAll(failedIds);
      _loadChildren();
    });

    final successText = deletedCount == 1
        ? '1 child deleted'
        : '$deletedCount children deleted';
    final hasFailures = failedIds.isNotEmpty;
    final message = hasFailures
        ? '$successText. Failed: ${failedIds.join(', ')}'
        : successText;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: hasFailures ? Colors.orange : Colors.green,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    if (dateStr == 'null' || dateStr.toLowerCase() == 'null') return '-';
    try {
      // Handle both full ISO format and date-only format
      final String cleanStr = dateStr.replaceAll('"', '').trim();
      if (cleanStr.isEmpty || cleanStr.toLowerCase() == 'null') return '-';
      
      final date = DateTime.parse(cleanStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr.isEmpty ? '-' : dateStr;
    }
  }

  String _formatDatePretty(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    if (dateStr == 'null' || dateStr.toLowerCase() == 'null') return '-';
    try {
      final date = DateTime.parse(dateStr.replaceAll('"', '').trim());
      return DateFormat('MMM d, y').format(date);
    } catch (_) {
      return _formatDate(dateStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4EF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.t('registered_children')),
        centerTitle: true,
        backgroundColor: const Color(0xFF1976D2),
        actions: [
          const LanguageMenuButton(iconColor: Colors.white),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(l10n.t('error_loading_data')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadChildren();
                      });
                    },
                    child: Text(l10n.t('retry')),
                  ),
                ],
              ),
            );
          }

          final children = [...(snapshot.data ?? <Map<String, dynamic>>[])];
          children.sort((a, b) {
            final idA = (a['child_id'] ?? '').toString().trim();
            final idB = (b['child_id'] ?? '').toString().trim();
            return idA.compareTo(idB);
          });

          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.child_care, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(l10n.t('no_children_registered')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loadChildren();
              });
              await _childrenFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 980),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.t('registered_children'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2D3D),
                              ),
                            ),
                            const Spacer(),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _selectedChildIds.isEmpty || _deletingChildren
                                      ? null
                                      : () => _deleteSelectedChildren(children),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: _deletingChildren
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                  label: Text(
                                    _selectedChildIds.isEmpty
                                        ? 'Delete Selected'
                                        : 'Delete Selected (${_selectedChildIds.length})',
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF4F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${children.length} ${l10n.t('children_registered')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0A5F67),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Scrollbar(
                              controller: _tableScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _tableScrollController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 34,
                                  horizontalMargin: 14,
                                  dividerThickness: 0.7,
                                  headingRowHeight: 50,
                                  dataRowMinHeight: 58,
                                  dataRowMaxHeight: 58,
                                  headingRowColor: const WidgetStatePropertyAll(
                                    Color(0xFFF4EEDF),
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'child id',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'dob',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'awc code',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'district',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'mandal',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'assessment cycle',
                                        style: TextStyle(
                                          color: Color(0xFF0A5F67),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: List.generate(children.length, (index) {
                                    final child = children[index];
                                    final childId =
                                        (child['child_id'] ?? '').toString().trim();
                                    final dob =
                                        (child['date_of_birth'] ?? child['dob'] ?? '')
                                            .toString()
                                            .trim();
                                    final awcCode =
                                        (child['awc_code'] ?? child['awc_id'] ?? '')
                                            .toString()
                                            .trim();
                                    final district =
                                        (child['district'] ?? '').toString().trim();
                                    final mandal =
                                        (child['mandal'] ?? '').toString().trim();
                                    final assessmentCycle =
                                        (child['assessment_cycle'] ?? 'Baseline')
                                            .toString()
                                            .trim();

                                    const rowText = TextStyle(
                                      fontSize: 31 / 2, // 15.5
                                      color: Color(0xFF374151),
                                      fontWeight: FontWeight.w500,
                                    );
                                    final isSelected =
                                        _selectedChildIds.contains(childId);

                                    return DataRow(
                                      selected: isSelected,
                                      onSelectChanged: (selected) {
                                        final shouldSelect = selected ?? false;
                                        setState(() {
                                          if (shouldSelect) {
                                            _selectedChildIds.add(childId);
                                          } else {
                                            _selectedChildIds.remove(childId);
                                          }
                                        });
                                      },
                                      cells: [
                                        DataCell(Text(childId, style: rowText)),
                                        DataCell(
                                          Text(_formatDatePretty(dob), style: rowText),
                                        ),
                                        DataCell(
                                          Text(
                                            awcCode.isEmpty ? '-' : awcCode,
                                            style: rowText,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            district.isEmpty ? '-' : district,
                                            style: rowText,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            mandal.isEmpty ? '-' : mandal,
                                            style: rowText,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            assessmentCycle.isEmpty
                                                ? 'Baseline'
                                                : assessmentCycle,
                                            style: rowText,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
