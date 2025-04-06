import 'package:flutter/material.dart';
import 'models/year.dart';
import 'pages/settings_page.dart'; // Import SettingsPage
import 'services/settings_service.dart'; // Import SettingsService
import 'services/year_service.dart';
import 'widgets/year_management_dialog.dart';
import 'widgets/year_records_grid.dart'; // Import YearRecordsGrid
import 'dart:io'; // Import dart:io for File and Directory
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:path/path.dart' as p; // Import path package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize settings service
  await SettingsService().init();
  // Initialize year service
  final yearService = await YearService.create();
  runApp(MyApp(yearService: yearService));
}

class MyApp extends StatelessWidget {
  final YearService yearService;

  const MyApp({super.key, required this.yearService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medoki', // Changed App Title
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: MyHomePage(
        title:
            'Medoki - Analyse Medical Documents with AI', // Changed AppBar Title
        yearService: yearService,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final YearService yearService;

  const MyHomePage({super.key, required this.title, required this.yearService});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  late List<Year> years;
  int _currentIndex = 0; // To track the current tab index
  String? _basePath; // Store the base path once loaded
  bool _isBasePathLoading = true; // Track loading state for base path
  // Define the index for the static Analysis tab
  final int _analysisTabIndex = 0;

  @override
  void initState() {
    super.initState();
    years = widget.yearService.getYears();
    _loadBasePath(); // Load base path on init
    // Initialize TabController, adding 1 to length for the Analysis tab
    _tabController = TabController(length: years.length + 1, vsync: this);
    // Add listener to update state (_currentIndex) when tab changes
    _tabController.addListener(() {
      // Check if the index actually changed to avoid unnecessary rebuilds
      if (_tabController.index != _currentIndex) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    // Dispose the controller when the widget is disposed
    _tabController.removeListener(() {}); // Remove listener first
    _tabController.dispose();
    super.dispose();
  }

  // Method to load the base path from settings
  Future<void> _loadBasePath() async {
    try {
      final path = await SettingsService().getMedicalFilesPath();
      if (mounted) {
        // Check if widget is still in the tree
        setState(() {
          _basePath = path;
          _isBasePathLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBasePathLoading = false;
          // Optionally show an error, but YearRecordsGrid handles null path
        });
        print("Error loading base path: $e"); // Log error
      }
    }
  }

  // Method to handle adding a new record
  Future<void> _addRecordForYear(String yearName) async {
    // 1. Check if base path is set
    if (_basePath == null || _basePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medical records path not set. Please set it in Settings.',
          ),
        ),
      );
      return;
    }

    // 2. Construct target directory path
    final targetDirectoryPath = p.join(_basePath!, yearName);

    try {
      // 3. Pick files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // 4. Create target directory if it doesn't exist
        final targetDir = Directory(targetDirectoryPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        int successCount = 0;
        List<String> errors = [];

        // 5. Copy selected files
        for (var file in result.files) {
          if (file.path != null) {
            try {
              final sourceFile = File(file.path!);
              final destinationPath = p.join(targetDirectoryPath, file.name);
              await sourceFile.copy(destinationPath);
              successCount++;
            } catch (e) {
              errors.add('Error copying ${file.name}: $e');
            }
          } else {
            errors.add('Could not get path for ${file.name}');
          }
        }

        // 6. Show feedback
        String feedbackMessage;
        if (errors.isEmpty) {
          feedbackMessage =
              '$successCount file(s) added to $yearName successfully.';
        } else {
          feedbackMessage =
              '$successCount file(s) added to $yearName. Errors: ${errors.join(', ')}';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feedbackMessage)));

        // 7. Refresh grid (Placeholder - see previous thinking)
        if (successCount > 0) {
          print("Need to implement grid refresh for $yearName");
          // TODO: Implement a robust refresh mechanism (e.g., using keys or state management)
        }
      } else {
        // User canceled the picker or selected no files
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File selection cancelled.')),
        );
      }
    } catch (e) {
      // Handle exceptions during picking or directory creation
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }

