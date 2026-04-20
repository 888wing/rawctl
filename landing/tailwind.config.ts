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
