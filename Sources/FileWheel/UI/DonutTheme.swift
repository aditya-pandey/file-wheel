import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Space Black & Brushed Titanium Theme (Apple Pro / Linear / Raycast)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public enum DonutTheme {
    // ── Space Black & Machined Graphite Ring Body ──
    public static let obsidianDark      = Color(red: 0.039, green: 0.043, blue: 0.051) // #0A0B0D
    public static let ringBodyFill      = Color(red: 0.067, green: 0.073, blue: 0.088) // #111317
    public static let ringSliceHover    = Color(red: 0.105, green: 0.115, blue: 0.140) // #1B1D24
    public static let ringEdgeStroke    = Color(white: 1.0, opacity: 0.09)
    public static let dividerHairline   = Color(white: 1.0, opacity: 0.10)

    // ── Anodized Titanium Hub ──
    public static let hubCenterFill     = Color(red: 0.035, green: 0.038, blue: 0.046)
    public static let metallicHi        = Color(red: 0.62, green: 0.66, blue: 0.73)
    public static let metallicLo        = Color(red: 0.14, green: 0.16, blue: 0.19)
    public static let metallicMid       = Color(red: 0.32, green: 0.35, blue: 0.40)

    // ── Primary Luxury Accents (Platinum Ice & Warm Champagne) ──
    public static let platinumIce       = Color(red: 0.86, green: 0.90, blue: 0.96) // #DCE6F5
    public static let iconResting       = Color(red: 0.56, green: 0.59, blue: 0.65) // #8F96A6 Brushed Silver

    // ── Restrained Anodized Format Accents (Revealed Only on Active Hover) ──
    public static let webpCyan          = Color(red: 0.58, green: 0.76, blue: 0.94) // Glacier Ice #94C2F0
    public static let pngEmerald        = Color(red: 0.48, green: 0.76, blue: 0.65) // Anodized Sage #7AC2A6
    public static let jpgAmber          = Color(red: 0.84, green: 0.73, blue: 0.56) // Warm Champagne #D6BA8F
    public static let cutoutViolet      = Color(red: 0.72, green: 0.64, blue: 0.90) // Pearl Lavender #B8A3E6
    public static let pdfRuby           = Color(red: 0.82, green: 0.56, blue: 0.60) // Smoked Rose #D18F99
    public static let clipboardTeal     = Color(red: 0.56, green: 0.78, blue: 0.76) // Muted Seafoam #8FC7C2
    public static let audioPurple       = Color(red: 0.66, green: 0.60, blue: 0.86) // Titanium Violet #A899DB
    public static let gifOrange         = Color(red: 0.84, green: 0.66, blue: 0.52) // Brushed Copper #D6A885

    // ── Typography ──
    public static let textPrimary       = Color(red: 0.96, green: 0.97, blue: 0.99)
    public static let textMuted         = Color(red: 0.52, green: 0.55, blue: 0.62)

    // ── Atmosphere & Shadows ──
    public static let ambientGlowRadius: CGFloat = 32.0
    public static let outerShadow       = Color.black.opacity(0.85)
}
