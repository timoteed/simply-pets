import 'package:flutter/material.dart';
import '../../../data/models/pet.dart';
import '../../../data/models/stats.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../core/constants.dart';
import '../../core/widgets/avatar_badge.dart';
import '../../core/widgets/stat_card.dart';
import '../export_backup/export_backup_dialog.dart';
import '../pet_detail/pet_detail_dialog.dart';
import '../pet_form/pet_form_dialog.dart';
import '../schedule/schedule_view.dart';

class DashboardView extends StatefulWidget {
  final AuthRepository authRepository;
  final PetRepository petRepository;
  final MedicationRepository medicationRepository;
  final WeightRepository weightRepository;
  final VoidCallback onThemeToggle;
  final VoidCallback onLogout;

  const DashboardView({
    super.key,
    required this.authRepository,
    required this.petRepository,
    required this.medicationRepository,
    required this.weightRepository,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<Pet> _allPets = [];
  Stats _stats = const Stats();
  bool _isLoading = true;
  String? _error;

  int _selectedTabIndex = 0; // 0: My Pets, 1: Schedule

  // Search & Filter
  String _searchQuery = '';
  String _speciesFilter = 'all';
  String _sortBy = 'name_asc';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.petRepository.getAllPets(),
        widget.petRepository.getStats(),
      ]);

