---
name: Crisp iOS Cleanliness
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#424754'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#727785'
  outline-variant: '#c2c6d6'
  surface-tint: '#005ac2'
  primary: '#0058be'
  on-primary: '#ffffff'
  primary-container: '#2170e4'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#825100'
  on-tertiary: '#ffffff'
  tertiary-container: '#a36700'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.003em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system translates the precision, clarity, and motion language of Apple Human Interface Guidelines into an intimate, tactile utility experience. Built around the comforting physical ritual of fresh laundry, the system evokes the sensory calm of crisp cotton sheets, organized closets, and gentle steam. It elevates domestic routines into moments of micro-satisfaction.

The core visual style is **Tactile Minimalism infused with Glassmorphism**:
- Generous breathing room with layered translucent surfaces.
- Dynamic spring physics that mimic the squish and weight of folded fabric.
- Utilitarian precision balanced by soft, pill-shaped tactile affordances.
- Clear state-driven color accents inspired by natural fabric dyes and laundry wash cycles.

## Colors

The palette draws directly from the optical purity of clean water, detergent pods, and fabric care states. The default mode is light, echoing bright morning daylight through frosted bathroom glass.

- **Primary (`#3B82F6`)**: The signature laundry blue. Represents active wash cycles, laundry machine timers, and interactive focal points.
- **Secondary (`#10B981`)**: Fresh linen emerald. Signals restored order, cleanliness, and the "In Closet" pristine state.
- **Tertiary (`#F59E0B`)**: Warm hamper amber. Indicates accumulated garments awaiting attention and items currently in the hamper.
- **Alert Rose (`#EF4444`)**: Soft coral warning. Highlights missing socks, delicate cycle cautions, and stain flags.
- **Base Canvas (`#F8FAFC`)**: A gentle, cool porcelain backdrop that eliminates harsh screen glare while maintaining maximum contrast against frosted surfaces.
- **Surface Dark (`#0F172A`)**: Deep ink for typography and structural icons, never pure pitch black.

## Typography

The typographic hierarchy aligns with native iOS structural patterns, using Plus Jakarta Sans for its friendly curves and legibility at compact mobile scale. 

- **Display & Large Titles**: Heavy weights paired with tight tracking evoke the authoritative simplicity of native Apple system navigation bars.
- **Body & Secondary Content**: Generous line heights ensure instant readability when skimming garment tags, fabric weights, or washing temperatures.
- **Labels & Micro-data**: Slightly tracked uppercase and semi-bold figures preserve clarity across dense tabular batch data and dynamic countdown timers.

## Layout & Spacing

Layouts follow an iPhone-first, single-column fluid grid, moving into adaptive split-column multi-pane views on tablet viewports:

- **Outer Margins**: A constant `1.25rem` (20px) margin maintains safe-edge clearance against bezel perimeters.
- **Vertical Rhythm**: Content blocks cluster tightly using `space-xs` and `space-sm` for unified semantic units (such as an icon paired with its status pill), separated by `space-lg` to define distinct batch sections.
- **Safe Area Anchoring**: Critical interactive buttons, laundry batch start toggles, and multi-select action bars anchor floating over the bottom safe-area margin using frosted blur treatments.

## Elevation & Depth

Visual hierarchy relies on ambient diffusion and iOS-style backdrop blurs rather than sharp directional shadows:

- **Level 0 (Canvas Base)**: Matte, opaque `#F8FAFC`.
- **Level 1 (Card & Tag Base)**: Pure white `#FFFFFF` with an ambient glow (`box-shadow: 0 4px 20px -2px rgba(15, 23, 42, 0.04), 0 2px 6px -1px rgba(15, 23, 42, 0.02)`) bordered by an ultra-thin hairline stroke (`border: 1px solid rgba(15, 23, 42, 0.06)`).
- **Level 2 (Translucent Frosted Sheets)**: `rgba(255, 255, 255, 0.72)` paired with `backdrop-filter: blur(24px) saturate(180%)`. Used for floating bottom sheets, navigation headers, and modal overlays.
- **Tactile Depress**: On active touch/press states, elements scale smoothly to `0.97` with shadow contraction, simulating a physical membrane depress before springing back into place.

## Shapes

The shape hierarchy follows high-curvature geometry that mirrors smoothed water-worn river stones and soft folded textiles:

- **Pills & Badges (`rounded-full`)**: Applied universally to status chips, floating check-off toggles, and primary navigation tabs.
- **Item & Batch Cards (`rounded-3xl` / 1.5rem to 2rem)**: Continuous corner smoothing creates an organic silhouette that nests comfortably within the hand.
- **Embedded Inner Elements**: Nested controls maintain concentric harmony with parent cards, scaling down smoothly to avoid visual pinch points.

## Components

### Status Pills
- Form: Full capsule shape (`rounded-full`) with an internal horizontal layout (`px-3 py-1`).
- Surface: Tinted background at 12% opacity using the semantic state color, bordered by a matched 20% opacity hairline.
- States:
  - *In Closet*: Sage background (`#10B981` at 12%), emerald text, micro hanger icon.
  - *Dirty Hamper*: Amber background (`#F59E0B` at 12%), warm ochre text.
  - *In Wash*: Laundry blue background (`#3B82F6` at 12%), blue text, animated pulse indicator.
  - *Missing*: Rose background (`#EF4444` at 12%), coral text.

### Buttons & Interactive Affordances
- **Primary Action**: Pill-shaped capsule in solid `#3B82F6` with bold white typography, soft drop glow (`0 8px 16px -4px rgba(59, 130, 246, 0.3)`), and tactile scale feedback on press.
- **Secondary Action**: Translucent white fill (`rgba(255, 255, 255, 0.8)`), subtle outline, dark text.
- **Check-off Button**: Circular squircle checkbox with an elastic spring animation when checked, triggering a micro haptic pattern and gentle stroke fill.

### Garment & Batch Cards
- White surface, `rounded-3xl` padding (`1.25rem`), containing garment category icon, care symbols (wash cold, tumble low), and an interactive status chip.
- Swipe gestures reveal quick actions (e.g., swipe right to mark "In Hamper", swipe left to log "Clean").

### Input Fields
- Inset pill or soft container (`rounded-2xl`) with `#F1F5F9` neutral fill, zero exterior border in resting state, transitioning to a focused state via a subtle `#3B82F6` border highlight and faint ambient glow.