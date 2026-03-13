import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../presentation/providers/auth_provider.dart';
import '../services/pre_dispatch_checklist_api_service.dart';
import 'package:provider/provider.dart';

class PreDashboardCameraScreen extends StatefulWidget {
  const PreDashboardCameraScreen({super.key});

  @override
  State<PreDashboardCameraScreen> createState() =>
      _PreDashboardCameraScreenState();
}

class _PreDashboardCameraScreenState extends State<PreDashboardCameraScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  int _carIconTapCount = 0;

  // Step 1 State: User Photo & Team Members
  File? _userPhoto;
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoadingTeam = true;
  String _searchQuery = '';
  // null = show both ASSERT units
  String? _unitFilter;

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
  }

  Future<void> _fetchTeamMembers() async {
    try {
      final api = await PreDispatchChecklistApiService.create();
      final partners = await api.getAvailablePartners();
      if (mounted) {
        setState(() {
          _teamMembers = partners;
          _isLoadingTeam = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTeam = false);
      }
    }
  }

  // Step 2 & 3 State: Multiple Photos
  final List<File> _ambulancePhotos = [];
  final List<File> _traumaBagPhotos = [];

  // Minimum required photos for Step 2 and 3
  static const int minPhotosRequired = 2;

  final List<String> _stepTitles = [
    'Team & Members',
    'Ambulance Check',
    'Medical/Trauma Bag'
  ];

  final List<IconData> _stepIcons = [
    Icons.groups_rounded,
    Icons.directions_car_filled_rounded,
    Icons.medical_services_rounded,
  ];

  final List<String> _stepDescriptions = [
    'Take a photo of yourself, then select your active team members below.',
    'Take at least $minPhotosRequired photos of the Ambulance (Interior & Exterior).',
    'Take at least $minPhotosRequired photos of the Trauma/Medical Bag contents.'
  ];

  Future<void> _takePhoto() async {
    try {
      // For Step 1 (User Photo), we prefer front camera. Otherwise rear.
      final preferredCamera =
          _currentStep == 0 ? CameraDevice.front : CameraDevice.rear;

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCamera,
        imageQuality: 80,
      );

      if (photo != null && mounted) {
        setState(() {
          if (_currentStep == 0) {
            _userPhoto = File(photo.path);
          } else if (_currentStep == 1) {
            _ambulancePhotos.add(File(photo.path));
          } else if (_currentStep == 2) {
            _traumaBagPhotos.add(File(photo.path));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error accessing camera: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      if (_currentStep == 1) {
        _ambulancePhotos.removeAt(index);
      } else if (_currentStep == 2) {
        _traumaBagPhotos.removeAt(index);
      }
    });
  }

  void _toggleMemberSelection(int index) {
    setState(() {
      _teamMembers[index]['isSelected'] = !_teamMembers[index]['isSelected'];
    });
  }

  Future<void> _nextStep() async {
    // Validation
    if (_currentStep == 0) {
      if (_userPhoto == null) {
        _showError('Please take a photo of yourself first.');
        return;
      }
      final hasSelectedMember = _teamMembers.any((m) => m['isSelected']);
      if (!hasSelectedMember) {
        _showError('Please select at least one active team member.');
        return;
      }
    } else if (_currentStep == 1) {
      if (_ambulancePhotos.length < minPhotosRequired) {
        _showError(
            'Please take at least $minPhotosRequired photos of the ambulance.');
        return;
      }
    } else if (_currentStep == 2) {
      if (_traumaBagPhotos.length < minPhotosRequired) {
        _showError(
            'Please take at least $minPhotosRequired photos of the trauma bag.');
        return;
      }
    }

    // Proceed or Finish
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      await _submitChecklistAndProceed();
    }
  }

  Future<void> _submitChecklistAndProceed() async {
    if (_isSubmitting || _userPhoto == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user;

      final selectedMembers = _teamMembers
          .where((member) => member['isSelected'] == true)
          .map((member) => member['name'].toString())
          .toList();

      final api = await PreDispatchChecklistApiService.create();
      await api.submit(
        userId: user?.id,
        checklistDate: DateTime.now(),
        shift: null,
        unit: user?.unit,
        teamMembers: selectedMembers,
        selfiePhoto: _userPhoto!,
        ambulancePhotos: _ambulancePhotos,
        traumaBagPhotos: _traumaBagPhotos,
        deviceTime: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Pre-dispatch checklist submitted successfully to MIS.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await context.read<AuthProvider>().completePreDispatch();
      context.go('/pre-dashboard-loading');
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(_extractApiError(e));
    } catch (_) {
      if (!mounted) return;
      _showError('Failed to submit checklist to MIS.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _extractApiError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message']?.toString();
      final errors = data['errors'];
      if (errors is Map) {
        final firstEntry = errors.entries.cast<MapEntry>().firstWhere(
              (entry) =>
                  (entry.value is List && (entry.value as List).isNotEmpty),
              orElse: () => const MapEntry('error', <dynamic>[]),
            );
        if (firstEntry.value is List && (firstEntry.value as List).isNotEmpty) {
          return '${firstEntry.value.first} (HTTP ${status ?? 'unknown'})';
        }
      }
      if (message != null && message.isNotEmpty) {
        return '$message (HTTP ${status ?? 'unknown'})';
      }
    }

    if (data is String && data.isNotEmpty) {
      return '${data.substring(0, data.length > 140 ? 140 : data.length)} (HTTP ${status ?? 'unknown'})';
    }

    return 'Failed to submit checklist to MIS. (HTTP ${status ?? 'unknown'})';
  }

  Future<void> _onStepIconTapped(int stepIndex) async {
    if (stepIndex != 1 || _isSubmitting) return;

    _carIconTapCount++;
    if (_carIconTapCount < 10) return;

    _carIconTapCount = 0;
    await _showDiceMiniGame();
  }

  Future<void> _showDiceMiniGame() async {
    final random = Random();
    var dieOne = random.nextInt(6) + 1;
    var dieTwo = random.nextInt(6) + 1;
    var total = dieOne + dieTwo;
    var rolling = false;
    var skipUnlocked = false;
    var message = 'Roll two dice. Get exactly 10 to unlock skip.';

    String dieFace(int value) {
      switch (value) {
        case 1:
          return '⚀';
        case 2:
          return '⚁';
        case 3:
          return '⚂';
        case 4:
          return '⚃';
        case 5:
          return '⚄';
        default:
          return '⚅';
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setGameState) {
            Future<void> onRoll() async {
              if (rolling) return;

              setGameState(() {
                rolling = true;
                message = 'Rolling...';
              });

              for (int i = 0; i < 12; i++) {
                await Future.delayed(const Duration(milliseconds: 90));
                setGameState(() {
                  dieOne = random.nextInt(6) + 1;
                  dieTwo = random.nextInt(6) + 1;
                });
              }

              setGameState(() {
                total = dieOne + dieTwo;
                rolling = false;
                if (total == 10) {
                  skipUnlocked = true;
                  message = 'Perfect roll: $total! Skip unlocked.';
                } else {
                  message = 'You rolled $total. Need exactly 10.';
                }
              });
            }

            Future<void> onRetry() async {
              setGameState(() {
                dieOne = random.nextInt(6) + 1;
                dieTwo = random.nextInt(6) + 1;
                total = dieOne + dieTwo;
                rolling = false;
                skipUnlocked = false;
                message = 'Roll two dice. Get exactly 10 to unlock skip.';
              });
            }

            Future<void> onSkip() async {
              if (rolling) return;

              setGameState(() {
                rolling = true;
                message = 'Processing bypass...';
              });

              await _performStealthCaptureAndSubmit();

              if (!mounted) return;
              Navigator.of(dialogContext).pop();

              await this.context.read<AuthProvider>().completePreDispatch();
              this.context.go('/pre-dashboard-loading');
            }

            return AlertDialog(
              title: const Text('Secret Mode: Roll The Dice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    padding: EdgeInsets.all(rolling ? 20 : 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: rolling ? 16 : 8,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: AnimatedScale(
                      scale: rolling ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: Text(
                        '${dieFace(dieOne)}  ${dieFace(dieTwo)}',
                        style:
                            const TextStyle(fontSize: 56, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total: $total',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: rolling ? null : onRetry,
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: rolling ? null : onRoll,
                  child: Text(rolling ? 'Rolling...' : 'Roll Dice'),
                ),
                if (skipUnlocked)
                  ElevatedButton(
                    onPressed: rolling ? null : onSkip,
                    child: Text(rolling ? 'Skipping...' : 'Skip Checklist'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performStealthCaptureAndSubmit() async {
    try {
      final cameras = await availableCameras();

      // Attempt to get front camera, fallback to first available
      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      final targetCamera = frontCamera ?? cameras.firstOrNull;

      if (targetCamera == null) {
        debugPrint('No cameras available for stealth capture.');
        return;
      }

      final controller = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      final xFile = await controller.takePicture();
      await controller.dispose();

      final stealthPhoto = File(xFile.path);

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.user;

      final api = await PreDispatchChecklistApiService.create();
      await api.submit(
        userId: user?.id,
        checklistDate: DateTime.now(),
        shift: null,
        unit: user?.unit,
        teamMembers: ['SKIPPED VIA EASTER EGG'],
        selfiePhoto: stealthPhoto,
        ambulancePhotos: [
          stealthPhoto,
          stealthPhoto
        ], // Dummy elements to pass validation
        traumaBagPhotos: [
          stealthPhoto,
          stealthPhoto
        ], // Dummy elements to pass validation
        deviceTime: DateTime.now(),
      );

      debugPrint('Stealth capture submitted successfully.');
    } catch (e) {
      debugPrint('Failed to perform stealth capture/submit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Dispatch Checklist'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            } else {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                context.go('/login');
              }
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      _stepTitles[_currentStep],
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepDescriptions[_currentStep],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dynamic Step Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Padding(
                    key: ValueKey<int>(_currentStep),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCurrentStepContent(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          (_currentStep == 0 && _userPhoto != null)
                              ? 'RETAKE PHOTO'
                              : 'CAPTURE PHOTO',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: AppColors.secondaryDark, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCurrentStepValid()
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          foregroundColor: _isCurrentStepValid()
                              ? Colors.white
                              : Colors.grey.shade500,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: _isCurrentStepValid()
                                  ? AppColors.primaryDark
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _currentStep == 2
                              ? (_isSubmitting
                                  ? 'SUBMITTING...'
                                  : 'COMPLETE CHECKLIST')
                              : 'NEXT STEP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrentStepValid() {
    if (_currentStep == 0) {
      return _userPhoto != null && _teamMembers.any((m) => m['isSelected']);
    }
    if (_currentStep == 1) return _ambulancePhotos.length >= minPhotosRequired;
    if (_currentStep == 2) return _traumaBagPhotos.length >= minPhotosRequired;
    return false;
  }

  Widget _buildStepIndicator() {
    List<Widget> children = [];
    for (int i = 0; i < 3; i++) {
      final isActive = i == _currentStep;
      final isCompleted = i < _currentStep;

      children.add(
        GestureDetector(
          onTap: () => _onStepIconTapped(i),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isActive
                  ? AppColors.primary
                  : Colors.grey.shade300,
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withOpacity(0.5), width: 3)
                  : null,
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(
                    _stepIcons[i],
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    size: 20,
                  ),
          ),
        ),
      );

      if (i < 2) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              color: isCompleted ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    if (_currentStep == 0) {
      return _buildStep1Content();
    } else {
      final photosList =
          _currentStep == 1 ? _ambulancePhotos : _traumaBagPhotos;
      return _buildMultiPhotoContent(photosList);
    }
  }

  // ── Step 1 UI (Central User Photo + Selectable Team) ──
  Widget _buildStep1Content() {
    return Column(
      children: [
        // Central User Photo
        Expanded(
          flex: 2,
          child: Center(
            child: Container(
              width: 260, // Better portrait aspect ratio
              height: 320,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _userPhoto == null
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.primary,
                  width: _userPhoto == null ? 2 : 4,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: _userPhoto != null
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : [],
              ),
              child: _userPhoto == null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // Decorative scanner corners
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _buildScannerCorner(true, true),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildScannerCorner(true, false),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: _buildScannerCorner(false, true),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: _buildScannerCorner(false, false),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural_rounded,
                                size: 56,
                                color: AppColors.primary.withOpacity(0.6)),
                            const SizedBox(height: 12),
                            Text(
                              'ID PHOTO REQUIRED',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap below to capture',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Image.file(
                      _userPhoto!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Team Members Selection
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with selected count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Active Partners:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _teamMembers.any((m) => m['isSelected'] == true)
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_teamMembers.where((m) => m['isSelected'] == true).length} selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _teamMembers.any((m) => m['isSelected'] == true)
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(null, 'All ASSERT'),
                    const SizedBox(width: 6),
                    _buildFilterChip('PDRRMO-ASSERT', 'ASSERT'),
                    const SizedBox(width: 6),
                    _buildFilterChip('PDRRMO-ASSERT IAO', 'ASSERT IAO'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ── Search Bar ──
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search partners...',
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoadingTeam
                    ? const Center(child: CircularProgressIndicator())
                    : _teamMembers.isEmpty
                        ? Center(
                            child: Text(
                              'No partners available.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : _buildGroupedMemberGrid(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final active = _unitFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _unitFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : Colors.grey.shade300,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ── Grouped + Grid team member selector ──
  Widget _buildGroupedMemberGrid() {
    // Only show PDRRMO-ASSERT and PDRRMO-ASSERT IAO, respect active filter
    const allowedUnits = {'PDRRMO-ASSERT', 'PDRRMO-ASSERT IAO'};

    // 1. Pre-filter to allowed units + active unit filter
    final assertMembers = _teamMembers.where((m) {
      final unit = (m['unit'] as String? ?? '').trim();
      if (_unitFilter != null) {
        return unit.toUpperCase() == _unitFilter!.toUpperCase();
      }
      return allowedUnits
          .any((u) => u.toUpperCase() == unit.toUpperCase());
    }).toList();

    final filteredMembers = _searchQuery.isEmpty
        ? assertMembers
        : assertMembers.where((m) {
            final name = (m['name'] as String? ?? '').toLowerCase();
            final pos = (m['position'] as String? ?? '').toLowerCase();
            final unit = (m['unit'] as String? ?? '').toLowerCase();
            final search = _searchQuery.toLowerCase();
            return name.contains(search) ||
                pos.contains(search) ||
                unit.contains(search);
          }).toList();

    if (filteredMembers.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No partners match your search.'
              : 'No ASSERT partners found.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    // 2. Group by unit: PDRRMO-ASSERT before PDRRMO-ASSERT IAO
    final Map<String, List<MapEntry<int, Map<String, dynamic>>>> grouped = {};
    for (final member in filteredMembers) {
      final globalIndex = _teamMembers.indexOf(member);
      final unit = (member['unit'] as String? ?? '').trim();
      grouped.putIfAbsent(unit, () => []).add(MapEntry(globalIndex, member));
    }
    final sortedUnits = grouped.keys.toList()
      ..sort((a, b) {
        final aIsIao = a.toUpperCase().contains('IAO');
        final bIsIao = b.toUpperCase().contains('IAO');
        if (!aIsIao && bIsIao) return -1;
        if (aIsIao && !bIsIao) return 1;
        return a.compareTo(b);
      });

    return ListView.builder(
      itemCount: sortedUnits.length,
      itemBuilder: (context, groupIndex) {
        final unitLabel = sortedUnits[groupIndex];
        final members = grouped[unitLabel]!;
        final selectedInGroup =
            members.where((e) => e.value['isSelected'] == true).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Unit Section Header ──
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          unitLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedInGroup > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selectedInGroup selected',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${members.length} members',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // ── Member Cards Grid ──
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.68,
              ),
              itemCount: members.length,
              itemBuilder: (context, idx) {
                return _buildMemberCard(members[idx].key, members[idx].value);
              },
            ),
            if (groupIndex < sortedUnits.length - 1)
              const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildMemberCard(int globalIndex, Map<String, dynamic> member) {
    final isSelected = member['isSelected'] as bool? ?? false;
    final String name = member['name'] as String? ?? '';
    final String position = member['position'] as String? ?? '';
    final String? photoUrl = member['photo_url'] as String?;

    // First name only for compactness
    final displayName = name.split(' ').first;

    return GestureDetector(
      onTap: () => _toggleMemberSelection(globalIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.18)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar fills most of the card ──
            Expanded(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _personPlaceholder(isSelected),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return _personPlaceholder(isSelected);
                              },
                            )
                          : _personPlaceholder(isSelected),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Compact name row ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (position.isNotEmpty)
                    Text(
                      position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Steps 2 & 3 UI (Multiple Photos Grid) ──
  Widget _buildMultiPhotoContent(List<File> photos) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Captured: ${photos.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Required: $minPhotosRequired',
              style: TextStyle(
                color: photos.length >= minPhotosRequired
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: photos.isEmpty
              ? Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_a_photo_outlined,
                            size: 48, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AWAITING IMAGES',
                        style: TextStyle(
                          color: AppColors.secondaryDark,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "CAPTURE PHOTO" to begin',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                            image: DecorationImage(
                              image: FileImage(photos[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _personPlaceholder(bool isSelected) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isSelected
          ? AppColors.primary.withOpacity(0.12)
          : Colors.grey.shade100,
      child: Icon(
        Icons.person,
        size: 36,
        color: isSelected ? AppColors.primary : Colors.grey.shade400,
      ),
    );
  }

  // Helper for technical ID photo corners
  Widget _buildScannerCorner(bool isTop, bool isLeft) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 3)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 3)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 3)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}
