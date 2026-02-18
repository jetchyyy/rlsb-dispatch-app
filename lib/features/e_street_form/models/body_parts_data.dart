import 'body_part.dart';

/// Static data for all 42 body parts (21 front + 21 back).
///
/// Coordinates are defined in a 300×500 reference coordinate space.
class BodyPartsData {
  BodyPartsData._();

  // ─── FRONT VIEW (21 parts) ──────────────────────────────

  static const List<BodyPart> frontParts = [
    // Head
    BodyPart(
      key: 'head', label: 'Head', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 150, cy: 42, rx: 30, ry: 36,
    ),
    // Neck
    BodyPart(
      key: 'neck', label: 'Neck', shape: BodyPartShape.rect,
      view: BodyPartView.front,
      x: 138, y: 74, w: 24, h: 22,
    ),
    // Left Shoulder
    BodyPart(
      key: 'left_shoulder', label: 'Left Shoulder', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 107, cy: 105, rx: 22, ry: 14,
    ),
    // Right Shoulder
    BodyPart(
      key: 'right_shoulder', label: 'Right Shoulder', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 193, cy: 105, rx: 22, ry: 14,
    ),
    // Chest
    BodyPart(
      key: 'chest', label: 'Chest', shape: BodyPartShape.rect,
      view: BodyPartView.front,
      x: 117, y: 100, w: 66, h: 50, cornerRadius: 6,
    ),
    // Abdomen
    BodyPart(
      key: 'abdomen', label: 'Abdomen', shape: BodyPartShape.rect,
      view: BodyPartView.front,
      x: 120, y: 150, w: 60, h: 46, cornerRadius: 6,
    ),
    // Pelvis
    BodyPart(
      key: 'pelvis', label: 'Pelvis/Groin', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 150, cy: 210, rx: 32, ry: 18,
    ),
    // Left Upper Arm
    BodyPart(
      key: 'left_upper_arm', label: 'Left Upper Arm', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 76, y: 112, w: 22, h: 56, cornerRadius: 8, rotation: 8,
    ),
    // Right Upper Arm
    BodyPart(
      key: 'right_upper_arm', label: 'Right Upper Arm', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 202, y: 112, w: 22, h: 56, cornerRadius: 8, rotation: -8,
    ),
    // Left Forearm
    BodyPart(
      key: 'left_forearm', label: 'Left Forearm', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 70, y: 170, w: 20, h: 56, cornerRadius: 6, rotation: 12,
    ),
    // Right Forearm
    BodyPart(
      key: 'right_forearm', label: 'Right Forearm', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 210, y: 170, w: 20, h: 56, cornerRadius: 6, rotation: -12,
    ),
    // Left Hand
    BodyPart(
      key: 'left_hand', label: 'Left Hand', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 62, cy: 240, rx: 12, ry: 16,
    ),
    // Right Hand
    BodyPart(
      key: 'right_hand', label: 'Right Hand', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 238, cy: 240, rx: 12, ry: 16,
    ),
    // Left Upper Leg (Thigh)
    BodyPart(
      key: 'left_upper_leg', label: 'Left Upper Leg (Thigh)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 118, y: 228, w: 28, h: 76, cornerRadius: 8,
    ),
    // Right Upper Leg (Thigh)
    BodyPart(
      key: 'right_upper_leg', label: 'Right Upper Leg (Thigh)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 154, y: 228, w: 28, h: 76, cornerRadius: 8,
    ),
    // Left Knee
    BodyPart(
      key: 'left_knee', label: 'Left Knee', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 132, cy: 316, rx: 14, ry: 16,
    ),
    // Right Knee
    BodyPart(
      key: 'right_knee', label: 'Right Knee', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 168, cy: 316, rx: 14, ry: 16,
    ),
    // Left Lower Leg
    BodyPart(
      key: 'left_lower_leg', label: 'Left Lower Leg', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 118, y: 334, w: 26, h: 80, cornerRadius: 8,
    ),
    // Right Lower Leg
    BodyPart(
      key: 'right_lower_leg', label: 'Right Lower Leg', shape: BodyPartShape.roundedRect,
      view: BodyPartView.front,
      x: 156, y: 334, w: 26, h: 80, cornerRadius: 8,
    ),
    // Left Foot
    BodyPart(
      key: 'left_foot', label: 'Left Foot', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 130, cy: 428, rx: 16, ry: 20,
    ),
    // Right Foot
    BodyPart(
      key: 'right_foot', label: 'Right Foot', shape: BodyPartShape.ellipse,
      view: BodyPartView.front,
      cx: 170, cy: 428, rx: 16, ry: 20,
    ),
  ];

