---
name: Wasla Connection System
colors:
  surface: '#fbf9f5'
  surface-dim: '#dbdad6'
  surface-bright: '#fbf9f5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3ef'
  surface-container: '#efeeea'
  surface-container-high: '#eae8e4'
  surface-container-highest: '#e4e2de'
  on-surface: '#1b1c1a'
  on-surface-variant: '#3e494a'
  inverse-surface: '#30312e'
  inverse-on-surface: '#f2f0ed'
  outline: '#6e797a'
  outline-variant: '#bdc9ca'
  surface-tint: '#006972'
  primary: '#006068'
  on-primary: '#ffffff'
  primary-container: '#0d7a84'
  on-primary-container: '#d1faff'
  inverse-primary: '#7dd4df'
  secondary: '#865300'
  on-secondary: '#ffffff'
  secondary-container: '#fda627'
  on-secondary-container: '#694000'
  tertiary: '#395c61'
  on-tertiary: '#ffffff'
  tertiary-container: '#52747a'
  on-tertiary-container: '#d5f9ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#99f0fb'
  primary-fixed-dim: '#7dd4df'
  on-primary-fixed: '#001f23'
  on-primary-fixed-variant: '#004f56'
  secondary-fixed: '#ffddb8'
  secondary-fixed-dim: '#ffb961'
  on-secondary-fixed: '#2b1700'
  on-secondary-fixed-variant: '#653e00'
  tertiary-fixed: '#c4e9ef'
  tertiary-fixed-dim: '#a9cdd3'
  on-tertiary-fixed: '#001f24'
  on-tertiary-fixed-variant: '#294c51'
  background: '#fbf9f5'
  on-background: '#1b1c1a'
  surface-variant: '#e4e2de'
  success-green: '#16A34A'
  error-red: '#DC2626'
  surface-base: '#FFFFFF'
  border-medium: '#EAE4DA'
  text-primary: '#161210'
  text-muted: '#8A8278'
  auth-purple: '#5B21B6'
  geo-green: '#15803D'
  cars-blue: '#0369A1'
typography:
  display-lg:
    fontFamily: Cairo
    fontSize: 48px
    fontWeight: '900'
    lineHeight: 56px
  headline-lg:
    fontFamily: Cairo
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Cairo
    fontSize: 26px
    fontWeight: '800'
    lineHeight: 32px
  headline-md:
    fontFamily: Cairo
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Cairo
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Cairo
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 24px
  label-mono:
    fontFamily: IBM Plex Mono
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  micro-tag:
    fontFamily: Cairo
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  gutter: 16px
  margin-mobile: 20px
  touch-target: 48px
---

## Brand & Style
The design system for this Egyptian classifieds platform is built on the philosophy of "Wasla" (the connection). It bridges the gap between buyers and sellers through a UI that feels inherently local, trustworthy, and technologically modern. The brand personality is **Culturally Grounded yet Modern**, avoiding the sterile nature of international competitors by leaning into a warm, hospitable aesthetic inspired by Egyptian landscapes and heritage.

The chosen design style is **Corporate / Modern with Tactile Warmth**. It utilizes a clean, card-based layout with a "Flat-to-Subtle" approach to depth. While the structure is systematic and professional, the "Warm Sand" neutrals and "Egyptian Teal" accents provide a welcoming atmosphere. High-contrast typography and clear verification markers ensure the app feels like a safe, reliable marketplace for the local community.

Key brand attributes:
- **Trustworthy:** Heavy emphasis on verification badges and professional color-coding.
- **RTL-First:** Designed from the ground up for Arabic reading patterns.
- **Accessible:** Large touch targets and high-contrast labels for on-the-go mobile use.

## Colors
The palette is rooted in the "Egyptian Teal" (Primary) and "Egyptian Gold" (Secondary). Teal represents the professional, technological side of the platform, while Gold is used exclusively for the "Wasla" arc, trust badges, and featured listings to draw immediate attention.