      setState(() {
        _allPets = results[0] as List<Pet>;
        _stats = results[1] as Stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSampleData() async {
    setState(() => _isLoading = true);
    try {
      await widget.petRepository.loadDemoData();
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Sample pets & medications loaded!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load demo data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Pet> _getFilteredPets() {
    var list = List<Pet>.from(_allPets);

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchBreed = p.breed.toLowerCase().contains(q);
        final matchNotes = p.notes.toLowerCase().contains(q);
        return matchName || matchBreed || matchNotes;
      }).toList();
    }

    // 2. Species Filter
    if (_speciesFilter != 'all') {
      if (_speciesFilter == 'Other') {
        final standard = {'Dog', 'Cat', 'Rabbit', 'Bird'};
        list = list.where((p) => !standard.contains(p.species)).toList();
      } else {
        list = list.where((p) => p.species.toLowerCase() == _speciesFilter.toLowerCase()).toList();
      }
    }

    // 3. Sorting
    switch (_sortBy) {
      case 'name_asc':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'name_desc':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'weight_desc':
        list.sort((a, b) => b.weight.compareTo(a.weight));
        break;
      case 'weight_asc':
        list.sort((a, b) => a.weight.compareTo(b.weight));
        break;
      case 'meds_desc':
        list.sort((a, b) => b.activeMedCount.compareTo(a.activeMedCount));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.authRepository.currentUser;
    final userDisplayName = user?.displayName ?? user?.username ?? 'User';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context, isDark, userDisplayName),
            const Divider(height: 1),

            // Main Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Error loading dashboard: $_error'),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Stats Ribbon
                                    _buildStatsRibbon(),
                                    const SizedBox(height: 20),

                                    // Nav Tabs & Sample Data trigger
                                    _buildViewNav(isDark),
                                    const SizedBox(height: 18),

                                    // Active Tab View
                                    if (_selectedTabIndex == 0)
                                      _buildPetsView(isDark)
                                    else
                                      ScheduleView(
                                        medicationRepository: widget.medicationRepository,
                                        onDoseLogged: _loadAllData,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, bool isDark, String userDisplayName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Brand logo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🐾', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SimplyPets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  Text(
                    'Smart pet health & medication management',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Theme toggle
              IconButton(
                tooltip: 'Toggle Theme',
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                onPressed: widget.onThemeToggle,
              ),
              const SizedBox(width: 6),

              // Backup & Export
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: const Icon(Icons.backup_outlined, size: 16),
                label: const Text('Backup & Export', style: TextStyle(fontSize: 13)),
                onPressed: () {
                  ExportBackupDialog.show(
                    context: context,
                    petRepository: widget.petRepository,
                    onDataChanged: _loadAllData,
                  );
                },
              ),
              const SizedBox(width: 8),

              // Add New Pet
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Pet', style: TextStyle(fontSize: 13)),
                onPressed: () {
                  PetFormDialog.show(
                    context: context,
                    petRepository: widget.petRepository,
                    onSaved: _loadAllData,
                  );
                },
              ),
              const SizedBox(width: 12),

              // User chip & Logout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      userDisplayName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout, size: 18),
                onPressed: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRibbon() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (!isWide) {
          return Column(
            children: [
              StatCard(
                icon: '🐾',
                value: '${_stats.totalPets}',
                label: 'Total Pets Tracked',
                type: StatCardType.primary,
              ),
              const SizedBox(height: 8),
              StatCard(
                icon: '💊',
                value: '${_stats.activeMedications}',
                label: 'Active Medications',
                type: StatCardType.amber,
              ),
              const SizedBox(height: 8),
              StatCard(
                icon: '✅',
                value: '${_stats.medsTakenToday}',
                label: 'Meds Given Today',
                type: StatCardType.green,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: StatCard(
                icon: '🐾',
                value: '${_stats.totalPets}',
                label: 'Total Pets Tracked',
                type: StatCardType.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StatCard(
                icon: '💊',
                value: '${_stats.activeMedications}',
                label: 'Active Medications',
                type: StatCardType.amber,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StatCard(
                icon: '✅',
                value: '${_stats.medsTakenToday}',
                label: 'Meds Given Today',
                type: StatCardType.green,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewNav(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildNavTabButton(
              title: 'My Pets',
              count: _allPets.length,
              isActive: _selectedTabIndex == 0,
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
            const SizedBox(width: 8),
            _buildNavTabButton(
              title: "Today's Meds Schedule",
              count: _stats.activeMedications,
              isActive: _selectedTabIndex == 1,
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ],
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          icon: const Text('✨', style: TextStyle(fontSize: 14)),
          label: const Text('Load Sample Pets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          onPressed: _loadSampleData,
        ),
      ],
    );
  }

  Widget _buildNavTabButton({
    required String title,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive
                    ? primaryColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetsView(bool isDark) {
    final filteredPets = _getFilteredPets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls bar: Search + Species Filter + Sort Filter
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            if (isNarrow) {
              return Column(
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSpeciesFilter()),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSortFilter()),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 12),
                SizedBox(width: 170, child: _buildSpeciesFilter()),
                const SizedBox(width: 12),
                SizedBox(width: 190, child: _buildSortFilter()),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Pets Grid or Empty State
        if (filteredPets.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Text('🐶', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'No pets found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No pets match your search criteria.'
                      : 'Start tracking your furry and feathered friends! Add your first pet or load sample pets to see how it works.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        PetFormDialog.show(
                          context: context,
                          petRepository: widget.petRepository,
                          onSaved: _loadAllData,
                        );
                      },
                      child: const Text('+ Add Your First Pet'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _loadSampleData,
                      child: const Text('✨ Load Sample Data'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;
              if (constraints.maxWidth > 900) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 2;
              }

              if (crossAxisCount == 1) {
                return Column(
                  children: filteredPets.map((pet) => _buildPetCard(pet, isDark)).toList(),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.45,
                ),
                itemCount: filteredPets.length,
                itemBuilder: (ctx, idx) => _buildPetCard(filteredPets[idx], isDark),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by pet name, breed, or notes...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
      ),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
    );
  }

  Widget _buildSpeciesFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _speciesFilter,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All Species')),
        DropdownMenuItem(value: 'Dog', child: Text('Dogs 🐶')),
        DropdownMenuItem(value: 'Cat', child: Text('Cats 🐱')),
        DropdownMenuItem(value: 'Rabbit', child: Text('Rabbits 🐰')),
        DropdownMenuItem(value: 'Bird', child: Text('Birds 🦜')),
        DropdownMenuItem(value: 'Other', child: Text('Other Animals')),
      ],
      onChanged: (v) => setState(() => _speciesFilter = v ?? 'all'),
    );
  }

  Widget _buildSortFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _sortBy,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: AppConstants.sortLabels.entries.map((e) {
        return DropdownMenuItem(value: e.key, child: Text(e.value));
      }).toList(),
      onChanged: (v) => setState(() => _sortBy = v ?? 'name_asc'),
    );
  }

  Widget _buildPetCard(Pet pet, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: Avatar + Name & Breed + Species badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarBadge(
                avatar: pet.avatar,
                photoUrl: pet.photoUrl,
                baseUrl: widget.petRepository.apiService.baseUrl,
                size: 50,
                fontSize: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pet.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pet.species,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pet.breed.isNotEmpty ? pet.breed : 'Breed not specified',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Middle row: Stats pills (Weight, Gender, Active Meds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildInfoBadge('⚖️ ${pet.weight} ${pet.weightUnit}', isDark),
                _buildInfoBadge(pet.gender, isDark),
                _buildMedBadge(pet.activeMedCount, isDark),
              ],
            ),
          ),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    PetDetailDialog.show(
                      context: context,
                      petId: pet.id,
                      petRepository: widget.petRepository,
                      medicationRepository: widget.medicationRepository,
                      weightRepository: widget.weightRepository,
                      onPetUpdated: _loadAllData,
                    );
                  },
                  child: const Text('View Health Record'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                tooltip: 'Edit Pet',
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () {
                  PetFormDialog.show(
                    context: context,
                    pet: pet,
                    petRepository: widget.petRepository,
                    onSaved: _loadAllData,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildMedBadge(int count, bool isDark) {
    final hasMeds = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hasMeds
            ? const Color(0x26F59E0B)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        hasMeds ? '💊 $count Active Med${count > 1 ? "s" : ""}' : '💊 0 Meds',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: hasMeds ? const Color(0xFFD97706) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
