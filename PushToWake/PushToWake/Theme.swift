import SwiftUI

// Centralized color palette — "Deep Focus" theme.
// Every screen pulls from here instead of hardcoding colors, so changing
// the app's look later means editing one file instead of hunting through
// every view.
enum Theme {
    // Backgrounds
    static let background = Color(red: 0x12/255, green: 0x14/255, blue: 0x17/255)      // #121417 — charcoal base
    static let surface = Color(red: 0x1B/255, green: 0x1F/255, blue: 0x26/255)         // #1B1F26 — cards, rows
    static let surfaceElevated = Color(red: 0x22/255, green: 0x27/255, blue: 0x30/255) // #222730 — raised elements

    // Accent — electric blue
    static let accent = Color(red: 0x37/255, green: 0x8A/255, blue: 0xDD/255)          // #378ADD
    static let accentDim = accent.opacity(0.15)

    // Status
    static let success = Color(red: 0x63/255, green: 0x99/255, blue: 0x22/255)         // green — goal reached
    static let danger = Color(red: 0xE2/255, green: 0x4B/255, blue: 0x4A/255)          // red — rarely used

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.3)

    // Borders / separators
    static let separator = Color.white.opacity(0.08)
}
