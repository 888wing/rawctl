# rawctl Landing Page Design — Art Deco Style

## Overview

**Design Direction**: Art Deco (The "Gatsby" Aesthetic)
**Target Audience**: Open source/tech community + Lightroom migrators
**Core Value Proposition**: Local-first — Your photos never leave your machine
**Primary CTA**: Download macOS App
**Language**: English primary

---

## Design System Summary

### Colors
| Token | Value | Usage |
|-------|-------|-------|
| Background | `#0A0A0A` | Obsidian black |
| Foreground | `#F2F0E4` | Champagne cream text |
| Card BG | `#141414` | Rich charcoal |
| Primary Accent | `#D4AF37` | Metallic gold |
| Secondary | `#1E3D59` | Midnight blue |
| Muted | `#888888` | Pewter gray |

### Typography
- **Headings**: Marcellus (Google Font) — uppercase, `tracking-[0.2em]` or wider
- **Body**: Josefin Sans (Google Font) — geometric, vintage feel
- **Scale**: H1 `text-6xl`/`text-7xl`, Body `text-lg`

### Key Visual Elements
- Sharp corners (`rounded-none`)
- Gold borders (1-2px)
- Stepped corner decorations (L-shaped brackets)
- Rotated diamond containers (45°)
- Sunburst radial gradients
- Glow effects (not drop shadows)
- Roman numerals (I, II, III)
- Diagonal crosshatch background pattern (3-5% opacity)

---

## Section I: Hero

### Content

**Main Headline**
```
YOUR PHOTOS. YOUR MACHINE. YOUR FREEDOM.
```

**Subheadline**
```
A native macOS RAW editor that keeps everything local.
No subscriptions. No cloud. No compromise.
```

**CTAs**
- Primary: "DOWNLOAD FOR MAC"
- Secondary: "★ GITHUB"

### Layout
```
┌─────────────────────────────────────────────────────────────┐
│                    ◆ rawctl ◆                               │
│                                                             │
│     ─────────── ✦ ───────────                              │
│                                                             │
│         YOUR PHOTOS. YOUR MACHINE.                          │
│              YOUR FREEDOM.                                  │
│                                                             │
│     A native macOS RAW editor that keeps                    │
│     everything local. No subscriptions.                     │
│           No cloud. No compromise.                          │
│                                                             │
│     ┌─────────────────────┐   ┌─────────────────────┐      │
│     │   DOWNLOAD FOR MAC  │   │   ★ GITHUB          │      │
│     └─────────────────────┘   └─────────────────────┘      │
│                                                             │
│              ┌───────────────────────────┐                  │
│              │    ╔═══════════════════╗  │                  │
│              │    ║   App Screenshot  ║  │                  │
│              │    ╚═══════════════════╝  │                  │
│              └───────────────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Design Notes
- Logo in 45° rotated diamond frame
- Decorative gold lines above/below headline with center star `✦`
- App screenshot with double gold frame (outer 2px, inner 4px black inset)
- Screenshot: `grayscale(30%)` default, full color + glow on hover
- L-shaped corner decorations on screenshot frame
- Sunburst radial gradient emanating from center
- Diagonal crosshatch pattern overlay at 3% opacity

---

## Section II: Pain Points (Why Local-First)

### Content

**Headline**
```
WHY LOCAL-FIRST?
Your Photos Deserve Better
```

**Three Cards**

| # | Title | Subtitle | Description |
|---|-------|----------|-------------|
| I | NO CLOUD DEPENDENCY | Process Locally | Your files never leave your machine. Full GPU acceleration with Metal. Zero upload latency. Works offline. |
| II | NO SUBSCRIPTION RANSOM | Own Your Tools | Why rent software at $120/year? Core editing is free forever. Only pay for AI features when you need them. |
| III | NO LOCK-IN | Open Standards | Standard JSON sidecars store your edits. No proprietary catalogs. Export everything, anytime, anywhere. |

### Layout
```
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│ ┌─            ─┐  │  │ ┌─            ─┐  │  │ ┌─            ─┐  │
│    ◆ I ◆          │  │    ◆ II ◆         │  │    ◆ III ◆        │
│   NO CLOUD        │  │ NO SUBSCRIPTION   │  │  NO LOCK-IN       │
│   DEPENDENCY      │  │     RANSOM        │  │                   │
│                   │  │                   │  │                   │
│  [description]    │  │  [description]    │  │  [description]    │
│ └─            ─┘  │  │ └─            ─┘  │  │ └─            ─┘  │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

