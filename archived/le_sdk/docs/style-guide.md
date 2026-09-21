# Lattice UI Style Guide

## Context

Lattice is a tactical C2 (command and control) application used on Android phones, tablets, and desktop browsers. Users operate in field conditions — often wearing gloves, in bright sunlight, on small screens, and under time pressure. Every UI decision must prioritize **usability over aesthetics**.

## Core Principles

### 1. Touch Targets

- **Minimum touch target: 48x48px** — all interactive elements (buttons, tiles, icons, tabs)
- Prefer 48px+ height for primary actions, 44px minimum for secondary
- Add generous padding around icons to extend hit area beyond the visual element
- Delete/close buttons need the same 48px treatment — small "x" icons must have large tap padding

### 2. Screen Sizes

- Must work on **5" phones** (narrow, ~360px logical width in portrait, ~640px in landscape)
- Must work on **8" tablets** (medium, ~800px logical width in landscape)
- Must work on **10"+ tablets and desktop browsers**
- The app forces landscape on mobile — design for landscape-first
- The settings drawer is 360px wide — this is nearly the full width of a 5" phone in landscape. Keep layouts compact.

### 3. Responsiveness

- Animations must be fast: 200-300ms for transitions, no more
- Use `ClampingScrollPhysics` — no bouncy overscroll (causes visual distortion on trackpads and feels sluggish)
- Wrap scrollable containers in `ClipRect` to prevent content bleeding during fast scrolls
- Loading states should appear instantly (no delay before showing indicator)

### 4. Glove Usability

- Buttons must be finger-pad sized, not fingertip sized
- No hover-only interactions — everything must work with tap
- Avoid swipe gestures as primary navigation (unreliable with gloves). Use visible tap targets instead.
- Text input fields need generous padding (14px+ vertical) for easy tap-to-focus

### 5. Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0A` | Panel/drawer background |
| Surface | `#111111` | Input fields, cards |
| Border | `#1E1E1E` | Subtle dividers |
| Border Active | `#2A2A2A` | Input borders, button outlines |
| Text Primary | `#FFFFFF` | Headings, active labels |
| Text Secondary | `#888888` | Descriptions, subtitles |
| Text Muted | `#555555` | Hints, disabled text |
| Accent | `#FF6B35` | Primary actions, active indicators, brand |
| Success | `#4CAF50` | Connected status |
| Error | `#FF4444` | Error states |

### 6. Typography

- Section labels: 10px, weight 600, `letterSpacing: 0.8`, uppercase, color `#999999`
- Body text: 13px, weight 400-500
- Titles: 18px, weight 600
- Button labels: 12-14px, weight 500-600
- Use system font for fastest render. Bundle Roboto as a fallback for offline/disconnected environments (the scaffold does this automatically).

### 7. Spacing

- Drawer padding: 12px horizontal, 10px vertical
- Between sections: 16px
- Between label and content: 8px
- Between stacked items (tiles, buttons): 6-8px
- Inside buttons: 48px height, center content

### 8. Component Patterns

**Buttons:**
- Primary (orange fill): `#FF6B35` background, white text, 48px height, 8px border-radius
- Secondary (outlined): `#111111` fill, `#2A2A2A` border, `#888888` text, 48px height
- Icon + label pattern for secondary actions

**Input Fields:**
- `#111111` fill, `#2A2A2A` border, 8px border-radius
- 14px vertical padding for easy gloved tap
- Orange border on focus (`#FF6B35`)
- Full width — never crowd with suffix actions (URLs are long)

**Endpoint Tiles:**
- 14px vertical padding, 12px horizontal
- Orange dot for selected state
- 6-8px margin between tiles
- Delete button with 48px hit area

**Tab Bar:**
- Icon-only tabs (no labels) to save vertical space
- 14px vertical padding per tab
- Orange underline for active tab
- Tooltip on hover for desktop users

**Loading States:**
- Full-screen black overlay with brand logo animation
- Subtle progress indicator
- Fade in/out (300ms)

## Anti-Patterns

- No tiny icon buttons without padding (< 44px hit area)
- No inline suffix icons in text fields for critical actions
- No bouncy scroll physics
- No hover-dependent UI
- No animations longer than 300ms for functional transitions
- No light-colored backgrounds (this is a dark-only app)
- No text smaller than 10px
