# UnclutterPlus Design System & Redesign Specification (v2.0)

## 1. Design Philosophy: "Crystal & Canvas"

We are moving away from the standard "AppKit Gray" to a vibrant, depth-aware aesthetic inspired by macOS Sonoma/Sequoia.

**Core Principles:**
*   **Translucency (Crystal)**: Use `Material` (ultraThin, regular) to create depth and context. The sidebar and overlays should feel like frosted glass.
*   **Content First (Canvas)**: The main content area should be clean, high-contrast, and focused.
*   **Micro-Interactions**: Every click, hover, and drag must have a physical response (scale, color shift, haptic).
*   **Visual Hierarchy**: Use font weight and color opacity, not just size, to denote importance.

---

## 2. Color System (Semantic)

We will use a semantic naming convention to support theming easily.

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `bg.canvas` | `Color(nsColor: .windowBackgroundColor)` | `Color(nsColor: .windowBackgroundColor)` | Main app background |
| `bg.surface` | `Color.white` | `Color(white: 0.2)` | Cards, Modals |
| `bg.floating` | `Material.regular` | `Material.regular` | Toolbars, Popovers |
| `text.primary` | `Color.primary` | `Color.primary` | Headings, Main Data |
| `text.secondary` | `Color.secondary` | `Color.secondary` | Metadata, Subtitles |
| `accent.main` | `Color.blue` | `Color.blue` | Primary actions |
| `accent.soft` | `Color.blue.opacity(0.1)` | `Color.blue.opacity(0.2)` | Hover states, active backgrounds |

---

## 3. Typography & Spacing

**Font Stack**: System Rounded (`.design(.rounded)`) for headers to give a friendly, modern feel. Standard system font for density-heavy data (code, logs).

**Spacing Scale**:
*   `xs` (4px): Tight grouping
*   `sm` (8px): Component padding
*   `md` (16px): Card padding
*   `lg` (24px): Section separation
*   `xl` (32px): Major layout divisions

---

## 4. Layout Architecture

**Hybrid Sidebar (Vertical Navigation)**
*   **Width**: 68px (collapsed/icon-only) - keeping it slim to save menu bar "popup" real estate.
*   **Appearance**: Full height, `ultraThinMaterial` background.
*   **Interaction**: Icons glow/scale on hover. Active state has a "pill" indicator.

**Content Area**
*   **Header**: Minimal, fused with the window title bar (if possible) or a "floating" header.
*   **Body**: Scrollable area with proper padding.

---

## 5. Component Guidelines

**Cards (Files/Clipboard)**
*   Background: `Color.surface`
*   Border: `1px solid Color.white.opacity(0.1)` (inner glow)
*   Shadow: `radius: 8, y: 4, color: black.opacity(0.1)`
*   Hover: `scale(1.02)` + `shadow(radius: 12)`

**Buttons**
*   **Primary**: Gradient background, white text, subtle shadow.
*   **Secondary**: Bordered or Ghost style.
*   **Icon**: Symbol image with circular hover background.

**Motion**
*   **Hover**: `.spring(response: 0.3, damping: 0.7)`
*   **Page Transition**: `.opacity` + `.move(edge: .trailing)` (subtle 10px slide)
*   **Feedback**: Ripple effect on click.

---

## 6. Implementation Plan

1.  **Refactor `ModernDesignSystem`**: Implement the semantic tokens and modifiers.
2.  **Rebuild `ModernMainContentView`**: Implement the "Crystal Sidebar".
3.  **Update Features**: Apply the `cardStyle` and `glassBackground` modifiers to all lists.