### Design Notes
- Cards: `#141414` background, gold border 30% → 100% on hover
- Roman numerals in gold diamond frame
- L-shaped corner decorations (top-left + bottom-right)
- Hover: `-translate-y-2` lift + glow effect
- Optional: line icons for each pain point (hard drive, coin with slash, unlock)

---

## Section III: Features (Professional Tools)

### Content

**Headline**
```
PROFESSIONAL TOOLS
Everything You Need, Nothing You Don't
```

**Six Feature Cards (2x3 Grid)**

| Icon | Title | Description |
|------|-------|-------------|
| ☀ | EXPOSURE | ±5 EV range with highlights, shadows, whites & blacks control. |
| ◐ | TONE CURVES | 5-point precision curve editor for cinematic color grading. |
| ◑ | WHITE BALANCE | Presets + Kelvin temperature (2000-12000K) + tint fine-tuning. |
| ★ | ORGANIZATION | Stars, flags, color labels, custom tags & smart filters. |
| ⚡ | PERFORMANCE | Metal GPU acceleration, smart caching, two-stage loading. |
| 📁 | RAW SUPPORT | ARW, CR2, CR3, NEF, ORF, RAF, RW2, DNG, 3FR, IIQ & more. |

### Layout
```
┌─────────────────────────┐    ┌─────────────────────────┐
│ ◇      ☀ EXPOSURE     ◇ │    │ ◇    ◐ TONE CURVES   ◇ │
│       [description]      │    │       [description]      │
└─────────────────────────┘    └─────────────────────────┘

┌─────────────────────────┐    ┌─────────────────────────┐
│ ◇   ◑ WHITE BALANCE   ◇ │    │ ◇    ★ ORGANIZATION  ◇ │
│       [description]      │    │       [description]      │
└─────────────────────────┘    └─────────────────────────┘

┌─────────────────────────┐    ┌─────────────────────────┐
│ ◇     ⚡ PERFORMANCE   ◇ │    │ ◇    📁 RAW SUPPORT   ◇ │
│       [description]      │    │       [description]      │
└─────────────────────────┘    └─────────────────────────┘
```

### Design Notes
- Four corner diamond decorations `◇` on each card
- Icons in 45° rotated diamond container, gold color
- Hover: icon container rotates from 45° → 0°, card glows
- Marcellus font for titles, uppercase, wide tracking
- Subtle radial gradient background from center

---

## Section IV: Comparison (vs Lightroom)

### Content

**Headline**
```
THE HONEST COMPARISON
See What You're Really Paying For
```

**Comparison Table**

| Feature | rawctl | Adobe Lightroom |
|---------|--------|-----------------|
| Price | FREE FOREVER ◆ | $9.99/month ($120/yr) |
| Data Storage | 100% Local ◆ | Cloud-dependent |
| Edit Format | JSON Sidecar (Open) ◆ | Proprietary Catalog (Locked) |
| Source Code | Open Source ◆ | Closed Source |
| Offline Mode | Full Support ◆ | Limited Features |
| AI Features | Pay-as-you-go (Optional) ◆ | Included (subscription required) |

**CTA**: "SWITCH TO FREEDOM →"

**Cost Calculator**
```
┌─────────────────────────────────────────┐
│  CALCULATE YOUR SAVINGS                 │
│                                         │
│  Years with Lightroom: [▼ 3 years ]    │
│                                         │
│  You've already paid:  $360            │
│  With rawctl:          $0              │
│  ─────────────────────────────         │
│  YOUR SAVINGS:         $360 ◆          │
└─────────────────────────────────────────┘
```

### Design Notes
- Table: double gold frame (outer 2px, inner 4px black inset)
- Row separators: gold 1px lines with small diamond ends
- rawctl column: gold text emphasis
- Lightroom column: muted gray `#888888`
- Gold diamond `◆` marks rawctl advantages
- Calculator: interactive dropdown, real-time calculation

---

