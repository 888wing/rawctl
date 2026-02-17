# rawctl Landing Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an Art Deco styled landing page for rawctl that deploys to Cloudflare Pages.

**Architecture:** React 18 + TypeScript + Vite + Tailwind CSS. Single-page application with 8 sections. Static site optimized for Cloudflare Pages deployment. Component-based structure with shared design tokens.

**Tech Stack:** React 18, TypeScript, Vite, Tailwind CSS, Framer Motion, Lucide React

---

## Task 1: Project Setup

**Files:**
- Create: `landing/package.json`
- Create: `landing/tsconfig.json`
- Create: `landing/vite.config.ts`
- Create: `landing/tailwind.config.ts`
- Create: `landing/postcss.config.js`
- Create: `landing/index.html`

**Step 1: Initialize project structure**

```bash
cd /Users/chuisiufai/Projects/rawctl
mkdir -p landing/src
```

**Step 2: Create package.json**

```json
{
  "name": "rawctl-landing",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "framer-motion": "^11.15.0",
    "lucide-react": "^0.468.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@vitejs/plugin-react": "^4.3.4",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.17",
    "typescript": "^5.6.3",
    "vite": "^6.0.5"
  }
}
```

**Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

**Step 4: Create vite.config.ts**

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
})
```

**Step 5: Create tailwind.config.ts**

```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        background: '#0A0A0A',
        foreground: '#F2F0E4',
        card: '#141414',
        gold: {
          DEFAULT: '#D4AF37',
          light: '#F2E8C4',
          dark: '#B8962E',
        },
        midnight: '#1E3D59',
        muted: '#888888',
      },
      fontFamily: {
        display: ['Marcellus', 'serif'],
        body: ['Josefin Sans', 'sans-serif'],
      },
      letterSpacing: {
        'art-deco': '0.2em',
        'art-deco-wide': '0.3em',
      },
      boxShadow: {
        'gold-glow': '0 0 15px rgba(212, 175, 55, 0.2)',
        'gold-glow-lg': '0 0 30px rgba(212, 175, 55, 0.3)',
        'gold-glow-xl': '0 0 40px rgba(212, 175, 55, 0.4)',
      },
    },
  },
  plugins: [],
}

export default config
```

**Step 6: Create postcss.config.js**

```javascript
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

**Step 7: Create index.html**

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="rawctl - A native macOS RAW editor. Your photos, your machine, your freedom. No subscriptions, no cloud, no compromise." />
    <title>rawctl — Your Photos. Your Machine. Your Freedom.</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Josefin+Sans:wght@300;400;500;600&family=Marcellus&display=swap" rel="stylesheet">
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**Step 8: Install dependencies**

```bash
cd landing && npm install
```

**Step 9: Commit**

```bash
git add landing/
git commit -m "chore: initialize landing page project with Vite + Tailwind"
```

---

## Task 2: Base Styles & Design Tokens

**Files:**
- Create: `landing/src/main.tsx`
- Create: `landing/src/App.tsx`
- Create: `landing/src/index.css`
- Create: `landing/src/styles/art-deco.css`

**Step 1: Create index.css with base styles**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-background text-foreground font-body antialiased;
  }

  h1, h2, h3, h4, h5, h6 {
    @apply font-display uppercase tracking-art-deco;
  }
}

@layer components {
  .btn-primary {
    @apply px-8 py-4 border-2 border-gold text-gold font-display uppercase tracking-art-deco-wide
           transition-all duration-300 hover:bg-gold hover:text-background hover:shadow-gold-glow-lg;
  }

  .btn-solid {
    @apply px-8 py-4 bg-gold text-background font-display uppercase tracking-art-deco-wide
           transition-all duration-300 hover:bg-gold-light hover:shadow-gold-glow-lg;
  }

  .card-deco {
    @apply bg-card border border-gold/30 relative
           transition-all duration-500 hover:border-gold hover:-translate-y-2 hover:shadow-gold-glow;
  }

  .section-title {
    @apply text-4xl md:text-5xl lg:text-6xl text-gold font-display uppercase tracking-art-deco-wide text-center;
  }

  .section-subtitle {
    @apply text-lg md:text-xl text-foreground/80 text-center mt-4;
  }
}
```

**Step 2: Create art-deco.css for decorative patterns**

```css
/* Diagonal crosshatch background pattern */
.bg-crosshatch {
  background-image:
    repeating-linear-gradient(
      45deg,
      transparent,
      transparent 10px,
      rgba(212, 175, 55, 0.03) 10px,
      rgba(212, 175, 55, 0.03) 11px
    ),
    repeating-linear-gradient(
      -45deg,
      transparent,
      transparent 10px,
      rgba(212, 175, 55, 0.03) 10px,
      rgba(212, 175, 55, 0.03) 11px
    );
}

/* Sunburst radial gradient */
.bg-sunburst {
  background: radial-gradient(
    ellipse at center,
    rgba(212, 175, 55, 0.15) 0%,
    rgba(212, 175, 55, 0.05) 30%,
    transparent 70%
  );
}

/* Corner decorations */
.corner-deco::before,
.corner-deco::after {
  content: '';
  position: absolute;
  width: 20px;
  height: 20px;
  border-color: #D4AF37;
  opacity: 0.5;
  transition: opacity 0.3s ease;
}

