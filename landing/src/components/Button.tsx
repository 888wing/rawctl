import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface ButtonProps {
  children: ReactNode
  variant?: 'primary' | 'solid' | 'outline'
  href?: string
  target?: string
  onClick?: () => void
  className?: string
}

export function Button({
  children,
  variant = 'primary',
  href,
  target,
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
      target={target}
      rel={target === '_blank' ? 'noopener noreferrer' : undefined}
      onClick={onClick}
      className={`${baseStyles} ${variants[variant]} ${className}`}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
    >
      {children}
    </Component>
  )
}
