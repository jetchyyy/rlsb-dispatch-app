import 'body_part.dart';

/// All 42 tappable body parts (21 front + 21 back) in a 300×500 coordinate space.
class BodyPartsData {
  BodyPartsData._();

  // ═══════════════════════════════════════════════════════════
  //  FRONT VIEW — 21 parts
  // ═══════════════════════════════════════════════════════════
  static const List<BodyPart> frontParts = [
    BodyPart(key: 'head', label: 'Head', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 150, cy: 50, rx: 35, ry: 40),
    BodyPart(key: 'neck', label: 'Neck', shape: BodyPartShape.rect, view: BodyPartView.front,
      x: 135, y: 85, w: 30, h: 20),
    BodyPart(key: 'left_shoulder', label: 'Left Shoulder', shape: BodyPartShape.circle, view: BodyPartView.front,
      cx: 106, cy: 95, r: 20),
    BodyPart(key: 'right_shoulder', label: 'Right Shoulder', shape: BodyPartShape.circle, view: BodyPartView.front,
      cx: 194, cy: 95, r: 20),
    BodyPart(key: 'chest', label: 'Chest', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 150, cy: 140, rx: 50, ry: 35),
    BodyPart(key: 'abdomen', label: 'Abdomen', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 150, cy: 200, rx: 45, ry: 30),
    BodyPart(key: 'pelvis', label: 'Pelvis/Groin', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 120, y: 225, w: 60, h: 25, cornerRadius: 5),
    BodyPart(key: 'left_upper_arm', label: 'Left Upper Arm', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 70, y: 110, w: 25, h: 60, cornerRadius: 12, rotation: 8),
    BodyPart(key: 'right_upper_arm', label: 'Right Upper Arm', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 205, y: 110, w: 25, h: 60, cornerRadius: 12, rotation: -8),
    BodyPart(key: 'left_forearm', label: 'Left Forearm', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 60, y: 175, w: 22, h: 60, cornerRadius: 11, rotation: 6),
    BodyPart(key: 'right_forearm', label: 'Right Forearm', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 218, y: 175, w: 22, h: 60, cornerRadius: 11, rotation: -6),
    BodyPart(key: 'left_hand', label: 'Left Hand', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 60, cy: 248, rx: 12, ry: 15),
    BodyPart(key: 'right_hand', label: 'Right Hand', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 240, cy: 248, rx: 12, ry: 15),
    BodyPart(key: 'left_upper_leg', label: 'Left Thigh', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 115, y: 250, w: 28, h: 80, cornerRadius: 12),
    BodyPart(key: 'right_upper_leg', label: 'Right Thigh', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 157, y: 250, w: 28, h: 80, cornerRadius: 12),
    BodyPart(key: 'left_knee', label: 'Left Knee', shape: BodyPartShape.circle, view: BodyPartView.front,
      cx: 129, cy: 342, r: 14),
    BodyPart(key: 'right_knee', label: 'Right Knee', shape: BodyPartShape.circle, view: BodyPartView.front,
      cx: 171, cy: 342, r: 14),
    BodyPart(key: 'left_lower_leg', label: 'Left Lower Leg', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 118, y: 357, w: 22, h: 70, cornerRadius: 10),
    BodyPart(key: 'right_lower_leg', label: 'Right Lower Leg', shape: BodyPartShape.roundedRect, view: BodyPartView.front,
      x: 160, y: 357, w: 22, h: 70, cornerRadius: 10),
    BodyPart(key: 'left_foot', label: 'Left Foot', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 129, cy: 440, rx: 16, ry: 12),
    BodyPart(key: 'right_foot', label: 'Right Foot', shape: BodyPartShape.ellipse, view: BodyPartView.front,
      cx: 171, cy: 440, rx: 16, ry: 12),
  ];

