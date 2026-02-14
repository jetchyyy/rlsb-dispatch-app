/// Contains identifiers and display names for 50+ body regions.
class BodyRegionConstants {
  BodyRegionConstants._();

  // ─── Head (Front) ─────────────────────────────────────────
  static const String headFront = 'head_front';
  static const String forehead = 'forehead';
  static const String leftEye = 'left_eye';
  static const String rightEye = 'right_eye';
  static const String nose = 'nose';
  static const String mouthJaw = 'mouth_jaw';
  static const String leftEar = 'left_ear';
  static const String rightEar = 'right_ear';

  // ─── Head (Back) ──────────────────────────────────────────
  static const String headBack = 'head_back';

  // ─── Neck ─────────────────────────────────────────────────
  static const String neckFront = 'neck_front';
  static const String neckBack = 'neck_back';

  // ─── Torso (Front) ───────────────────────────────────────
  static const String chest = 'chest';
  static const String abdomen = 'abdomen';
  static const String leftRibcage = 'left_ribcage';
  static const String rightRibcage = 'right_ribcage';
  static const String sternum = 'sternum';
  static const String groin = 'groin';

  // ─── Torso (Back) ────────────────────────────────────────
  static const String upperBack = 'upper_back';
  static const String lowerBack = 'lower_back';

  // ─── Arms ─────────────────────────────────────────────────
  static const String leftShoulder = 'left_shoulder';
  static const String rightShoulder = 'right_shoulder';
  static const String leftUpperArm = 'left_upper_arm';
  static const String rightUpperArm = 'right_upper_arm';
  static const String leftElbow = 'left_elbow';
  static const String rightElbow = 'right_elbow';
  static const String leftForearm = 'left_forearm';
  static const String rightForearm = 'right_forearm';
  static const String leftWrist = 'left_wrist';
  static const String rightWrist = 'right_wrist';
  static const String leftHand = 'left_hand';
  static const String rightHand = 'right_hand';
  static const String leftFingers = 'left_fingers';
  static const String rightFingers = 'right_fingers';
  static const String leftPalm = 'left_palm';
  static const String rightPalm = 'right_palm';

  // ─── Legs ─────────────────────────────────────────────────
  static const String leftHip = 'left_hip';
  static const String rightHip = 'right_hip';
  static const String leftThigh = 'left_thigh';
  static const String rightThigh = 'right_thigh';
  static const String leftKnee = 'left_knee';
  static const String rightKnee = 'right_knee';
  static const String leftLowerLeg = 'left_lower_leg';
  static const String rightLowerLeg = 'right_lower_leg';
  static const String leftAnkle = 'left_ankle';
  static const String rightAnkle = 'right_ankle';
  static const String leftFoot = 'left_foot';
  static const String rightFoot = 'right_foot';
  static const String leftToes = 'left_toes';
  static const String rightToes = 'right_toes';
  static const String leftSole = 'left_sole';
  static const String rightSole = 'right_sole';

  // ─── Back-Specific ────────────────────────────────────────
  static const String leftShoulderBlade = 'left_shoulder_blade';
  static const String rightShoulderBlade = 'right_shoulder_blade';
  static const String spineUpper = 'spine_upper';
  static const String spineLower = 'spine_lower';
  static const String leftButtock = 'left_buttock';
  static const String rightButtock = 'right_buttock';

  /// Mapping from region ID to human-readable display name.
  static const Map<String, String> regionNames = {
    // Head
    headFront: 'Head (Front)',
    headBack: 'Head (Back)',
    forehead: 'Forehead',
    leftEye: 'Left Eye',
    rightEye: 'Right Eye',
    nose: 'Nose',
    mouthJaw: 'Mouth / Jaw',
    leftEar: 'Left Ear',
    rightEar: 'Right Ear',

    // Neck
    neckFront: 'Neck (Front)',
    neckBack: 'Neck (Back)',

    // Torso
    chest: 'Chest',
    abdomen: 'Abdomen',
    leftRibcage: 'Left Ribcage',
    rightRibcage: 'Right Ribcage',
    sternum: 'Sternum',
    groin: 'Groin',
    upperBack: 'Upper Back',
    lowerBack: 'Lower Back',

    // Arms
    leftShoulder: 'Left Shoulder',
    rightShoulder: 'Right Shoulder',
    leftUpperArm: 'Left Upper Arm',
    rightUpperArm: 'Right Upper Arm',
    leftElbow: 'Left Elbow',
    rightElbow: 'Right Elbow',
    leftForearm: 'Left Forearm',
    rightForearm: 'Right Forearm',
    leftWrist: 'Left Wrist',
    rightWrist: 'Right Wrist',
    leftHand: 'Left Hand',
    rightHand: 'Right Hand',
    leftFingers: 'Left Fingers',
    rightFingers: 'Right Fingers',
    leftPalm: 'Left Palm',
    rightPalm: 'Right Palm',

    // Legs
    leftHip: 'Left Hip',
    rightHip: 'Right Hip',
    leftThigh: 'Left Thigh',
    rightThigh: 'Right Thigh',
    leftKnee: 'Left Knee',
    rightKnee: 'Right Knee',
    leftLowerLeg: 'Left Lower Leg',
    rightLowerLeg: 'Right Lower Leg',
    leftAnkle: 'Left Ankle',
    rightAnkle: 'Right Ankle',
    leftFoot: 'Left Foot',
    rightFoot: 'Right Foot',
    leftToes: 'Left Toes',
    rightToes: 'Right Toes',
    leftSole: 'Left Sole',
    rightSole: 'Right Sole',

    // Back-specific
    leftShoulderBlade: 'Left Shoulder Blade',
    rightShoulderBlade: 'Right Shoulder Blade',
    spineUpper: 'Upper Spine',
    spineLower: 'Lower Spine',
    leftButtock: 'Left Buttock',
    rightButtock: 'Right Buttock',
  };

  /// Returns the display name for a given region ID.
  static String getRegionName(String regionId) {
    return regionNames[regionId] ?? regionId;
  }
}
