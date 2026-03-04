import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../presentation/providers/auth_provider.dart';
import '../services/pre_logout_turnover_api_service.dart';

class PreLogoutCameraScreen extends StatefulWidget {
  const PreLogoutCameraScreen({super.key});

  @override
  State<PreLogoutCameraScreen> createState() => _PreLogoutCameraScreenState();
}

class _PreLogoutCameraScreenState extends State<PreLogoutCameraScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();
  int _carIconTapCount = 0;

  // Step 1: Turnover Items
  final List<File> _itemPhotos = [];
  final TextEditingController _notesController = TextEditingController();

  // Step 2: Ambulance Photos (Interior/Exterior)
  final List<File> _ambulancePhotos = [];

  // Step 3: Odometer Photo
  File? _odometerPhoto;

  bool _isFinalizing = false;

  final List<String> _stepTitles = [
    'Turnover Items',
    'Ambulance Condition',
    'Odometer Reading',
    'Complete',
  ];

  final List<IconData> _stepIcons = [
    Icons.inventory_2_rounded,
    Icons.directions_car_filled_rounded,
    Icons.speed_rounded,
    Icons.check_circle_rounded,
  ];

  final List<String> _stepDescriptions = [
    'Take photos of the items being turned over and add any necessary notes below.',
    'Take at least 2 photos of the Ambulance (Interior & Exterior).',
    'Take a clear photo of the current odometer reading.',
    'Turnover sequence completed successfully.',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
            _nextStep(); // Auto advance when odometer is captured
          }
        });
      }
    } catch (e) {
      _showError('Error accessing camera: $e');
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

  void _nextStep() {
    // Validation
    if (_currentStep == 0 && _itemPhotos.isEmpty) {
      _showError('Please take at least one photo of the turnover items.');
      return;
    } else if (_currentStep == 1 && _ambulancePhotos.length < 2) {
      _showError('Please take at least 2 photos of the ambulance.');
      return;
    } else if (_currentStep == 2 && _odometerPhoto == null) {
      _showError('Please capture a photo of the odometer.');
      return;
    }

    // Proceed
    if (_currentStep < 3) {
      setState(() => _currentStep++);

      // Auto finalize on the last step
      if (_currentStep == 3) {
        _finalizeLogout();
      }
    }
  }

  Future<void> _finalizeLogout() async {
    setState(() => _isFinalizing = true);

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user;

      if (_odometerPhoto == null) {
        throw Exception('Odometer photo is required.');
      }

      final api = await PreLogoutTurnoverApiService.create();
      await api.submit(
        userId: user?.id,
        turnoverDate: DateTime.now(),
        unit: user?.unit,
        notes: _notesController.text.trim(),
        itemPhotos: _itemPhotos,
        ambulancePhotos: _ambulancePhotos,
        odometerPhoto: _odometerPhoto!,
        deviceTime: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pre-logout turnover submitted successfully to MIS.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      await context.read<AuthProvider>().logout();
      if (mounted) {
        context.go('/login');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(_extractApiError(e));
      setState(() {
        _isFinalizing = false;
        _currentStep = 2;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit turnover logs: $e');
      setState(() {
        _isFinalizing = false;
        _currentStep = 2;
      });
    }
  }

  String _extractApiError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message']?.toString();
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            return '${value.first} (HTTP ${status ?? 'unknown'})';
          }
        }
      }
      if (message != null && message.isNotEmpty) {
        return '$message (HTTP ${status ?? 'unknown'})';
      }
    }

    if (data is String && data.isNotEmpty) {
      final short = data.substring(0, data.length > 140 ? 140 : data.length);
      return '$short (HTTP ${status ?? 'unknown'})';
    }

    return 'Failed to submit turnover logs to MIS. (HTTP ${status ?? 'unknown'})';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onStepIconTapped(int stepIndex) async {
    if (_isFinalizing || stepIndex != 1) return;

    _carIconTapCount++;
    if (_carIconTapCount < 10) return;

    _carIconTapCount = 0;
    await _showSlotMachineMiniGame();
  }

  Future<void> _showSlotMachineMiniGame() async {
    final random = Random();
    const symbols = ['🍒', '🍋', '🍉', '7️⃣', '⭐'];
    const scatter = '⭐';

    var reelOne = symbols[random.nextInt(symbols.length)];
    var reelTwo = symbols[random.nextInt(symbols.length)];
    var reelThree = symbols[random.nextInt(symbols.length)];
    var spinning = false;
    var unlocked = false;
    var message = 'Hit SCATTER SCATTER SCATTER to unlock skip.';

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setGameState) {
            Future<void> spin() async {
              if (spinning) return;

              setGameState(() {
                spinning = true;
                unlocked = false;
                message = 'Spinning reels...';
              });

              for (int i = 0; i < 22; i++) {
                await Future.delayed(const Duration(milliseconds: 85));
                setGameState(() {
                  reelOne = symbols[random.nextInt(symbols.length)];
                  reelTwo = symbols[random.nextInt(symbols.length)];
                  reelThree = symbols[random.nextInt(symbols.length)];
                });
              }

              setGameState(() {
                spinning = false;
                unlocked =
                    reelOne == scatter && reelTwo == scatter && reelThree == scatter;
                message = unlocked
                    ? 'JACKPOT! SCATTER x3 unlocked skip.'
                    : 'No SCATTER combo. Try again.';
              });
            }

            Future<void> reset() async {
              setGameState(() {
                reelOne = symbols[random.nextInt(symbols.length)];
                reelTwo = symbols[random.nextInt(symbols.length)];
                reelThree = symbols[random.nextInt(symbols.length)];
                spinning = false;
                unlocked = false;
                message = 'Hit SCATTER SCATTER SCATTER to unlock skip.';
              });
            }

            Future<void> onSkip() async {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Turnover checklist skipped via secret mode.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await this.context.read<AuthProvider>().logout();
              if (mounted) {
                this.context.go('/login');
              }
            }

            Widget reel(String symbol, {VoidCallback? onTap}) {
              final reelBody = AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                width: 82,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: unlocked
                        ? const Color(0xFF22C55E)
                        : Colors.white.withOpacity(0.25),
                    width: unlocked ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (spinning ? Colors.cyan : Colors.black).withOpacity(0.3),
                      blurRadius: spinning ? 14 : 6,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: AnimatedScale(
                  scale: spinning ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  child: Text(
                    symbol,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              );
              if (onTap == null) return reelBody;
              return GestureDetector(onTap: onTap, child: reelBody);
            }

            void forceScatterJackpot() {
              if (spinning) return;
              setGameState(() {
                reelOne = scatter;
                reelTwo = scatter;
                reelThree = scatter;
                unlocked = true;
                message = 'Secret hit! SCATTER x3 unlocked skip.';
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              title: const Text(
                'Secret Mode: Slot Machine',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C2D12), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        reel(reelOne),
                        const SizedBox(width: 8),
                        reel(
                          reelTwo,
                          onTap: forceScatterJackpot,
                        ),
                        const SizedBox(width: 8),
                        reel(reelThree),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: unlocked ? const Color(0xFF86EFAC) : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: spinning ? null : reset,
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: spinning ? null : spin,
                  child: Text(spinning ? 'Spinning...' : 'Spin'),
                ),
                if (unlocked)
                  ElevatedButton(
                    onPressed: onSkip,
                    child: const Text('Skip Turnover'),
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

  bool _isCurrentStepValid() {
    if (_currentStep == 0) return _itemPhotos.isNotEmpty;
    if (_currentStep == 1) return _ambulancePhotos.length >= 2;
    if (_currentStep == 2) return _odometerPhoto != null;
    return true; // Step 3
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
              setState(() => _currentStep--);
            } else if (_currentStep == 0) {
              Navigator.pop(
                  context); // Go back to dashboard without logging out
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              if (_currentStep < 3) ...[
                const SizedBox(height: 24),
                _buildStepIndicator(),
                const SizedBox(height: 32),
              ],
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
                    if (_currentStep < 3) ...[
                      const SizedBox(height: 8),
                      Text(
                        _stepDescriptions[_currentStep],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    key: ValueKey<int>(_currentStep),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCurrentStepContent(),
                  ),
                ),
              ),
              if (_currentStep < 3) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_currentStep < 2 ||
                          (_currentStep == 2 && _odometerPhoto == null))
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isFinalizing ? null : _takePhoto,
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
                      if (_currentStep < 2) const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isFinalizing ? null : _nextStep,
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
                                ? (_isFinalizing
                                    ? 'Submitting...'
                                    : 'Submit & Logout')
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
            ],
          ),
        ),
      ),
    );
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
    if (_currentStep == 0) return _buildStep1Content();
    if (_currentStep == 1) return _buildAmbulanceGrid();
    if (_currentStep == 2) return _buildOdometerContent();
    return _buildStep4Content();
  }

  // ── Step 1: Turnover Items ──
  Widget _buildStep1Content() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _itemPhotos.isEmpty
              ? _buildEmptyState('No items captured yet.')
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _itemPhotos.length,
                  itemBuilder: (context, index) =>
                      _buildPhotoCard(_itemPhotos[index], index),
                ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _notesController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText:
                  'Enter specific items being turned over or any relevant notes...',
              filled: true,
              fillColor: Colors.white,
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
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Ambulance Check ──
  Widget _buildAmbulanceGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Captured: ${_ambulancePhotos.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Required: 2 (Interior & Exterior)',
              style: TextStyle(
                color: _ambulancePhotos.length >= 2
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _ambulancePhotos.isEmpty
              ? _buildEmptyState('No exterior or interior photos captured yet.')
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _ambulancePhotos.length,
                  itemBuilder: (context, index) => Stack(
                    children: [
                      _buildPhotoCard(_ambulancePhotos[index], index),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            index == 0
                                ? 'Exterior'
                                : (index == 1 ? 'Interior' : 'Extra'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── Step 3: Odometer ──
  Widget _buildOdometerContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_odometerPhoto == null)
          _buildEmptyState('Snap a photo of the dashboard odometer.')
        else
          Expanded(
            child: _buildPhotoCard(_odometerPhoto!, 0),
          ),
      ],
    );
  }

  // ── Step 4: Thank You / Loading ──
  Widget _buildStep4Content() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(seconds: 1),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 100, color: AppColors.success),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Thank You for your Service!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your turnover logs have been successfully submitted.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 48),
          if (_isFinalizing)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Logging you out securely...',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(File photo, int index) {
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
              image: FileImage(photo),
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
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_back_outlined,
              size: 64, color: Colors.grey.shade300),
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
}