  // ═══════════════════════════════════════════════════════════
  //  BACK VIEW — 21 parts
  // ═══════════════════════════════════════════════════════════
  static const List<BodyPart> backParts = [
    BodyPart(key: 'back_of_head', label: 'Back of Head', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 150, cy: 50, rx: 35, ry: 40),
    BodyPart(key: 'back_neck', label: 'Back of Neck', shape: BodyPartShape.rect, view: BodyPartView.back,
      x: 135, y: 85, w: 30, h: 20),
    BodyPart(key: 'left_shoulder_back', label: 'Left Shoulder (Back)', shape: BodyPartShape.circle, view: BodyPartView.back,
      cx: 106, cy: 95, r: 20),
    BodyPart(key: 'right_shoulder_back', label: 'Right Shoulder (Back)', shape: BodyPartShape.circle, view: BodyPartView.back,
      cx: 194, cy: 95, r: 20),
    BodyPart(key: 'upper_back', label: 'Upper Back', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 150, cy: 140, rx: 50, ry: 35),
    BodyPart(key: 'lower_back', label: 'Lower Back', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 150, cy: 200, rx: 45, ry: 30),
    BodyPart(key: 'buttocks', label: 'Buttocks/Sacral Area', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 120, y: 225, w: 60, h: 25, cornerRadius: 5),
    BodyPart(key: 'left_upper_arm_back', label: 'Left Upper Arm (Back)', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 70, y: 110, w: 25, h: 60, cornerRadius: 12, rotation: 8),
    BodyPart(key: 'right_upper_arm_back', label: 'Right Upper Arm (Back)', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 205, y: 110, w: 25, h: 60, cornerRadius: 12, rotation: -8),
    BodyPart(key: 'left_forearm_back', label: 'Left Forearm (Back)', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 60, y: 175, w: 22, h: 60, cornerRadius: 11, rotation: 6),
    BodyPart(key: 'right_forearm_back', label: 'Right Forearm (Back)', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 218, y: 175, w: 22, h: 60, cornerRadius: 11, rotation: -6),
    BodyPart(key: 'left_hand_back', label: 'Left Hand (Back)', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 60, cy: 248, rx: 12, ry: 15),
    BodyPart(key: 'right_hand_back', label: 'Right Hand (Back)', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 240, cy: 248, rx: 12, ry: 15),
    BodyPart(key: 'left_hamstring', label: 'Left Hamstring', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 115, y: 250, w: 28, h: 80, cornerRadius: 12),
    BodyPart(key: 'right_hamstring', label: 'Right Hamstring', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 157, y: 250, w: 28, h: 80, cornerRadius: 12),
    BodyPart(key: 'left_knee_back', label: 'Left Knee (Back)', shape: BodyPartShape.circle, view: BodyPartView.back,
      cx: 129, cy: 342, r: 12),
    BodyPart(key: 'right_knee_back', label: 'Right Knee (Back)', shape: BodyPartShape.circle, view: BodyPartView.back,
      cx: 171, cy: 342, r: 12),
    BodyPart(key: 'left_calf', label: 'Left Calf', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 118, y: 357, w: 22, h: 70, cornerRadius: 10),
    BodyPart(key: 'right_calf', label: 'Right Calf', shape: BodyPartShape.roundedRect, view: BodyPartView.back,
      x: 160, y: 357, w: 22, h: 70, cornerRadius: 10),
    BodyPart(key: 'left_heel', label: 'Left Heel/Ankle', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 129, cy: 440, rx: 16, ry: 12),
    BodyPart(key: 'right_heel', label: 'Right Heel/Ankle', shape: BodyPartShape.ellipse, view: BodyPartView.back,
      cx: 171, cy: 440, rx: 16, ry: 12),
  ];

  static List<BodyPart> getPartsForView(BodyPartView view) {
    return view == BodyPartView.front ? frontParts : backParts;
  }

  static List<BodyPart> get allParts => [...frontParts, ...backParts];

  static BodyPart? findByKey(String key) {
    try {
      return allParts.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }
}