.corner-deco::before {
  top: 8px;
  left: 8px;
  border-top: 2px solid;
  border-left: 2px solid;
}

.corner-deco::after {
  bottom: 8px;
  right: 8px;
  border-bottom: 2px solid;
  border-right: 2px solid;
}

.corner-deco:hover::before,
.corner-deco:hover::after {
  opacity: 1;
}

/* Diamond container */
.diamond {
  transform: rotate(45deg);
}

.diamond-content {
  transform: rotate(-45deg);
}

/* Gold divider line */
.divider-gold {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
}

.divider-gold::before,
.divider-gold::after {
  content: '';
  height: 1px;
  width: 60px;
  background: linear-gradient(90deg, transparent, #D4AF37, transparent);
}
```

**Step 3: Create main.tsx**

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'
import './styles/art-deco.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

**Step 4: Create App.tsx placeholder**

```tsx
export default function App() {
  return (
    <div className="min-h-screen bg-background bg-crosshatch">
      <main>
        <h1 className="text-6xl text-gold font-display text-center py-20 tracking-art-deco-wide">
          rawctl
        </h1>
        <p className="text-foreground text-center">Landing page coming soon...</p>
      </main>
    </div>
  )
}
```

**Step 5: Test dev server**

```bash
cd landing && npm run dev
```

Expected: Server runs on localhost:5173, shows "rawctl" heading with gold text on black background

**Step 6: Commit**

```bash
git add landing/src/
git commit -m "feat: add base styles and Art Deco design tokens"
```

---

## Task 3: Shared Components

**Files:**
- Create: `landing/src/components/Button.tsx`
- Create: `landing/src/components/Card.tsx`
- Create: `landing/src/components/SectionHeader.tsx`
- Create: `landing/src/components/Divider.tsx`
- Create: `landing/src/components/DiamondIcon.tsx`

**Step 1: Create Button component**

```tsx
// landing/src/components/Button.tsx
import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface ButtonProps {
  children: ReactNode
  variant?: 'primary' | 'solid' | 'outline'
  href?: string
  onClick?: () => void
  className?: string
}

export function Button({
  children,
  variant = 'primary',
  href,
  onClick,
  className = ''
}: ButtonProps) {
  const baseStyles = 'inline-flex items-center justify-center gap-2 font-display uppercase tracking-art-deco-wide transition-all duration-300'

  const variants = {
    primary: 'px-8 py-4 border-2 border-gold text-gold hover:bg-gold hover:text-background hover:shadow-gold-glow-lg',
    solid: 'px-8 py-4 bg-gold text-background hover:bg-gold-light hover:shadow-gold-glow-lg',
    outline: 'px-6 py-3 border border-gold/50 text-gold/80 hover:border-gold hover:text-gold',
  }

  const Component = href ? motion.a : motion.button

  return (
    <Component
      href={href}
      onClick={onClick}
      className={`${baseStyles} ${variants[variant]} ${className}`}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
    >
      {children}
    </Component>
  )
}
```

**Step 2: Create Card component**

```tsx
// landing/src/components/Card.tsx
import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface CardProps {
  children: ReactNode
  className?: string
  hover?: boolean
}

export function Card({ children, className = '', hover = true }: CardProps) {
  return (
    <motion.div
      className={`
        bg-card border border-gold/30 relative p-8
        corner-deco
        ${hover ? 'transition-all duration-500 hover:border-gold hover:-translate-y-2 hover:shadow-gold-glow' : ''}
        ${className}
      `}
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5 }}
    >
      {children}
    </motion.div>
  )
}
```

**Step 3: Create SectionHeader component**

```tsx
// landing/src/components/SectionHeader.tsx
import { motion } from 'framer-motion'

interface SectionHeaderProps {
  title: string
  subtitle?: string
}

export function SectionHeader({ title, subtitle }: SectionHeaderProps) {
  return (
    <motion.div
      className="text-center mb-16"
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6 }}
    >
      <div className="divider-gold mb-6">
        <span className="text-gold text-2xl">✦</span>
      </div>
      <h2 className="section-title">{title}</h2>
      {subtitle && <p className="section-subtitle">{subtitle}</p>}
    </motion.div>
  )
}
```

**Step 4: Create Divider component**

```tsx
// landing/src/components/Divider.tsx
export function Divider({ className = '' }: { className?: string }) {
  return (
    <div className={`divider-gold py-8 ${className}`}>
      <span className="text-gold text-xl">✦</span>
    </div>
  )
}
```

**Step 5: Create DiamondIcon component**

```tsx
// landing/src/components/DiamondIcon.tsx
import { ReactNode } from 'react'
import { motion } from 'framer-motion'