  // ─── BACK VIEW (21 parts) ───────────────────────────────

  static const List<BodyPart> backParts = [
    // Back of Head
    BodyPart(
      key: 'back_of_head', label: 'Back of Head', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 150, cy: 42, rx: 30, ry: 36,
    ),
    // Back Neck
    BodyPart(
      key: 'back_neck', label: 'Back of Neck', shape: BodyPartShape.rect,
      view: BodyPartView.back,
      x: 138, y: 74, w: 24, h: 22,
    ),
    // Left Shoulder Back
    BodyPart(
      key: 'left_shoulder_back', label: 'Left Shoulder (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 107, cy: 105, rx: 22, ry: 14,
    ),
    // Right Shoulder Back
    BodyPart(
      key: 'right_shoulder_back', label: 'Right Shoulder (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 193, cy: 105, rx: 22, ry: 14,
    ),
    // Upper Back
    BodyPart(
      key: 'upper_back', label: 'Upper Back', shape: BodyPartShape.rect,
      view: BodyPartView.back,
      x: 117, y: 100, w: 66, h: 50, cornerRadius: 6,
    ),
    // Lower Back
    BodyPart(
      key: 'lower_back', label: 'Lower Back', shape: BodyPartShape.rect,
      view: BodyPartView.back,
      x: 120, y: 150, w: 60, h: 46, cornerRadius: 6,
    ),
    // Buttocks
    BodyPart(
      key: 'buttocks', label: 'Buttocks/Sacral Area', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 150, cy: 210, rx: 32, ry: 18,
    ),
    // Left Upper Arm Back
    BodyPart(
      key: 'left_upper_arm_back', label: 'Left Upper Arm (Back)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 76, y: 112, w: 22, h: 56, cornerRadius: 8, rotation: 8,
    ),
    // Right Upper Arm Back
    BodyPart(
      key: 'right_upper_arm_back', label: 'Right Upper Arm (Back)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 202, y: 112, w: 22, h: 56, cornerRadius: 8, rotation: -8,
    ),
    // Left Forearm Back
    BodyPart(
      key: 'left_forearm_back', label: 'Left Forearm (Back)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 70, y: 170, w: 20, h: 56, cornerRadius: 6, rotation: 12,
    ),
    // Right Forearm Back
    BodyPart(
      key: 'right_forearm_back', label: 'Right Forearm (Back)', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 210, y: 170, w: 20, h: 56, cornerRadius: 6, rotation: -12,
    ),
    // Left Hand Back
    BodyPart(
      key: 'left_hand_back', label: 'Left Hand (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 62, cy: 240, rx: 12, ry: 16,
    ),
    // Right Hand Back
    BodyPart(
      key: 'right_hand_back', label: 'Right Hand (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 238, cy: 240, rx: 12, ry: 16,
    ),
    // Left Hamstring
    BodyPart(
      key: 'left_hamstring', label: 'Left Hamstring/Back Thigh', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 118, y: 228, w: 28, h: 76, cornerRadius: 8,
    ),
    // Right Hamstring
    BodyPart(
      key: 'right_hamstring', label: 'Right Hamstring/Back Thigh', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 154, y: 228, w: 28, h: 76, cornerRadius: 8,
    ),
    // Left Knee Back
    BodyPart(
      key: 'left_knee_back', label: 'Left Knee (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 132, cy: 316, rx: 14, ry: 16,
    ),
    // Right Knee Back
    BodyPart(
      key: 'right_knee_back', label: 'Right Knee (Back)', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 168, cy: 316, rx: 14, ry: 16,
    ),
    // Left Calf
    BodyPart(
      key: 'left_calf', label: 'Left Calf', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 118, y: 334, w: 26, h: 80, cornerRadius: 8,
    ),
    // Right Calf
    BodyPart(
      key: 'right_calf', label: 'Right Calf', shape: BodyPartShape.roundedRect,
      view: BodyPartView.back,
      x: 156, y: 334, w: 26, h: 80, cornerRadius: 8,
    ),
    // Left Heel
    BodyPart(
      key: 'left_heel', label: 'Left Heel/Ankle', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 130, cy: 428, rx: 16, ry: 20,
    ),
    // Right Heel
    BodyPart(
      key: 'right_heel', label: 'Right Heel/Ankle', shape: BodyPartShape.ellipse,
      view: BodyPartView.back,
      cx: 170, cy: 428, rx: 16, ry: 20,
    ),
  ];

