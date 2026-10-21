import 'package:flutter/material.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/medication_repository.dart';
import 'data/repositories/pet_repository.dart';
import 'data/repositories/weight_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/storage_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/auth/login_view.dart';
import 'ui/features/dashboard/dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();

  runApp(SimplyPetsApp(storageService: storageService));
}

class SimplyPetsApp extends StatefulWidget {
  final StorageService storageService;

  const SimplyPetsApp({super.key, required this.storageService});

  @override
  State<SimplyPetsApp> createState() => _SimplyPetsAppState();
}

class _SimplyPetsAppState extends State<SimplyPetsApp> {
  late final ApiService _apiService;
  late final AuthRepository _authRepository;
  late final PetRepository _petRepository;
  late final MedicationRepository _medicationRepository;
  late final WeightRepository _weightRepository;

  ThemeMode _themeMode = ThemeMode.system;
  bool _isAuthenticated = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();

    _apiService = ApiService(
      storageService: widget.storageService,
      onUnauthorized: () {
        if (mounted && _isAuthenticated) {
          setState(() => _isAuthenticated = false);
        }
      },
    );

    _authRepository = AuthRepository(
      apiService: _apiService,
      storageService: widget.storageService,
    );

    _petRepository = PetRepository(apiService: _apiService);
    _medicationRepository = MedicationRepository(apiService: _apiService);
    _weightRepository = WeightRepository(apiService: _apiService);

    _loadThemeMode();
    _checkInitialAuth();
  }

  void _loadThemeMode() {
    final saved = widget.storageService.getThemeMode();
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> _checkInitialAuth() async {
    final user = await _authRepository.checkSession();
    if (mounted) {
      setState(() {
        _isAuthenticated = user != null;
        _isCheckingSession = false;
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      final isCurrentDark = _themeMode == ThemeMode.dark ||
          (_themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

      if (isCurrentDark) {
        _themeMode = ThemeMode.light;
        widget.storageService.setThemeMode('light');
      } else {
        _themeMode = ThemeMode.dark;
        widget.storageService.setThemeMode('dark');
      }
    });
  }

  void _handleLogout() async {
    await _authRepository.logout();
    if (mounted) {
      setState(() => _isAuthenticated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimplyPets — Modern Pet & Medication Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _isCheckingSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated
              ? DashboardView(
                  authRepository: _authRepository,
                  petRepository: _petRepository,
                  medicationRepository: _medicationRepository,
                  weightRepository: _weightRepository,
                  onThemeToggle: _toggleTheme,
                  onLogout: _handleLogout,
                )
              : LoginView(
                  authRepository: _authRepository,
                  onLoginSuccess: () {
                    setState(() => _isAuthenticated = true);
                  },
                ),
    );
  }
}