interface DiamondIconProps {
  children: ReactNode
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

export function DiamondIcon({ children, size = 'md', className = '' }: DiamondIconProps) {
  const sizes = {
    sm: 'w-10 h-10',
    md: 'w-14 h-14',
    lg: 'w-20 h-20',
  }

  return (
    <motion.div
      className={`
        ${sizes[size]} border-2 border-gold flex items-center justify-center
        diamond ${className}
      `}
      whileHover={{ rotate: 0 }}
      initial={{ rotate: 45 }}
    >
      <div className="diamond-content text-gold">
        {children}
      </div>
    </motion.div>
  )
}
```

**Step 6: Create index export**

```tsx
// landing/src/components/index.ts
export { Button } from './Button'
export { Card } from './Card'
export { SectionHeader } from './SectionHeader'
export { Divider } from './Divider'
export { DiamondIcon } from './DiamondIcon'
```

**Step 7: Commit**

```bash
git add landing/src/components/
git commit -m "feat: add shared Art Deco UI components"
```

---

## Task 4: Hero Section

**Files:**
- Create: `landing/src/sections/Hero.tsx`
- Create: `landing/public/screenshot.png` (copy from project)
- Create: `landing/public/favicon.svg`

**Step 1: Copy app screenshot**

```bash
cp "/Users/chuisiufai/Projects/rawctl/image copy.png" /Users/chuisiufai/Projects/rawctl/landing/public/screenshot.png
```

**Step 2: Create favicon.svg**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" fill="#0A0A0A"/>
  <path d="M50 10 L90 50 L50 90 L10 50 Z" fill="none" stroke="#D4AF37" stroke-width="4"/>
  <text x="50" y="58" text-anchor="middle" fill="#D4AF37" font-family="serif" font-size="24" font-weight="bold">r</text>
</svg>
```

**Step 3: Create Hero section**

```tsx
// landing/src/sections/Hero.tsx
import { motion } from 'framer-motion'
import { Github, Download } from 'lucide-react'
import { Button } from '@/components'

export function Hero() {
  return (
    <section className="min-h-screen flex flex-col items-center justify-center px-6 py-20 bg-sunburst relative overflow-hidden">
      {/* Logo */}
      <motion.div
        className="mb-8"
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.8 }}
      >
        <div className="w-16 h-16 border-2 border-gold diamond flex items-center justify-center">
          <span className="diamond-content text-gold font-display text-2xl">r</span>
        </div>
      </motion.div>

      {/* Brand name */}
      <motion.h1
        className="text-2xl text-gold font-display tracking-art-deco-wide mb-12"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3, duration: 0.6 }}
      >
        rawctl
      </motion.h1>

      {/* Divider */}
      <motion.div
        className="divider-gold mb-12"
        initial={{ opacity: 0, scaleX: 0 }}
        animate={{ opacity: 1, scaleX: 1 }}
        transition={{ delay: 0.5, duration: 0.6 }}
      >
        <span className="text-gold text-2xl">✦</span>
      </motion.div>

      {/* Main headline */}
      <motion.h2
        className="text-4xl md:text-5xl lg:text-7xl font-display text-foreground text-center tracking-art-deco-wide leading-tight mb-8"
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.7, duration: 0.8 }}
      >
        YOUR PHOTOS. YOUR MACHINE.
        <br />
        <span className="text-gold">YOUR FREEDOM.</span>
      </motion.h2>

      {/* Subheadline */}
      <motion.p
        className="text-lg md:text-xl text-foreground/70 text-center max-w-2xl mb-12 font-body"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1, duration: 0.6 }}
      >
        A native macOS RAW editor that keeps everything local.
        <br />
        No subscriptions. No cloud. No compromise.
      </motion.p>

      {/* CTAs */}
      <motion.div
        className="flex flex-col sm:flex-row gap-4 mb-20"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 1.2, duration: 0.6 }}
      >
        <Button variant="solid" href="#download">
          <Download className="w-5 h-5" />
          Download for Mac
        </Button>
        <Button variant="primary" href="https://github.com/user/rawctl" target="_blank">
          <Github className="w-5 h-5" />
          GitHub
        </Button>
      </motion.div>

      {/* App screenshot */}
      <motion.div
        className="relative max-w-5xl w-full"
        initial={{ opacity: 0, y: 40 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 1.4, duration: 0.8 }}
      >
        {/* Double frame */}
        <div className="relative p-1 border-2 border-gold">
          <div className="p-1 border-4 border-background">
            <img
              src="/screenshot.png"
              alt="rawctl - Native macOS RAW Editor Interface"
              className="w-full grayscale-[30%] brightness-90 hover:grayscale-0 hover:brightness-100 transition-all duration-700"
            />
          </div>
          {/* Corner decorations */}
          <div className="absolute top-2 left-2 w-6 h-6 border-t-2 border-l-2 border-gold" />
          <div className="absolute top-2 right-2 w-6 h-6 border-t-2 border-r-2 border-gold" />
          <div className="absolute bottom-2 left-2 w-6 h-6 border-b-2 border-l-2 border-gold" />
          <div className="absolute bottom-2 right-2 w-6 h-6 border-b-2 border-r-2 border-gold" />
        </div>
        {/* Glow effect on hover */}
        <div className="absolute inset-0 opacity-0 hover:opacity-100 transition-opacity duration-700 pointer-events-none shadow-gold-glow-xl" />
      </motion.div>
    </section>
  )
}
```

**Step 4: Commit**

```bash
git add landing/src/sections/ landing/public/
git commit -m "feat: add Hero section with app screenshot"
```

---

## Task 5: Pain Points Section

**Files:**
- Create: `landing/src/sections/PainPoints.tsx`

**Step 1: Create PainPoints section**

```tsx
// landing/src/sections/PainPoints.tsx
import { motion } from 'framer-motion'
import { HardDrive, CircleDollarSign, Unlock } from 'lucide-react'
import { SectionHeader, Card, DiamondIcon } from '@/components'

const painPoints = [
  {
    numeral: 'I',
    icon: HardDrive,
    title: 'NO CLOUD DEPENDENCY',
    subtitle: 'Process Locally',
    description: 'Your files never leave your machine. Full GPU acceleration with Metal. Zero upload latency. Works offline.',
  },
  {
    numeral: 'II',
    icon: CircleDollarSign,
    title: 'NO SUBSCRIPTION RANSOM',
    subtitle: 'Own Your Tools',
    description: 'Why rent software at $120/year? Core editing is free forever. Only pay for AI features when you need them.',
  },
  {
    numeral: 'III',
    icon: Unlock,
    title: 'NO LOCK-IN',
    subtitle: 'Open Standards',
    description: 'Standard JSON sidecars store your edits. No proprietary catalogs. Export everything, anytime, anywhere.',
  },
]

export function PainPoints() {
  return (
    <section className="py-32 px-6">
      <div className="max-w-6xl mx-auto">
        <SectionHeader
          title="WHY LOCAL-FIRST?"
          subtitle="Your Photos Deserve Better"
        />

        <div className="grid md:grid-cols-3 gap-8">
          {painPoints.map((point, index) => (
            <motion.div
              key={point.numeral}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.2, duration: 0.6 }}
            >
              <Card className="h-full text-center">
                {/* Roman numeral in diamond */}
                <div className="flex justify-center mb-6">
                  <DiamondIcon size="md">
                    <span className="font-display text-lg">{point.numeral}</span>
                  </DiamondIcon>
                </div>

                {/* Icon */}
                <div className="flex justify-center mb-4">
                  <point.icon className="w-8 h-8 text-gold/60" />
                </div>

                {/* Title */}
                <h3 className="text-xl font-display text-gold tracking-art-deco mb-2">
                  {point.title}
                </h3>

                {/* Subtitle */}
                <p className="text-sm text-muted uppercase tracking-wider mb-4">
                  {point.subtitle}
                </p>

                {/* Description */}
                <p className="text-foreground/70 leading-relaxed">
                  {point.description}
                </p>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

**Step 2: Commit**

```bash
git add landing/src/sections/PainPoints.tsx
git commit -m "feat: add Pain Points section"
```

---

## Task 6: Features Section

**Files:**
- Create: `landing/src/sections/Features.tsx`

**Step 1: Create Features section**

```tsx
// landing/src/sections/Features.tsx
import { motion } from 'framer-motion'
import { Sun, Spline, Thermometer, Star, Zap, FolderOpen } from 'lucide-react'
import { SectionHeader, Card } from '@/components'

const features = [
  {
    icon: Sun,
    title: 'EXPOSURE',
    description: '±5 EV range with highlights, shadows, whites & blacks control.',
  },
  {
    icon: Spline,
    title: 'TONE CURVES',
    description: '5-point precision curve editor for cinematic color grading.',
  },
  {
    icon: Thermometer,
    title: 'WHITE BALANCE',
    description: 'Presets + Kelvin temperature (2000-12000K) + tint fine-tuning.',
  },
  {
    icon: Star,
    title: 'ORGANIZATION',
    description: 'Stars, flags, color labels, custom tags & smart filters.',
  },
  {
    icon: Zap,
    title: 'PERFORMANCE',
    description: 'Metal GPU acceleration, smart caching, two-stage loading.',
  },
  {
    icon: FolderOpen,
    title: 'RAW SUPPORT',
    description: 'ARW, CR2, CR3, NEF, ORF, RAF, RW2, DNG, 3FR, IIQ & more.',
  },
]

export function Features() {
  return (
    <section className="py-32 px-6 bg-sunburst">
      <div className="max-w-6xl mx-auto">
        <SectionHeader
          title="PROFESSIONAL TOOLS"
          subtitle="Everything You Need, Nothing You Don't"
        />

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1, duration: 0.5 }}
            >
              <Card className="h-full">
                {/* Corner diamonds */}
                <div className="absolute top-4 left-4 text-gold/30">◇</div>
                <div className="absolute top-4 right-4 text-gold/30">◇</div>
                <div className="absolute bottom-4 left-4 text-gold/30">◇</div>
                <div className="absolute bottom-4 right-4 text-gold/30">◇</div>

