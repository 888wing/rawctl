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
      'Unlimited manual editing',
      'Folder-based workflow',
      '.latent.json sidecars',
      'Offline support',
      'Ratings, filters, export',
    ],
    cta: 'DOWNLOAD',
    ctaVariant: 'primary' as const,
    recommended: false,
  },
  {
    numeral: '◆◆◆◆',
    name: 'PRO',
    price: '$15',
    period: '/mo',
    features: [
      'AI Cull',
      'AI Colour Grade',
      'Smart Sync',
      'AI Mask',
      'Batch processing',
      'Yearly plan also available',
    ],
    cta: 'SUBSCRIBE',
    ctaVariant: 'solid' as const,
    recommended: true,
  },
]

const payAsYouGo = [
  { resolution: '100 credits', price: '$4.99' },
  { resolution: '300 credits', price: '$11.99' },
  { resolution: '1000 credits', price: '$29.99' },
]

export function Pricing() {
  return (
    <section className="py-32 px-6" id="pricing">
      <div className="max-w-5xl mx-auto">
        <SectionHeader
          title="SIMPLE PRICING"
          subtitle="Free manual editing. Optional Pro and credits for AI workflows."
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
              Need AI usage without a recurring subscription? Use credits only when you need them.
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
              Credit packs are available in-app for one-off AI work.
            </p>
          </div>
        </motion.div>
      </div>
    </section>
  )
}
