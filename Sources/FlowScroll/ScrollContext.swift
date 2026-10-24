import CoreGraphics

/// The wheel origin selects the display clock. Output coordinates must be
/// evaluated independently for each frame as the pointer may have moved.
struct ScrollContext {
    static let marker: Int64 = 0x464C4F575343
    static let postingTap: CGEventTapLocation = .cgSessionEventTap
    var origin: CGPoint
    var flags: CGEventFlags

    func makeFrame(y: Int32, x: Int32, currentLocation: CGPoint?) -> CGEvent? {
        guard let currentLocation,
              let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                  wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) else { return nil }
        event.location = currentLocation
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        return event
    }
}