## Section V: Open Source (Community)

### Content

**Headline**
```
BUILT IN THE OPEN
By Photographers, For Photographers
```

**GitHub Stats (Live API)**
- Stars: [dynamic]
- Forks: [dynamic]
- Contributors: [dynamic]

**Quote**
> "No corporate agenda. No investor pressure. Just a tool built by people who actually edit photos."
> — The rawctl Philosophy

**How to Contribute (3 Steps)**

| Step | Title | Description |
|------|-------|-------------|
| I. | FORK | Clone the repository |
| II. | CODE | Fix bugs or add features |
| III. | PR | Submit & get merged |

**CTAs**
- "★ STAR ON GITHUB"
- "◆ READ THE SOURCE"

### Layout
```
┌─────────┐      ┌─────────┐      ┌─────────┐
│  ◆ ★★★  │      │  ◆ ⑂⑂⑂  │      │  ◆ ◯◯◯  │
│   128   │      │   42    │      │   15    │
│  STARS  │      │  FORKS  │      │ CONTRIBS│
└─────────┘      └─────────┘      └─────────┘

┌─────────────────────────────────────────────┐
│ ◇                                         ◇ │
│  "No corporate agenda..."                   │
│                    — The rawctl Philosophy  │
│ ◇                                         ◇ │
└─────────────────────────────────────────────┘

┌───────────┐   ┌───────────┐   ┌───────────┐
│    I.     │ → │   II.     │ → │   III.    │
│   FORK    │   │   CODE    │   │    PR     │
└───────────┘   └───────────┘   └───────────┘
```

### Design Notes
- Stats in diamond containers with 45° rotation
- Quote block with four corner diamond decorations
- Contribution steps connected by gold arrows `→`
- Roman numerals for steps
- Gold horizontal line separating stats from contribution section

---

## Section VI: Pricing

### Content

**Headline**
```
SIMPLE PRICING
Free Forever. Pay Only for AI Magic.
```

**Two-Column Pricing Cards**

| Plan | Price | Features |
|------|-------|----------|
| **FREE** | $0 forever | Full RAW editing, All pro tools, Unlimited photos, JSON sidecar, Offline support, 5 AI images/mo |
| **PRO** ⭐ | $9.99/mo | Everything in Free, 200 standard AI/mo, 50 HD AI/mo, Priority queue, Early feature access, Support the project |

**Pay-as-you-go (Below Cards)**
```
─── OR PAY AS YOU GO ───

Need just a few AI generations? No problem.

◆ 1K Resolution ─────── $0.15 / image
◆ 2K Resolution ─────── $0.30 / image
◆ 4K Resolution ─────── $0.50 / image

No subscription. No commitment. Pay only what you use.
```

### Layout
```
        ┌───────────────────┐     ┌─────────────────────────┐
        │ ◇               ◇ │     │ ◇   RECOMMENDED       ◇ │
        │      ◆ I ◆       │     │      ◆ ◆ ◆ ◆           │
        │      FREE        │     │        PRO              │
        │                  │     │                         │
        │       $0         │     │       $9.99             │
        │     forever      │     │        /mo              │
        │                  │     │                         │
        │  ✓ Full RAW...   │     │  ✓ Everything in Free  │
        │  ✓ All tools...  │     │  ✓ 200 standard AI/mo  │
        │  ✓ ...           │     │  ✓ ...                 │
        │                  │     │                         │
        │  ┌────────────┐  │     │  ┌─────────────────┐   │
        │  │  DOWNLOAD  │  │     │  │    SUBSCRIBE    │   │
        │  └────────────┘  │     │  └─────────────────┘   │
        │ ◇               ◇ │     │ ◇                   ◇ │
        └───────────────────┘     └─────────────────────────┘

══════════════════════════════════════════════════════════════

                    ─── OR PAY AS YOU GO ───

        ┌────────────────────────────────────────────────┐
        │  ◆ 1K Resolution ─────── $0.15 / image        │
        │  ◆ 2K Resolution ─────── $0.30 / image        │
        │  ◆ 4K Resolution ─────── $0.50 / image        │
        └────────────────────────────────────────────────┘
```

