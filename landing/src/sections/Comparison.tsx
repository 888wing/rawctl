import { useState } from 'react'
import { motion } from 'framer-motion'
import { SectionHeader, Button } from '@/components'

const comparisons = [
  { feature: 'PRICING', latent: 'Free editing + optional Pro', lightroom: 'Subscription required', winner: 'latent' },
  { feature: 'DATA STORAGE', latent: '100% local folders', lightroom: 'Cloud-tied ecosystem', winner: 'latent' },
  { feature: 'EDIT FORMAT', latent: '.latent.json sidecars', lightroom: 'Proprietary catalog', winner: 'latent' },
  { feature: 'OFFLINE MODE', latent: 'Full local workflow', lightroom: 'Service-dependent features', winner: 'latent' },
  { feature: 'AI ACCESS', latent: 'Credits or Pro plan', lightroom: 'Subscription required', winner: 'latent' },
  { feature: 'SOURCE CODE', latent: 'MIT-licensed repo', lightroom: 'Closed source', winner: 'latent' },
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
                  <th className="py-4 px-6 text-center font-display text-gold tracking-art-deco">Latent</th>
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
                      <span className="text-gold font-medium">{row.latent}</span>
                      {row.winner === 'latent' && <span className="ml-2 text-gold">◆</span>}
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
            DOWNLOAD LATENT →
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
                <span className="text-foreground/70">With Latent:</span>
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