                {/* Icon in diamond */}
                <motion.div
                  className="w-12 h-12 border border-gold/50 flex items-center justify-center mb-6 mx-auto"
                  style={{ transform: 'rotate(45deg)' }}
                  whileHover={{ rotate: 0 }}
                  transition={{ duration: 0.3 }}
                >
                  <feature.icon
                    className="w-6 h-6 text-gold"
                    style={{ transform: 'rotate(-45deg)' }}
                  />
                </motion.div>

                {/* Title */}
                <h3 className="text-lg font-display text-gold tracking-art-deco text-center mb-4">
                  {feature.title}
                </h3>

                {/* Description */}
                <p className="text-foreground/70 text-center leading-relaxed">
                  {feature.description}
                </p>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

**Step 2: Commit**

```bash
git add landing/src/sections/Features.tsx
git commit -m "feat: add Features section"
```

---

## Task 7: Comparison Section

**Files:**
- Create: `landing/src/sections/Comparison.tsx`

**Step 1: Create Comparison section**

```tsx
// landing/src/sections/Comparison.tsx
import { useState } from 'react'
import { motion } from 'framer-motion'
import { SectionHeader, Button } from '@/components'

const comparisons = [
  { feature: 'PRICE', rawctl: 'FREE FOREVER', lightroom: '$9.99/month ($120/yr)', winner: 'rawctl' },
  { feature: 'DATA STORAGE', rawctl: '100% Local', lightroom: 'Cloud-dependent', winner: 'rawctl' },
  { feature: 'EDIT FORMAT', rawctl: 'JSON Sidecar (Open)', lightroom: 'Proprietary Catalog', winner: 'rawctl' },
  { feature: 'SOURCE CODE', rawctl: 'Open Source', lightroom: 'Closed Source', winner: 'rawctl' },
  { feature: 'OFFLINE MODE', rawctl: 'Full Support', lightroom: 'Limited Features', winner: 'rawctl' },
  { feature: 'AI FEATURES', rawctl: 'Pay-as-you-go', lightroom: 'Subscription Required', winner: 'rawctl' },
]

export function Comparison() {
  const [years, setYears] = useState(3)
  const savings = years * 120

  return (
    <section className="py-32 px-6">
      <div className="max-w-5xl mx-auto">
        <SectionHeader
          title="THE HONEST COMPARISON"
          subtitle="See What You're Really Paying For"
        />

        {/* Comparison Table */}
        <motion.div
          className="border-2 border-gold p-1 mb-16"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          <div className="border-4 border-background">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gold/30">
                  <th className="py-4 px-6 text-left font-display text-muted tracking-wider"></th>
                  <th className="py-4 px-6 text-center font-display text-gold tracking-art-deco">rawctl</th>
                  <th className="py-4 px-6 text-center font-display text-muted tracking-wider">Adobe Lightroom</th>
                </tr>
              </thead>
              <tbody>
                {comparisons.map((row, index) => (
                  <tr key={row.feature} className={index < comparisons.length - 1 ? 'border-b border-gold/20' : ''}>
                    <td className="py-4 px-6 font-display text-foreground/60 tracking-wider text-sm">
                      {row.feature}
                    </td>
                    <td className="py-4 px-6 text-center">
                      <span className="text-gold font-medium">{row.rawctl}</span>
                      {row.winner === 'rawctl' && <span className="ml-2 text-gold">◆</span>}
                    </td>
                    <td className="py-4 px-6 text-center text-muted">
                      {row.lightroom}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </motion.div>

        {/* CTA */}
        <div className="text-center mb-20">
          <Button variant="primary" href="#download">
            SWITCH TO FREEDOM →
          </Button>
        </div>

        {/* Savings Calculator */}
        <motion.div
          className="max-w-md mx-auto bg-card border border-gold/30 p-8"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          <h3 className="font-display text-gold tracking-art-deco text-center text-xl mb-6">
            CALCULATE YOUR SAVINGS
          </h3>

          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-foreground/70">Years with Lightroom:</span>
              <select
                value={years}
                onChange={(e) => setYears(Number(e.target.value))}
                className="bg-background border border-gold/50 text-gold px-4 py-2 font-display"
              >
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((y) => (
                  <option key={y} value={y}>{y} year{y > 1 ? 's' : ''}</option>
                ))}
              </select>
            </div>

            <div className="border-t border-gold/20 pt-4 space-y-2">
              <div className="flex justify-between">
                <span className="text-foreground/70">You've already paid:</span>
                <span className="text-muted">${savings}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-foreground/70">With rawctl:</span>
                <span className="text-gold">$0</span>
              </div>
            </div>

            <div className="border-t border-gold pt-4">
              <div className="flex justify-between items-center">
                <span className="font-display text-foreground tracking-wider">YOUR SAVINGS:</span>
                <span className="text-2xl font-display text-gold">${savings} ◆</span>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  )
}
```

**Step 2: Commit**

```bash
git add landing/src/sections/Comparison.tsx
git commit -m "feat: add Comparison section with savings calculator"
```

---

## Task 8: Open Source Section

**Files:**
- Create: `landing/src/sections/OpenSource.tsx`

**Step 1: Create OpenSource section**

```tsx
// landing/src/sections/OpenSource.tsx
import { motion } from 'framer-motion'
import { Star, GitFork, Users, Github, Code } from 'lucide-react'
import { SectionHeader, Button, DiamondIcon } from '@/components'

const stats = [
  { icon: Star, value: '128', label: 'STARS' },
  { icon: GitFork, value: '42', label: 'FORKS' },
  { icon: Users, value: '15', label: 'CONTRIBUTORS' },
]

const steps = [
  { numeral: 'I', title: 'FORK', description: 'Clone the repository' },
  { numeral: 'II', title: 'CODE', description: 'Fix bugs or add features' },
  { numeral: 'III', title: 'PR', description: 'Submit & get merged' },
]

export function OpenSource() {
  return (
    <section className="py-32 px-6 bg-sunburst">
      <div className="max-w-6xl mx-auto">
        <SectionHeader
          title="BUILT IN THE OPEN"
          subtitle="By Photographers, For Photographers"
        />

        {/* GitHub Stats */}
        <motion.div
          className="flex flex-wrap justify-center gap-8 mb-16"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          {stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              className="text-center"
              initial={{ opacity: 0, scale: 0.8 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1 }}
            >
              <DiamondIcon size="lg" className="mx-auto mb-4">
                <stat.icon className="w-6 h-6" />
              </DiamondIcon>
              <div className="text-3xl font-display text-gold mb-1">{stat.value}</div>
              <div className="text-sm text-muted tracking-wider">{stat.label}</div>
            </motion.div>
          ))}
        </motion.div>

        {/* Quote */}
        <motion.div
          className="max-w-3xl mx-auto mb-16 bg-card border border-gold/30 p-8 relative corner-deco"
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
        >
          <blockquote className="text-xl text-foreground/80 italic text-center leading-relaxed">
            "No corporate agenda. No investor pressure. Just a tool
            built by people who actually edit photos."
          </blockquote>
          <p className="text-right text-gold mt-4 font-display tracking-wider">
            — The rawctl Philosophy
          </p>
        </motion.div>

        {/* CTAs */}
        <div className="flex flex-wrap justify-center gap-4 mb-20">
          <Button variant="solid" href="https://github.com/user/rawctl">
            <Star className="w-5 h-5" />
            STAR ON GITHUB
          </Button>
          <Button variant="primary" href="https://github.com/user/rawctl">
            <Code className="w-5 h-5" />
            READ THE SOURCE
          </Button>
        </div>

        {/* Divider */}
        <div className="border-t border-gold/20 mb-16" />

        {/* How to Contribute */}
        <h3 className="text-2xl font-display text-foreground tracking-art-deco text-center mb-12">
          HOW TO CONTRIBUTE
        </h3>

        <div className="flex flex-wrap justify-center items-center gap-4 md:gap-8">
          {steps.map((step, index) => (
            <motion.div
              key={step.numeral}
              className="flex items-center gap-4 md:gap-8"
              initial={{ opacity: 0, x: -20 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.2 }}
            >
              <div className="text-center">
                <div className="w-20 h-20 border border-gold/50 flex flex-col items-center justify-center mb-2">
                  <span className="font-display text-gold text-lg">{step.numeral}.</span>
                  <span className="font-display text-foreground tracking-wider text-sm mt-1">
                    {step.title}
                  </span>
                </div>
                <p className="text-muted text-sm max-w-[100px]">{step.description}</p>
              </div>
              {index < steps.length - 1 && (
                <span className="text-gold text-2xl hidden md:block">→</span>
              )}
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

**Step 2: Commit**

```bash
git add landing/src/sections/OpenSource.tsx
git commit -m "feat: add Open Source section"
```

---

## Task 9: Pricing Section

**Files:**
- Create: `landing/src/sections/Pricing.tsx`

**Step 1: Create Pricing section**

```tsx
// landing/src/sections/Pricing.tsx
import { motion } from 'framer-motion'
import { Check, Download } from 'lucide-react'
import { SectionHeader, Button } from '@/components'

const plans = [
  {
    numeral: 'I',
    name: 'FREE',
    price: '$0',
    period: 'forever',
    features: [
      'Full RAW editing',
      'All pro tools',
      'Unlimited photos',
      'JSON sidecar export',
      'Offline support',
      '5 AI images/mo',
    ],
    cta: 'DOWNLOAD',
    ctaVariant: 'primary' as const,
    recommended: false,
  },
  {
    numeral: '◆◆◆◆',
    name: 'PRO',
    price: '$9.99',
    period: '/mo',
    features: [
      'Everything in Free',
      '200 standard AI images/mo',
      '50 HD AI images/mo',
      'Priority queue',
      'Early feature access',
      'Support the project',
    ],
    cta: 'SUBSCRIBE',
    ctaVariant: 'solid' as const,
    recommended: true,
  },
]

const payAsYouGo = [
  { resolution: '1K Resolution', price: '$0.15 / image' },
  { resolution: '2K Resolution', price: '$0.30 / image' },
  { resolution: '4K Resolution', price: '$0.50 / image' },
]

export function Pricing() {
  return (
    <section className="py-32 px-6">
      <div className="max-w-5xl mx-auto">
        <SectionHeader
          title="SIMPLE PRICING"
          subtitle="Free Forever. Pay Only for AI Magic."
        />

        {/* Pricing Cards */}
        <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto mb-20">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              className={`
                relative bg-card border p-8
                ${plan.recommended
                  ? 'border-gold border-2 scale-105 shadow-gold-glow'
                  : 'border-gold/30'
                }
              `}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.2 }}
            >
              {/* Recommended badge */}
              {plan.recommended && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gold text-background px-4 py-1 font-display text-sm tracking-wider">
                  RECOMMENDED
                </div>
              )}

              {/* Corner decorations */}
              <div className="absolute top-3 left-3 text-gold/50">◇</div>
              <div className="absolute top-3 right-3 text-gold/50">◇</div>
              <div className="absolute bottom-3 left-3 text-gold/50">◇</div>
              <div className="absolute bottom-3 right-3 text-gold/50">◇</div>

              {/* Plan indicator */}
              <div className="text-center mb-4">
                <span className="font-display text-gold tracking-widest">{plan.numeral}</span>
              </div>

              {/* Plan name */}
              <h3 className="text-2xl font-display text-foreground tracking-art-deco text-center mb-4">
                {plan.name}
              </h3>

              {/* Price */}
              <div className="text-center mb-6">
                <span className="text-5xl font-display text-gold">{plan.price}</span>
                <span className="text-muted ml-2">{plan.period}</span>
              </div>

              {/* Divider */}
              <div className="border-t border-gold/20 mb-6" />

              {/* Features */}
              <ul className="space-y-3 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-3">
                    <Check className="w-5 h-5 text-gold flex-shrink-0" />
                    <span className="text-foreground/70">{feature}</span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              <Button variant={plan.ctaVariant} className="w-full" href="#download">
                {plan.name === 'FREE' && <Download className="w-5 h-5" />}
                {plan.cta}
              </Button>
            </motion.div>
          ))}
        </div>

        {/* Pay as you go */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          {/* Divider with text */}
          <div className="flex items-center gap-4 mb-8">
            <div className="flex-1 border-t border-gold/30" />
            <span className="font-display text-muted tracking-wider">OR PAY AS YOU GO</span>
            <div className="flex-1 border-t border-gold/30" />
          </div>

          {/* Pay as you go card */}
          <div className="max-w-2xl mx-auto bg-card border border-gold/20 p-8">
            <p className="text-foreground/70 text-center mb-6">
              Need just a few AI generations? No problem.
            </p>

            <div className="space-y-3 mb-6">
              {payAsYouGo.map((tier) => (
                <div key={tier.resolution} className="flex items-center gap-4">
                  <span className="text-gold">◆</span>
                  <span className="text-foreground/70 flex-1">{tier.resolution}</span>
                  <span className="font-display text-gold tracking-wider">{tier.price}</span>
                </div>
              ))}
            </div>

            <p className="text-muted text-center text-sm">
              No subscription. No commitment. Pay only what you use.
            </p>
          </div>
        </motion.div>
      </div>
    </section>
  )
}
```

**Step 2: Commit**

```bash
git add landing/src/sections/Pricing.tsx
git commit -m "feat: add Pricing section"
```

---

## Task 10: Final CTA & Footer

**Files:**
- Create: `landing/src/sections/FinalCTA.tsx`
- Create: `landing/src/sections/Footer.tsx`
- Create: `landing/src/sections/index.ts`

**Step 1: Create FinalCTA section**

```tsx
// landing/src/sections/FinalCTA.tsx
import { motion } from 'framer-motion'
import { Download } from 'lucide-react'
import { Button } from '@/components'

export function FinalCTA() {
  return (
    <section className="py-32 px-6 bg-sunburst" id="download">
      <div className="max-w-3xl mx-auto">
        <motion.div
          className="border-2 border-gold p-1"
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
        >
          <div className="border-4 border-background bg-card p-12 md:p-16 text-center">
            {/* Top divider */}
            <div className="divider-gold mb-8">
              <span className="text-gold text-2xl">✦</span>
            </div>

            {/* Headline */}
            <h2 className="text-3xl md:text-4xl lg:text-5xl font-display text-foreground tracking-art-deco-wide mb-6">
              READY TO OWN YOUR PHOTOS?
            </h2>

            {/* Subheadline */}
            <p className="text-lg text-foreground/70 mb-10">
              Join photographers who chose freedom over fees.
            </p>

            {/* CTA */}
            <Button variant="solid" href="#" className="text-lg px-10 py-5">
              <Download className="w-6 h-6" />
              DOWNLOAD FOR MAC
            </Button>

            {/* Requirement note */}
            <p className="text-muted text-sm mt-6">
              Requires macOS 14+
            </p>

            {/* Bottom divider */}
            <div className="divider-gold mt-8">
              <span className="text-gold text-2xl">✦</span>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  )
}
```

**Step 2: Create Footer section**

```tsx
// landing/src/sections/Footer.tsx
import { Divider } from '@/components'

const footerLinks = {
  product: [
    { label: 'Features', href: '#features' },
    { label: 'Pricing', href: '#pricing' },
    { label: 'Changelog', href: '#' },
    { label: 'Roadmap', href: '#' },
  ],
  community: [
    { label: 'GitHub', href: 'https://github.com/user/rawctl' },
    { label: 'Discussions', href: '#' },
    { label: 'Contributing', href: '#' },
    { label: 'Twitter/X', href: '#' },
  ],
  legal: [
    { label: 'Privacy', href: '#' },
    { label: 'Terms', href: '#' },
    { label: 'License (MIT)', href: '#' },
  ],
}

export function Footer() {
  return (
    <footer className="py-16 px-6 border-t border-gold/20">
      <div className="max-w-6xl mx-auto">
        <div className="grid md:grid-cols-4 gap-12 mb-12">
          {/* Brand */}
          <div className="md:col-span-1">
            <div className="flex items-center gap-2 mb-4">
              <span className="text-gold text-xl">◆</span>
              <span className="font-display text-xl text-foreground tracking-art-deco">rawctl</span>
            </div>
            <p className="text-foreground/60 leading-relaxed">
              Your photos. Your machine. Your freedom.
            </p>
            <p className="text-muted text-sm mt-4">
              A native macOS RAW editor built for photographers who value ownership.
            </p>
          </div>

          {/* Product */}
          <div>
            <h4 className="font-display text-foreground tracking-wider mb-4">PRODUCT</h4>
            <ul className="space-y-2">
              {footerLinks.product.map((link) => (
                <li key={link.label}>
                  <a href={link.href} className="text-muted hover:text-gold transition-colors">
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Community */}
          <div>
            <h4 className="font-display text-foreground tracking-wider mb-4">COMMUNITY</h4>
            <ul className="space-y-2">
              {footerLinks.community.map((link) => (
                <li key={link.label}>
                  <a href={link.href} className="text-muted hover:text-gold transition-colors">
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div>
            <h4 className="font-display text-foreground tracking-wider mb-4">LEGAL</h4>
            <ul className="space-y-2">
              {footerLinks.legal.map((link) => (
                <li key={link.label}>
                  <a href={link.href} className="text-muted hover:text-gold transition-colors">
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom */}
        <div className="border-t border-gold/20 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <p className="text-muted text-sm">
              <span className="text-gold/50">◇</span> Built with SwiftUI + Metal <span className="text-gold/50">◇</span>
            </p>
            <p className="text-muted text-sm">
              © MMXXVI rawctl. Open Source.
            </p>
          </div>

          {/* Final divider */}
          <Divider className="mt-8" />
        </div>
      </div>
    </footer>
  )
}
```

**Step 3: Create sections index**

```tsx
// landing/src/sections/index.ts
export { Hero } from './Hero'
export { PainPoints } from './PainPoints'
export { Features } from './Features'
export { Comparison } from './Comparison'
export { OpenSource } from './OpenSource'
export { Pricing } from './Pricing'
export { FinalCTA } from './FinalCTA'
export { Footer } from './Footer'
```

**Step 4: Commit**

```bash
git add landing/src/sections/
git commit -m "feat: add Final CTA and Footer sections"
```

---

## Task 11: Assemble App

**Files:**
- Modify: `landing/src/App.tsx`

**Step 1: Update App.tsx to include all sections**

```tsx
// landing/src/App.tsx
import {
  Hero,
  PainPoints,
  Features,
  Comparison,
  OpenSource,
  Pricing,
  FinalCTA,
  Footer,
} from '@/sections'

export default function App() {
  return (
    <div className="min-h-screen bg-background bg-crosshatch">
      <main>
        <Hero />
        <PainPoints />
        <Features />
        <Comparison />
        <OpenSource />
        <Pricing />
        <FinalCTA />
      </main>
      <Footer />
    </div>
  )
}
```

**Step 2: Test full page**

```bash
cd landing && npm run dev
```

Expected: All 8 sections render with Art Deco styling

**Step 3: Commit**

```bash
git add landing/src/App.tsx
git commit -m "feat: assemble complete landing page"
```

---

## Task 12: Cloudflare Pages Deployment Setup

**Files:**
- Create: `landing/wrangler.toml` (optional, for preview)
- Create: `landing/.gitignore`
- Create: `landing/README.md`

**Step 1: Create .gitignore**

```
node_modules
dist
.DS_Store
*.local
```

**Step 2: Create README.md**

```markdown
# rawctl Landing Page

Art Deco styled landing page for rawctl - the native macOS RAW editor.

## Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Deploy to Cloudflare Pages

1. Connect GitHub repo to Cloudflare Pages
2. Build settings:
   - Build command: `npm run build`
   - Build output directory: `dist`
   - Root directory: `landing`
3. Deploy
```

**Step 3: Build and verify**

```bash
cd landing && npm run build
```

Expected: Build completes without errors, `dist/` folder created

**Step 4: Commit**

```bash
git add landing/
git commit -m "chore: add deployment configuration for Cloudflare Pages"
```

---

## Task 13: Final Review & Polish

**Step 1: Run final build check**

```bash
cd landing && npm run build && npm run preview
```

**Step 2: Visual review checklist**

- [ ] Hero: Logo diamond, headline, screenshot with frame
- [ ] Pain Points: 3 cards with Roman numerals
- [ ] Features: 6 cards with diamond icons
- [ ] Comparison: Table with gold markers, calculator
- [ ] Open Source: Stats, quote, contribution steps
- [ ] Pricing: 2 cards (PRO recommended), pay-as-you-go
- [ ] Final CTA: Double frame, download button
- [ ] Footer: 4 columns, Roman numeral year

**Step 3: Responsive check**

- [ ] Mobile (375px)
- [ ] Tablet (768px)
- [ ] Desktop (1280px)

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete rawctl Art Deco landing page

- 8 sections: Hero, Pain Points, Features, Comparison, Open Source, Pricing, CTA, Footer
- Art Deco design system with gold/black palette
- Framer Motion animations
- Responsive layout
- Ready for Cloudflare Pages deployment"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Project Setup | package.json, configs |
| 2 | Base Styles | CSS, design tokens |
| 3 | Shared Components | Button, Card, etc. |
| 4 | Hero Section | Hero.tsx |
| 5 | Pain Points | PainPoints.tsx |
| 6 | Features | Features.tsx |
| 7 | Comparison | Comparison.tsx |
| 8 | Open Source | OpenSource.tsx |
| 9 | Pricing | Pricing.tsx |
| 10 | Final CTA & Footer | FinalCTA.tsx, Footer.tsx |
| 11 | Assemble App | App.tsx |
| 12 | Deployment Config | .gitignore, README |
| 13 | Final Review | QA checklist |

**Total estimated tasks:** 13
**Deployment:** Cloudflare Pages (build: `npm run build`, output: `dist`, root: `landing`)
