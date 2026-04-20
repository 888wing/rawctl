import { motion } from 'framer-motion'
import { Star, GitFork, Users, Code } from 'lucide-react'
import { SectionHeader, Button, DiamondIcon } from '@/components'
import { SITE } from '@/site'

const stats = [
  { icon: Code, value: 'SwiftUI', label: 'NATIVE STACK' },
  { icon: GitFork, value: 'Local', label: 'WORKFLOW' },
  { icon: Users, value: 'macOS 14+', label: 'TARGET PLATFORM' },
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
            "Keep the originals in your own folders, keep the edits beside them,
            and add AI only where it actually saves real editing time."
          </blockquote>
          <p className="text-right text-gold mt-4 font-display tracking-wider">
            — The Latent Philosophy
          </p>
        </motion.div>

        {/* CTAs */}
        <div className="flex flex-wrap justify-center gap-4 mb-20">
          <Button variant="solid" href={SITE.repoUrl} target="_blank">
            <Star className="w-5 h-5" />
            STAR ON GITHUB
          </Button>
          <Button variant="primary" href={SITE.repoUrl} target="_blank">
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
