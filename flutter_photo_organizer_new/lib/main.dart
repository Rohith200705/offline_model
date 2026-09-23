// Main app entry point

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'shared/constants/app_constants.dart';
import 'core/database/database_service.dart';
import 'core/services/image_processor.dart';
import 'features/organize/domain/photo_organizer.dart';
import 'features/chat/domain/chatbot.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/organize/presentation/screens/organize_screen.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/faces/presentation/screens/faces_screen.dart';
import 'features/stats/presentation/screens/stats_screen.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependencies
  await _setupDependencies();
  
  runApp(const PhotoOrganizerApp());
}

Future<void> _setupDependencies() async {
  // Database
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService.instance);
  
  // ML Services
  getIt.registerLazySingleton<ImageProcessor>(() => ImageProcessorImpl());
  
  // Domain services
  getIt.registerLazySingleton<PhotoOrganizer>(
    () => PhotoOrganizer(
      processor: getIt<ImageProcessor>(),
      database: getIt<DatabaseService>(),
    ),
  );
  
  getIt.registerLazySingleton<PhotoChatbot>(
    () => PhotoChatbot(
      database: getIt<DatabaseService>(),
      processor: getIt<ImageProcessor>(),
    ),
  );
}

class PhotoOrganizerApp extends StatelessWidget {
  const PhotoOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const OrganizeScreen(),
      const ChatScreen(),
      const FacesScreen(),
      const StatsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Organize',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_outlined),
            selectedIcon: Icon(Icons.face),
            label: 'Faces',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}