**Usage Guidance:**
- **Primary Teal:** Use for primary actions, active navigation states, and brand-identifying surfaces.
- **Accent Gold:** Reserved for CTAs, "Verified" status indicators, and highlighting premium content.
- **Warm Sand (Neutral):** This is the foundation of the UI. Use `#F9F7F3` for page backgrounds to reduce eye strain compared to pure white.
- **Domain Colors:** Use the named colors (Purple, Blue, Green) to categorize different marketplace verticals (e.g., Real Estate vs. Motors) to help users orient themselves quickly.

## Typography
This system employs a dual-font strategy. **Cairo** is the workhorse for all Arabic and standard UI text, chosen for its modern geometry and excellent legibility in Arabic script. **IBM Plex Mono** is used selectively for numbers, prices, and technical metadata (like IDs or vehicle specifications) to provide a clear, "data-rich" contrast to the organic feel of Cairo.

**Implementation Notes:**
- **RTL Optimization:** Ensure `line-height` is generous for Cairo (minimum 1.6x for body) to prevent Arabic diacritics from clashing between lines.
- **Numbers:** Always use IBM Plex Mono for prices to ensure digits are distinct and easy to scan in a list view.
- **Hierarchy:** Use heavy weights (800-900) for headers to create a strong visual anchor on the page.

## Layout & Spacing
The design system uses a **Fluid Grid** model optimized for mobile-first classifieds. The spacing rhythm is based on a **4px baseline**, with most components utilizing 16px (md) gaps for clarity.

**Grid Specs:**
- **Mobile:** 4-column fluid grid with 16px gutters and 20px side margins.
- **Desktop:** 12-column fixed grid (max-width 1140px) with 24px gutters.
- **Touch Safety:** All interactive elements (communication buttons, filters) must adhere to a minimum touch target of `48px` height to accommodate varied user environments.

Content should reflow from a single-column list on mobile to a multi-column masonry or grid layout on larger screens, prioritizing the image gallery of the listing.

## Elevation & Depth
Elevation is primarily conveyed through **Tonal Layers** and **Low-Contrast Outlines** rather than heavy shadows, maintaining a clean and modern "app-like" feel.

- **Level 0 (Base):** Neutral Warm Sand (`#F9F7F3`) background.
- **Level 1 (Surface):** Cards and containers use White (`#FFFFFF`) with a 1px solid border in `#EAE4DA`.
- **Level 2 (Interactive):** On hover or focus, elements gain a subtle ambient shadow: `0 8px 20px rgba(13, 122, 132, 0.08)` (tinted with Primary Teal).
- **Sticky Elements:** The navigation header uses a **Glassmorphism** effect with a `16px` backdrop blur and 92% opacity of the neutral background to maintain context while scrolling.
- **The "Wasla" Arc:** Decorative connections between sections can use a subtle gradient (`145deg`) from Primary Teal to Deep Teal to imply structural depth.

## Shapes
The shape language is consistently **Rounded**, reflecting the "Arc" of the Wasla logo. Sharp corners are avoided to maintain an approachable and friendly character.

- **Cards:** Use `16px` (rounded-lg) for main ad cards and profile containers.
- **Buttons:** Use `10px` for standard interactive buttons.
- **Pills/Tags:** Use `20px` (full pill) for status badges (e.g., "Verified", "Active", "Sold") and category chips.
- **Inputs:** Use `12px` for search bars and text fields to balance the roundedness of cards and buttons.

## Components
Consistent styling across components reinforces the "Wasla" identity.

- **Buttons:**
    - *Primary:* Solid Teal (`#0D7A84`) with white text.
    - *Secondary (Featured):* Solid Gold (`#E89510`) with white text.
    - *Communication:* Large, high-visibility buttons for "Call" and "WhatsApp" with representative icons.
- **Verification Badges:** Use the Gold Accent color with a small checkmark icon and the "Wasla Arc" motif to signify a verified user or listing.
- **Ad Cards:**
    - Image-first layout.
    - Title in Cairo Bold.
    - Price in IBM Plex Mono.
    - Location tag with a subtle sand background (`n100`).
- **Input Fields:**
    - High contrast borders (`n200`) that shift to Primary Teal on focus.
    - Labels must be RTL aligned, using Cairo Medium.
- **Chips:**
    - Used for category filtering. Soft teal background (`p50`) for unselected, and Deep Teal (`p600`) for selected states.