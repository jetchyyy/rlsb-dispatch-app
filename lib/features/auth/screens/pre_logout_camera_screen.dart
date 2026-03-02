import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../presentation/providers/auth_provider.dart';

class PreLogoutCameraScreen extends StatefulWidget {
  const PreLogoutCameraScreen({super.key});

  @override
  State<PreLogoutCameraScreen> createState() => _PreLogoutCameraScreenState();
}

class _PreLogoutCameraScreenState extends State<PreLogoutCameraScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();

  // Step 1: Turnover Items
  final List<File> _itemPhotos = [];
  final TextEditingController _notesController = TextEditingController();

  // Step 2: Ambulance (Interior/Exterior)
  final List<File> _ambulancePhotos = [];
  // Using a map to visually label what the user is taking a picture of if we choose,
  // but for a dynamic grid we'll just store files. The UI will prompt specifically.

  // Step 3: Odometer
  File? _odometerPhoto;

  // Minimum required photos
  static const int minItemPhotos = 1;
  static const int minAmbulancePhotos = 2;

  final List<String> _stepTitles = [
    'Turnover Items',
    'Ambulance Log',
    'Odometer Log',
    'Completion'
  ];

  final List<IconData> _stepIcons = [
    Icons.inventory_2_rounded,
    Icons.directions_car_filled_rounded,
    Icons.speed_rounded,
    Icons.verified_rounded
  ];

  final List<String> _stepDescriptions = [
    'Take photos of turnover items and optionally add notes below.',
    'Take at least $minAmbulancePhotos photos of the Ambulance (Interior & Exterior).',
    'Take a clear picture of the Dashboard Odometer.',
    'Thank you for your service.'
  ];

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null && mounted) {
        setState(() {
          if (_currentStep == 0) {
            _itemPhotos.add(File(photo.path));
          } else if (_currentStep == 1) {
            _ambulancePhotos.add(File(photo.path));
          } else if (_currentStep == 2) {
            _odometerPhoto = File(photo.path);
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
      if (_currentStep == 0) {
        _itemPhotos.removeAt(index);
      } else if (_currentStep == 1) {
        _ambulancePhotos.removeAt(index);
      } else if (_currentStep == 2) {
        _odometerPhoto = null;
      }
    });
  }

  void _nextStep() async {
    // Validation
    if (_currentStep == 0) {
      if (_itemPhotos.length < minItemPhotos) {
        _showError('Please capture at least $minItemPhotos item photo.');
        return;
      }
    } else if (_currentStep == 1) {
      if (_ambulancePhotos.length < minAmbulancePhotos) {
        _showError(
            'Please capture at least $minAmbulancePhotos photos (Interior & Exterior).');
        return;
      }
    } else if (_currentStep == 2) {
      if (_odometerPhoto == null) {
        _showError('Please capture the odometer.');
        return;
      }
    }

    // Proceed to Step 4 (Completion)
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });

      // If we just entered Step 3 (index 3), trigger the final logout delay
      if (_currentStep == 3) {
        _finalizeLogout();
      }
    }
  }

  Future<void> _finalizeLogout() async {
    // Delay to let user see the Thank You message
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        context.go('/login');
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Logout Turnover'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 3) {
              setState(() {
                _currentStep--;
              });
            } else if (_currentStep == 0) {
              // If they back out of the logout, cancel the flow and go back to Dashboard
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
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

              // Action Buttons (Hidden on final Thank You step)
              if (_currentStep < 3)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            (_currentStep == 2 && _odometerPhoto != null)
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
                          onPressed: _nextStep,
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
                            _currentStep == 2 ? 'Submit & Logout' : 'Next Step',
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
    if (_currentStep == 0) return _itemPhotos.length >= minItemPhotos;
    if (_currentStep == 1) return _ambulancePhotos.length >= minAmbulancePhotos;
    if (_currentStep == 2) return _odometerPhoto != null;
    return false;
  }

  Widget _buildStepIndicator() {
    List<Widget> children = [];
    for (int i = 0; i < 4; i++) {
      final isActive = i == _currentStep;
      final isCompleted = i < _currentStep;

      children.add(
        Container(
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
      );

      if (i < 3) {
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    if (_currentStep == 0) {
      return _buildStep1Content();
    } else if (_currentStep == 1) {
      return _buildAmbulanceGrid();
    } else if (_currentStep == 2) {
      return _buildOdometerContent();
    } else {
      return _buildStep4Content();
    }
  }

  // ── Step 1 UI (Items & Writable Text) ──
  Widget _buildStep1Content() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Captured: ${_itemPhotos.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Required: $minItemPhotos',
              style: TextStyle(
                color: _itemPhotos.length >= minItemPhotos
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: _itemPhotos.isEmpty
              ? _buildEmptyState('No item photos yet.\nTap below to capture.',
                  Icons.photo_library_outlined)
              : _buildPhotoGrid(_itemPhotos),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _notesController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: 'Add turnover notes or item details here...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2 UI (Ambulance with Labels inside Empty State) ──
  Widget _buildAmbulanceGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Captured: ${_ambulancePhotos.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Required: $minAmbulancePhotos',
              style: TextStyle(
                color: _ambulancePhotos.length >= minAmbulancePhotos
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Visual Labels helper
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.door_sliding_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Exterior',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.airline_seat_recline_normal_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text('Interior',
                      style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _ambulancePhotos.isEmpty
              ? _buildEmptyState(
                  'Please capture both the interior and exterior of the ambulance.',
                  Icons.camera_front_outlined)
              : _buildPhotoGrid(_ambulancePhotos),
        ),
      ],
    );
  }

  // ── Step 3 UI (Odometer) ──
  Widget _buildOdometerContent() {
    return Column(
      children: [
        Expanded(
          child: _odometerPhoto == null
              ? _buildEmptyState(
                  'Odometer photo required.\nTap below to capture.',
                  Icons.speed_outlined)
              : Stack(
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
                          image: FileImage(_odometerPhoto!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removePhoto(0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Step 4 UI (Thank You & Completion) ──
  Widget _buildStep4Content() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 80,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Turnover Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your logs have been saved securely.\nLogging you out now...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 48),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<File> photos) {
    return GridView.builder(
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
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
