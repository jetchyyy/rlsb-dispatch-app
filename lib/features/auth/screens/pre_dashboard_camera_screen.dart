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
  final List<Map<String, dynamic>> _teamMembers = [
    {'id': '1', 'name': 'Partner A', 'isSelected': false},
    {'id': '2', 'name': 'Partner B', 'isSelected': false},
    {'id': '3', 'name': 'Partner C', 'isSelected': false},
  ];

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
                              ? 'Retake Photo'
                              : 'Take Photo',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                              : Colors.grey.shade300,
                          foregroundColor: _isCurrentStepValid()
                              ? Colors.white
                              : Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentStep == 2
                              ? (_isSubmitting
                                  ? 'Submitting...'
                                  : 'Complete Checklist')
                              : 'Next Step',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
          flex: 3,
          child: Center(
            child: Container(
              width: 500,
              height: 500,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _userPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1,
                            size: 50, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Tap below\nto capture',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
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
        const SizedBox(height: 24),
        // Team Members Selection
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Active Partners:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = _teamMembers[index];
                    final isSelected = member['isSelected'];
                    return GestureDetector(
                      onTap: () => _toggleMemberSelection(index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              width: isSelected ? 86 : 76,
                              height: isSelected ? 86 : 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 4 : 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: ClipOval(
                                child: ColorFiltered(
                                  colorFilter: isSelected
                                      ? const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.multiply,
                                        )
                                      : const ColorFilter.mode(
                                          Colors.grey,
                                          BlendMode.saturation,
                                        ),
                                  child: Image.asset(
                                    'assets/images/hero1.png', // Temporary placeholder
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              member['name'],
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No photos yet.\nTap below to capture.',
                        textAlign: TextAlign.center,
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
}
