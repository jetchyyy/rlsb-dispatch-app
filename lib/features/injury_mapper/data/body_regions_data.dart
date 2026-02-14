import 'dart:ui';

import '../../../../core/models/body_region.dart';

/// Normalized polygon coordinates (0.0–1.0) for 50+ body regions.
/// Front and back views defined separately.
///
/// Coordinate system: (0, 0) = top-left, (1, 1) = bottom-right
/// of the body silhouette image.
class BodyRegionsData {
  BodyRegionsData._();

  static final List<BodyRegion> allRegions = [
    ...frontRegions,
    ...backRegions,
  ];

  // ═══════════════════════════════════════════════════════════
  //  FRONT VIEW
  // ═══════════════════════════════════════════════════════════

  static final List<BodyRegion> frontRegions = [
    // ─── Head (Front) ────────────────────────────────────────
    BodyRegion(
      regionId: 'head_front',
      regionName: 'Head (Front)',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.40, 0.02),
        Offset(0.60, 0.02),
        Offset(0.64, 0.05),
        Offset(0.64, 0.09),
        Offset(0.60, 0.12),
        Offset(0.40, 0.12),
        Offset(0.36, 0.09),
        Offset(0.36, 0.05),
      ],
    ),
    BodyRegion(
      regionId: 'forehead',
      regionName: 'Forehead',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.42, 0.02),
        Offset(0.58, 0.02),
        Offset(0.60, 0.04),
        Offset(0.60, 0.06),
        Offset(0.40, 0.06),
        Offset(0.40, 0.04),
      ],
    ),
    BodyRegion(
      regionId: 'left_eye',
      regionName: 'Left Eye',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.43, 0.06),
        Offset(0.47, 0.06),
        Offset(0.48, 0.07),
        Offset(0.47, 0.08),
        Offset(0.43, 0.08),
        Offset(0.42, 0.07),
      ],
    ),
    BodyRegion(
      regionId: 'right_eye',
      regionName: 'Right Eye',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.53, 0.06),
        Offset(0.57, 0.06),
        Offset(0.58, 0.07),
        Offset(0.57, 0.08),
        Offset(0.53, 0.08),
        Offset(0.52, 0.07),
      ],
    ),
    BodyRegion(
      regionId: 'nose',
      regionName: 'Nose',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.48, 0.06),
        Offset(0.52, 0.06),
        Offset(0.53, 0.09),
        Offset(0.50, 0.10),
        Offset(0.47, 0.09),
      ],
    ),
    BodyRegion(
      regionId: 'mouth_jaw',
      regionName: 'Mouth / Jaw',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.44, 0.09),
        Offset(0.56, 0.09),
        Offset(0.58, 0.11),
        Offset(0.55, 0.13),
        Offset(0.45, 0.13),
        Offset(0.42, 0.11),
      ],
    ),
    BodyRegion(
      regionId: 'left_ear',
      regionName: 'Left Ear',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.36, 0.06),
        Offset(0.39, 0.06),
        Offset(0.39, 0.10),
        Offset(0.36, 0.10),
      ],
    ),
    BodyRegion(
      regionId: 'right_ear',
      regionName: 'Right Ear',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.61, 0.06),
        Offset(0.64, 0.06),
        Offset(0.64, 0.10),
        Offset(0.61, 0.10),
      ],
    ),

    // ─── Neck (Front) ────────────────────────────────────────
    BodyRegion(
      regionId: 'neck_front',
      regionName: 'Neck (Front)',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.44, 0.12),
        Offset(0.56, 0.12),
        Offset(0.56, 0.16),
        Offset(0.44, 0.16),
      ],
    ),

    // ─── Torso (Front) ──────────────────────────────────────
    BodyRegion(
      regionId: 'chest',
      regionName: 'Chest',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.35, 0.18),
        Offset(0.65, 0.18),
        Offset(0.65, 0.30),
        Offset(0.35, 0.30),
      ],
    ),
    BodyRegion(
      regionId: 'sternum',
      regionName: 'Sternum',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.47, 0.18),
        Offset(0.53, 0.18),
        Offset(0.53, 0.30),
        Offset(0.47, 0.30),
      ],
    ),
    BodyRegion(
      regionId: 'left_ribcage',
      regionName: 'Left Ribcage',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.30, 0.22),
        Offset(0.40, 0.22),
        Offset(0.40, 0.34),
        Offset(0.30, 0.34),
      ],
    ),
    BodyRegion(
      regionId: 'right_ribcage',
      regionName: 'Right Ribcage',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.60, 0.22),
        Offset(0.70, 0.22),
        Offset(0.70, 0.34),
        Offset(0.60, 0.34),
      ],
    ),
    BodyRegion(
      regionId: 'abdomen',
      regionName: 'Abdomen',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.37, 0.30),
        Offset(0.63, 0.30),
        Offset(0.63, 0.40),
        Offset(0.37, 0.40),
      ],
    ),
    BodyRegion(
      regionId: 'groin',
      regionName: 'Groin',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.42, 0.40),
        Offset(0.58, 0.40),
        Offset(0.56, 0.45),
        Offset(0.44, 0.45),
      ],
    ),

    // ─── Left Arm (Front) ───────────────────────────────────
    BodyRegion(
      regionId: 'left_shoulder',
      regionName: 'Left Shoulder',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.25, 0.16),
        Offset(0.35, 0.16),
        Offset(0.35, 0.20),
        Offset(0.25, 0.20),
      ],
    ),
    BodyRegion(
      regionId: 'left_upper_arm',
      regionName: 'Left Upper Arm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.22, 0.20),
        Offset(0.30, 0.20),
        Offset(0.28, 0.32),
        Offset(0.20, 0.32),
      ],
    ),
    BodyRegion(
      regionId: 'left_elbow',
      regionName: 'Left Elbow',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.19, 0.32),
        Offset(0.27, 0.32),
        Offset(0.26, 0.36),
        Offset(0.18, 0.36),
      ],
    ),
    BodyRegion(
      regionId: 'left_forearm',
      regionName: 'Left Forearm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.17, 0.36),
        Offset(0.25, 0.36),
        Offset(0.23, 0.46),
        Offset(0.15, 0.46),
      ],
    ),
    BodyRegion(
      regionId: 'left_wrist',
      regionName: 'Left Wrist',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.14, 0.46),
        Offset(0.22, 0.46),
        Offset(0.21, 0.48),
        Offset(0.13, 0.48),
      ],
    ),
    BodyRegion(
      regionId: 'left_hand',
      regionName: 'Left Hand',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.12, 0.48),
        Offset(0.20, 0.48),
        Offset(0.19, 0.53),
        Offset(0.11, 0.53),
      ],
    ),
    BodyRegion(
      regionId: 'left_fingers',
      regionName: 'Left Fingers',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.10, 0.53),
        Offset(0.18, 0.53),
        Offset(0.17, 0.57),
        Offset(0.09, 0.57),
      ],
    ),
    BodyRegion(
      regionId: 'left_palm',
      regionName: 'Left Palm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.12, 0.49),
        Offset(0.19, 0.49),
        Offset(0.18, 0.54),
        Offset(0.11, 0.54),
      ],
    ),

    // ─── Right Arm (Front) ──────────────────────────────────
    BodyRegion(
      regionId: 'right_shoulder',
      regionName: 'Right Shoulder',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.65, 0.16),
        Offset(0.75, 0.16),
        Offset(0.75, 0.20),
        Offset(0.65, 0.20),
      ],
    ),
    BodyRegion(
      regionId: 'right_upper_arm',
      regionName: 'Right Upper Arm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.70, 0.20),
        Offset(0.78, 0.20),
        Offset(0.80, 0.32),
        Offset(0.72, 0.32),
      ],
    ),
    BodyRegion(
      regionId: 'right_elbow',
      regionName: 'Right Elbow',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.73, 0.32),
        Offset(0.81, 0.32),
        Offset(0.82, 0.36),
        Offset(0.74, 0.36),
      ],
    ),
    BodyRegion(
      regionId: 'right_forearm',
      regionName: 'Right Forearm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.75, 0.36),
        Offset(0.83, 0.36),
        Offset(0.85, 0.46),
        Offset(0.77, 0.46),
      ],
    ),
    BodyRegion(
      regionId: 'right_wrist',
      regionName: 'Right Wrist',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.78, 0.46),
        Offset(0.86, 0.46),
        Offset(0.87, 0.48),
        Offset(0.79, 0.48),
      ],
    ),
    BodyRegion(
      regionId: 'right_hand',
      regionName: 'Right Hand',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.80, 0.48),
        Offset(0.88, 0.48),
        Offset(0.89, 0.53),
        Offset(0.81, 0.53),
      ],
    ),
    BodyRegion(
      regionId: 'right_fingers',
      regionName: 'Right Fingers',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.82, 0.53),
        Offset(0.90, 0.53),
        Offset(0.91, 0.57),
        Offset(0.83, 0.57),
      ],
    ),
    BodyRegion(
      regionId: 'right_palm',
      regionName: 'Right Palm',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.81, 0.49),
        Offset(0.88, 0.49),
        Offset(0.89, 0.54),
        Offset(0.82, 0.54),
      ],
    ),

    // ─── Left Leg (Front) ───────────────────────────────────
    BodyRegion(
      regionId: 'left_hip',
      regionName: 'Left Hip',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.35, 0.38),
        Offset(0.44, 0.38),
        Offset(0.44, 0.44),
        Offset(0.35, 0.44),
      ],
    ),
    BodyRegion(
      regionId: 'left_thigh',
      regionName: 'Left Thigh',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.36, 0.44),
        Offset(0.48, 0.44),
        Offset(0.47, 0.58),
        Offset(0.37, 0.58),
      ],
    ),
    BodyRegion(
      regionId: 'left_knee',
      regionName: 'Left Knee',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.37, 0.58),
        Offset(0.47, 0.58),
        Offset(0.47, 0.64),
        Offset(0.37, 0.64),
      ],
    ),
    BodyRegion(
      regionId: 'left_lower_leg',
      regionName: 'Left Lower Leg',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.38, 0.64),
        Offset(0.47, 0.64),
        Offset(0.46, 0.80),
        Offset(0.39, 0.80),
      ],
    ),
    BodyRegion(
      regionId: 'left_ankle',
      regionName: 'Left Ankle',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.39, 0.80),
        Offset(0.46, 0.80),
        Offset(0.46, 0.84),
        Offset(0.39, 0.84),
      ],
    ),
    BodyRegion(
      regionId: 'left_foot',
      regionName: 'Left Foot',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.37, 0.84),
        Offset(0.46, 0.84),
        Offset(0.47, 0.90),
        Offset(0.36, 0.90),
      ],
    ),
    BodyRegion(
      regionId: 'left_toes',
      regionName: 'Left Toes',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.35, 0.90),
        Offset(0.47, 0.90),
        Offset(0.48, 0.94),
        Offset(0.34, 0.94),
      ],
    ),

    // ─── Right Leg (Front) ──────────────────────────────────
    BodyRegion(
      regionId: 'right_hip',
      regionName: 'Right Hip',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.56, 0.38),
        Offset(0.65, 0.38),
        Offset(0.65, 0.44),
        Offset(0.56, 0.44),
      ],
    ),
    BodyRegion(
      regionId: 'right_thigh',
      regionName: 'Right Thigh',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.52, 0.44),
        Offset(0.64, 0.44),
        Offset(0.63, 0.58),
        Offset(0.53, 0.58),
      ],
    ),
    BodyRegion(
      regionId: 'right_knee',
      regionName: 'Right Knee',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.53, 0.58),
        Offset(0.63, 0.58),
        Offset(0.63, 0.64),
        Offset(0.53, 0.64),
      ],
    ),
    BodyRegion(
      regionId: 'right_lower_leg',
      regionName: 'Right Lower Leg',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.53, 0.64),
        Offset(0.62, 0.64),
        Offset(0.61, 0.80),
        Offset(0.54, 0.80),
      ],
    ),
    BodyRegion(
      regionId: 'right_ankle',
      regionName: 'Right Ankle',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.54, 0.80),
        Offset(0.61, 0.80),
        Offset(0.61, 0.84),
        Offset(0.54, 0.84),
      ],
    ),
    BodyRegion(
      regionId: 'right_foot',
      regionName: 'Right Foot',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.54, 0.84),
        Offset(0.63, 0.84),
        Offset(0.64, 0.90),
        Offset(0.53, 0.90),
      ],
    ),
    BodyRegion(
      regionId: 'right_toes',
      regionName: 'Right Toes',
      view: BodyView.front,
      polygonPoints: const [
        Offset(0.52, 0.90),
        Offset(0.65, 0.90),
        Offset(0.66, 0.94),
        Offset(0.52, 0.94),
      ],
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  //  BACK VIEW
  // ═══════════════════════════════════════════════════════════

  static final List<BodyRegion> backRegions = [
    // ─── Head (Back) ─────────────────────────────────────────
    BodyRegion(
      regionId: 'head_back',
      regionName: 'Head (Back)',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.40, 0.02),
        Offset(0.60, 0.02),
        Offset(0.64, 0.05),
        Offset(0.64, 0.09),
        Offset(0.60, 0.12),
        Offset(0.40, 0.12),
        Offset(0.36, 0.09),
        Offset(0.36, 0.05),
      ],
    ),

    // ─── Neck (Back) ─────────────────────────────────────────
    BodyRegion(
      regionId: 'neck_back',
      regionName: 'Neck (Back)',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.44, 0.12),
        Offset(0.56, 0.12),
        Offset(0.56, 0.16),
        Offset(0.44, 0.16),
      ],
    ),

    // ─── Upper Back ──────────────────────────────────────────
    BodyRegion(
      regionId: 'upper_back',
      regionName: 'Upper Back',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.32, 0.16),
        Offset(0.68, 0.16),
        Offset(0.68, 0.30),
        Offset(0.32, 0.30),
      ],
    ),

    // ─── Shoulder Blades ─────────────────────────────────────
    BodyRegion(
      regionId: 'left_shoulder_blade',
      regionName: 'Left Shoulder Blade',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.32, 0.18),
        Offset(0.45, 0.18),
        Offset(0.44, 0.28),
        Offset(0.33, 0.28),
      ],
    ),
    BodyRegion(
      regionId: 'right_shoulder_blade',
      regionName: 'Right Shoulder Blade',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.55, 0.18),
        Offset(0.68, 0.18),
        Offset(0.67, 0.28),
        Offset(0.56, 0.28),
      ],
    ),

    // ─── Spine ───────────────────────────────────────────────
    BodyRegion(
      regionId: 'spine_upper',
      regionName: 'Upper Spine',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.47, 0.16),
        Offset(0.53, 0.16),
        Offset(0.53, 0.30),
        Offset(0.47, 0.30),
      ],
    ),
    BodyRegion(
      regionId: 'spine_lower',
      regionName: 'Lower Spine',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.47, 0.30),
        Offset(0.53, 0.30),
        Offset(0.53, 0.42),
        Offset(0.47, 0.42),
      ],
    ),

    // ─── Lower Back ──────────────────────────────────────────
    BodyRegion(
      regionId: 'lower_back',
      regionName: 'Lower Back',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.35, 0.30),
        Offset(0.65, 0.30),
        Offset(0.65, 0.42),
        Offset(0.35, 0.42),
      ],
    ),

    // ─── Buttocks ────────────────────────────────────────────
    BodyRegion(
      regionId: 'left_buttock',
      regionName: 'Left Buttock',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.36, 0.40),
        Offset(0.50, 0.40),
        Offset(0.49, 0.48),
        Offset(0.37, 0.48),
      ],
    ),
    BodyRegion(
      regionId: 'right_buttock',
      regionName: 'Right Buttock',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.50, 0.40),
        Offset(0.64, 0.40),
        Offset(0.63, 0.48),
        Offset(0.51, 0.48),
      ],
    ),

    // ─── Left Shoulder (Back) ────────────────────────────────
    BodyRegion(
      regionId: 'left_shoulder',
      regionName: 'Left Shoulder',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.25, 0.16),
        Offset(0.35, 0.16),
        Offset(0.35, 0.20),
        Offset(0.25, 0.20),
      ],
    ),

    // ─── Right Shoulder (Back) ───────────────────────────────
    BodyRegion(
      regionId: 'right_shoulder',
      regionName: 'Right Shoulder',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.65, 0.16),
        Offset(0.75, 0.16),
        Offset(0.75, 0.20),
        Offset(0.65, 0.20),
      ],
    ),

    // ─── Left Arm (Back) ────────────────────────────────────
    BodyRegion(
      regionId: 'left_upper_arm',
      regionName: 'Left Upper Arm',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.22, 0.20),
        Offset(0.30, 0.20),
        Offset(0.28, 0.32),
        Offset(0.20, 0.32),
      ],
    ),
    BodyRegion(
      regionId: 'left_elbow',
      regionName: 'Left Elbow',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.19, 0.32),
        Offset(0.27, 0.32),
        Offset(0.26, 0.36),
        Offset(0.18, 0.36),
      ],
    ),
    BodyRegion(
      regionId: 'left_forearm',
      regionName: 'Left Forearm',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.17, 0.36),
        Offset(0.25, 0.36),
        Offset(0.23, 0.46),
        Offset(0.15, 0.46),
      ],
    ),
    BodyRegion(
      regionId: 'left_wrist',
      regionName: 'Left Wrist',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.14, 0.46),
        Offset(0.22, 0.46),
        Offset(0.21, 0.48),
        Offset(0.13, 0.48),
      ],
    ),
    BodyRegion(
      regionId: 'left_hand',
      regionName: 'Left Hand',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.12, 0.48),
        Offset(0.20, 0.48),
        Offset(0.19, 0.53),
        Offset(0.11, 0.53),
      ],
    ),
    BodyRegion(
      regionId: 'left_fingers',
      regionName: 'Left Fingers',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.10, 0.53),
        Offset(0.18, 0.53),
        Offset(0.17, 0.57),
        Offset(0.09, 0.57),
      ],
    ),

    // ─── Right Arm (Back) ───────────────────────────────────
    BodyRegion(
      regionId: 'right_upper_arm',
      regionName: 'Right Upper Arm',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.70, 0.20),
        Offset(0.78, 0.20),
        Offset(0.80, 0.32),
        Offset(0.72, 0.32),
      ],
    ),
    BodyRegion(
      regionId: 'right_elbow',
      regionName: 'Right Elbow',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.73, 0.32),
        Offset(0.81, 0.32),
        Offset(0.82, 0.36),
        Offset(0.74, 0.36),
      ],
    ),
    BodyRegion(
      regionId: 'right_forearm',
      regionName: 'Right Forearm',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.75, 0.36),
        Offset(0.83, 0.36),
        Offset(0.85, 0.46),
        Offset(0.77, 0.46),
      ],
    ),
    BodyRegion(
      regionId: 'right_wrist',
      regionName: 'Right Wrist',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.78, 0.46),
        Offset(0.86, 0.46),
        Offset(0.87, 0.48),
        Offset(0.79, 0.48),
      ],
    ),
    BodyRegion(
      regionId: 'right_hand',
      regionName: 'Right Hand',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.80, 0.48),
        Offset(0.88, 0.48),
        Offset(0.89, 0.53),
        Offset(0.81, 0.53),
      ],
    ),
    BodyRegion(
      regionId: 'right_fingers',
      regionName: 'Right Fingers',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.82, 0.53),
        Offset(0.90, 0.53),
        Offset(0.91, 0.57),
        Offset(0.83, 0.57),
      ],
    ),

    // ─── Left Leg (Back) ────────────────────────────────────
    BodyRegion(
      regionId: 'left_hip',
      regionName: 'Left Hip',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.35, 0.38),
        Offset(0.44, 0.38),
        Offset(0.44, 0.44),
        Offset(0.35, 0.44),
      ],
    ),
    BodyRegion(
      regionId: 'left_thigh',
      regionName: 'Left Thigh',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.36, 0.46),
        Offset(0.48, 0.46),
        Offset(0.47, 0.58),
        Offset(0.37, 0.58),
      ],
    ),
    BodyRegion(
      regionId: 'left_knee',
      regionName: 'Left Knee',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.37, 0.58),
        Offset(0.47, 0.58),
        Offset(0.47, 0.64),
        Offset(0.37, 0.64),
      ],
    ),
    BodyRegion(
      regionId: 'left_lower_leg',
      regionName: 'Left Lower Leg',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.38, 0.64),
        Offset(0.47, 0.64),
        Offset(0.46, 0.80),
        Offset(0.39, 0.80),
      ],
    ),
    BodyRegion(
      regionId: 'left_ankle',
      regionName: 'Left Ankle',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.39, 0.80),
        Offset(0.46, 0.80),
        Offset(0.46, 0.84),
        Offset(0.39, 0.84),
      ],
    ),
    BodyRegion(
      regionId: 'left_foot',
      regionName: 'Left Foot',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.37, 0.84),
        Offset(0.46, 0.84),
        Offset(0.47, 0.90),
        Offset(0.36, 0.90),
      ],
    ),
    BodyRegion(
      regionId: 'left_sole',
      regionName: 'Left Sole',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.37, 0.86),
        Offset(0.46, 0.86),
        Offset(0.47, 0.93),
        Offset(0.36, 0.93),
      ],
    ),

    // ─── Right Leg (Back) ───────────────────────────────────
    BodyRegion(
      regionId: 'right_hip',
      regionName: 'Right Hip',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.56, 0.38),
        Offset(0.65, 0.38),
        Offset(0.65, 0.44),
        Offset(0.56, 0.44),
      ],
    ),
    BodyRegion(
      regionId: 'right_thigh',
      regionName: 'Right Thigh',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.52, 0.46),
        Offset(0.64, 0.46),
        Offset(0.63, 0.58),
        Offset(0.53, 0.58),
      ],
    ),
    BodyRegion(
      regionId: 'right_knee',
      regionName: 'Right Knee',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.53, 0.58),
        Offset(0.63, 0.58),
        Offset(0.63, 0.64),
        Offset(0.53, 0.64),
      ],
    ),
    BodyRegion(
      regionId: 'right_lower_leg',
      regionName: 'Right Lower Leg',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.53, 0.64),
        Offset(0.62, 0.64),
        Offset(0.61, 0.80),
        Offset(0.54, 0.80),
      ],
    ),
    BodyRegion(
      regionId: 'right_ankle',
      regionName: 'Right Ankle',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.54, 0.80),
        Offset(0.61, 0.80),
        Offset(0.61, 0.84),
        Offset(0.54, 0.84),
      ],
    ),
    BodyRegion(
      regionId: 'right_foot',
      regionName: 'Right Foot',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.54, 0.84),
        Offset(0.63, 0.84),
        Offset(0.64, 0.90),
        Offset(0.53, 0.90),
      ],
    ),
    BodyRegion(
      regionId: 'right_sole',
      regionName: 'Right Sole',
      view: BodyView.back,
      polygonPoints: const [
        Offset(0.54, 0.86),
        Offset(0.63, 0.86),
        Offset(0.64, 0.93),
        Offset(0.53, 0.93),
      ],
    ),
  ];

  /// Returns regions for a given [BodyView].
  static List<BodyRegion> getRegionsForView(BodyView view) {
    return allRegions.where((r) => r.view == view).toList();
  }

  /// Returns a single region by ID and view.
  static BodyRegion? findRegion(String regionId, BodyView view) {
    try {
      return allRegions
          .firstWhere((r) => r.regionId == regionId && r.view == view);
    } catch (_) {
      return null;
    }
  }
}
