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