  /// All 42 body parts.
  static List<BodyPart> get allParts => [...frontParts, ...backParts];

  /// Get parts for a specific view.
  static List<BodyPart> getPartsForView(BodyPartView view) {
    return view == BodyPartView.front ? frontParts : backParts;
  }

  /// Find a body part by its key.
  static BodyPart? findByKey(String key) {
    try {
      return allParts.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable labels for all body part keys.
  static const Map<String, String> bodyPartLabels = {
    // Front
    'head': 'Head',
    'neck': 'Neck',
    'chest': 'Chest',
    'left_shoulder': 'Left Shoulder',
    'right_shoulder': 'Right Shoulder',
    'abdomen': 'Abdomen',
    'pelvis': 'Pelvis/Groin',
    'left_upper_arm': 'Left Upper Arm',
    'right_upper_arm': 'Right Upper Arm',
    'left_forearm': 'Left Forearm',
    'right_forearm': 'Right Forearm',
    'left_hand': 'Left Hand',
    'right_hand': 'Right Hand',
    'left_upper_leg': 'Left Upper Leg (Thigh)',
    'right_upper_leg': 'Right Upper Leg (Thigh)',
    'left_knee': 'Left Knee',
    'right_knee': 'Right Knee',
    'left_lower_leg': 'Left Lower Leg',
    'right_lower_leg': 'Right Lower Leg',
    'left_foot': 'Left Foot',
    'right_foot': 'Right Foot',
    // Back
    'back_of_head': 'Back of Head',
    'back_neck': 'Back of Neck',
    'upper_back': 'Upper Back',
    'lower_back': 'Lower Back',
    'buttocks': 'Buttocks/Sacral Area',
    'left_shoulder_back': 'Left Shoulder (Back)',
    'right_shoulder_back': 'Right Shoulder (Back)',
    'left_upper_arm_back': 'Left Upper Arm (Back)',
    'right_upper_arm_back': 'Right Upper Arm (Back)',
    'left_forearm_back': 'Left Forearm (Back)',
    'right_forearm_back': 'Right Forearm (Back)',
    'left_hand_back': 'Left Hand (Back)',
    'right_hand_back': 'Right Hand (Back)',
    'left_hamstring': 'Left Hamstring/Back Thigh',
    'right_hamstring': 'Right Hamstring/Back Thigh',
    'left_knee_back': 'Left Knee (Back)',
    'right_knee_back': 'Right Knee (Back)',
    'left_calf': 'Left Calf',
    'right_calf': 'Right Calf',
    'left_heel': 'Left Heel/Ankle',
    'right_heel': 'Right Heel/Ankle',
  };
}
