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
