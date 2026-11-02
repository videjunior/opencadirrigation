/// The pilot of a hydraulic valve (1.6.0 MOT+): a zone valve or a mainline
/// valve that, besides opening and closing, reduces the pressure after it,
/// sustains the pressure before it, or both.
library;

/// What the pilot of a valve holds: nothing ([none], a plain valve), the
/// pressure after it ([reducing], a pressure reducing pilot), the pressure
/// before it ([sustaining], a pressure sustaining pilot: the valve throttles
/// rather than let the line upstream fall below its setting) or both.
enum ValvePilot {
  none,
  reducing,
  sustaining,
  reducingSustaining;

  /// Whether the pilot holds the pressure after the valve.
  bool get reduces => this == reducing || this == reducingSustaining;

  /// Whether the pilot keeps the pressure before the valve up.
  bool get sustains => this == sustaining || this == reducingSustaining;
}