### Design Notes
- PRO card: `scale-105`, 3px gold border, "RECOMMENDED" banner
- FREE card: standard size, 1px gold border
- PRO uses diamond array `◆ ◆ ◆ ◆` instead of Roman numeral
- Pay-as-you-go: horizontal section below, lighter styling
- Gold checkmarks `✓` for feature lists
- Price in large `text-5xl` Marcellus font

---

## Section VII: Final CTA

### Content

**Headline**: "READY TO OWN YOUR PHOTOS?"
**Subheadline**: "Join photographers who chose freedom over fees."
**CTA**: "◆ DOWNLOAD FOR MAC"
**Note**: "Requires macOS 14+"

### Layout
```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              ─────── ✦ ───────                               ║
║                                                               ║
║            READY TO OWN YOUR PHOTOS?                          ║
║                                                               ║
║      Join photographers who chose freedom over fees.          ║
║                                                               ║
║              ┌─────────────────────────┐                     ║
║              │   ◆ DOWNLOAD FOR MAC    │                     ║
║              └─────────────────────────┘                     ║
║                                                               ║
║                   Requires macOS 14+                          ║
║                                                               ║
║              ─────── ✦ ───────                               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Design Notes
- Double gold frame with `╔══╗` corners
- Sunburst radial gradient background inside frame
- Download button: gold filled background, black text
- Hover: intensified glow effect
- Centered layout with decorative star lines

---

## Section VIII: Footer

### Content

**Tagline**
```
◆ rawctl

Your photos. Your machine. Your freedom.

A native macOS RAW editor built for photographers who value ownership.
```

**Links**

| PRODUCT | COMMUNITY | LEGAL |
|---------|-----------|-------|
| Features | GitHub | Privacy |
| Pricing | Discussions | Terms |
| Changelog | Contributing | License (MIT) |
| Roadmap | Twitter/X | |

**Bottom**
- Tech: "Built with SwiftUI + Metal"
- Copyright: "© MMXXV rawctl. Open Source."

### Layout
```
═══════════════════════════════════════════════════════════════════

◆ rawctl

Your photos. Your machine.              PRODUCT         COMMUNITY
Your freedom.                           ────────        ──────────
                                        Features        GitHub
A native macOS RAW editor               Pricing         Discussions
built for photographers who             Changelog       Contributing
value ownership.                        Roadmap         Twitter/X

                                        LEGAL
                                        ──────
                                        Privacy
                                        Terms
                                        License (MIT)

───────────────────────────────────────────────────────────────────

◇ Built with SwiftUI + Metal ◇        © MMXXV rawctl. Open Source.

                    ─────── ✦ ───────
```

### Design Notes
- Three-column link layout
- Gold separators between sections
- Roman numeral year (MMXXV = 2025)
- Diamond decorations around tech stack text
- Final centered star divider at bottom

---

## Technical Implementation Notes

### Tech Stack
- **Framework**: React 18 + TypeScript + Vite
- **Styling**: Tailwind CSS
- **Animations**: Framer Motion
- **Fonts**: Google Fonts (Marcellus, Josefin Sans)
- **Icons**: Custom SVG / Lucide React

### Responsive Breakpoints
- **Desktop**: Full layout (lg: 1024px+)
- **Tablet**: 2-column grids → 1-column (md: 768px)
- **Mobile**: Stacked layout, reduced decorations (sm: 640px)

### Performance Considerations
- Lazy load app screenshot
- Preload fonts
- CSS-based decorations (pseudo-elements) over images
- Intersection Observer for scroll animations

### Accessibility
- Gold on black passes WCAG AA (~7:1 contrast)
- Focus states with gold ring
- Semantic HTML structure
- Skip-to-content link
- Decorative elements use `aria-hidden="true"`

---

## Summary

| Section | Purpose |
|---------|---------|
| I. Hero | First impression + primary CTA |
| II. Pain Points | Why local-first matters |
| III. Features | Professional capabilities |
| IV. Comparison | vs Lightroom decision helper |
| V. Open Source | Community trust building |
| VI. Pricing | Clear monetization model |
| VII. Final CTA | Conversion push |
| VIII. Footer | Navigation + trust signals |

**Design Theme**: Art Deco luxury meets open-source rebellion — sophisticated, bold, and unapologetically premium.