  void _showYearManagementDialog() {
    showDialog<List<Year>>(
      context: context,
      builder:
          (context) => YearManagementDialog(yearService: widget.yearService),
    ).then((updatedYears) {
      if (updatedYears != null) {
        // Use addPostFrameCallback to ensure setState is called after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check if the widget is still mounted before calling setState
          if (mounted) {
            setState(() {
              // Sort the years list in descending order numerically
              updatedYears.sort((a, b) {
                try {
                  return int.parse(b.name).compareTo(int.parse(a.name));
                } catch (e) {
                  // Handle potential non-integer year names gracefully
                  return 0;
                }
              });

              // Check if the number of tabs needs to change
              int newLength = updatedYears.length + 1;
              if (_tabController.length != newLength) {
                // Store the current index before disposing
                int previousIndex = _tabController.index;
                _tabController.dispose(); // Dispose old controller
                // Create a new controller with the updated length
                _tabController = TabController(
                  length: newLength,
                  vsync: this,
                  // Try to restore the previous index if valid, otherwise default to 0
                  initialIndex: (previousIndex < newLength) ? previousIndex : 0,
                );
                // Re-add the listener to the new controller
                _tabController.addListener(() {
                  if (_tabController.index != _currentIndex) {
                    setState(() {
                      _currentIndex = _tabController.index;
                    });
                  }
                });
                // Update the current index state if it changed due to recreation
                _currentIndex = _tabController.index;
              }
              // Update the years list
              years = updatedYears;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // Add actions list for the settings button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          // Increase height slightly for the divider
          preferredSize: const Size.fromHeight(
            kToolbarHeight + kTextTabBarHeight + 1.0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        // Static Analysis tab
                        const Tab(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Analysis',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'medical insights',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        // Dynamic year tabs
                        ...years.map((year) {
                          return Tab(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  year.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'medical records',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  // Edit years button
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showYearManagementDialog,
                    tooltip: 'Add/Edit Years',
                  ),
                ],
              ),
              // Conditionally build the toolbar based on the selected tab index
              Container(
                height: kToolbarHeight, // Use standard toolbar height
                color: Theme.of(context).colorScheme.surface,
                child: _buildToolbarContent(context), // Call the helper method
              ),
              const Divider(
                height: 1.0,
                thickness: 1.0,
              ), // Add the separator line
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Analysis tab content view
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Medical Analysis',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text('This is the Analysis tab content'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: null, // Placeholder action
                  child: Text('Generate Analysis'),
                ),
              ],
            ),
          ),
          // Dynamic year tab content views using YearRecordsGrid directly
          // Pass the loaded _basePath
          if (_isBasePathLoading) // Show loading indicator if base path is still loading
            const Center(child: CircularProgressIndicator())
          else // Once base path is loaded (or failed), build the grids
            ...years.map((year) {
              return YearRecordsGrid(
                // Use ValueKey to ensure state is preserved correctly when years change
                key: ValueKey(
                  '${year.name}-$_basePath',
                ), // Key might help trigger rebuilds
                yearName: year.name,
                basePath: _basePath, // Pass the loaded base path
                // Pass down the add record callback
                onAddRecord: () => _addRecordForYear(year.name),
              );
            }).toList(),
        ],
      ),
    );
  }

  // Helper method defined INSIDE _MyHomePageState to build toolbar content
  Widget _buildToolbarContent(BuildContext context) {
    if (_currentIndex == _analysisTabIndex) {
      // Content for the Analysis tab toolbar
      return Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the button
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Placeholder action for generating report
            },
            icon: const Icon(Icons.assessment),
            label: const Text('Generate Report'),
          ),
        ],
      );
    } else {
      // Content for the Year tabs toolbar (Add left, Search/Filter right)
      return Row(
        children: [
          Padding(
            // Add padding to the left button
            padding: const EdgeInsets.only(left: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // Call add record for the currently selected year tab
                // Adjust index because years list doesn't include Analysis tab
                if (_currentIndex > 0 && _currentIndex <= years.length) {
                  _addRecordForYear(years[_currentIndex - 1].name);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add medical records...'),
              // Add styling for background and foreground color
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const Spacer(), // Pushes Search/Filter to the right
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Placeholder action for search
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Placeholder action for filter
            },
          ),
        ],
      );
    }
  }
}
