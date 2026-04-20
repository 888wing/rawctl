import { motion } from 'framer-motion'
import { Download } from 'lucide-react'
import { Button } from '@/components'
import { SITE } from '@/site'

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
              Latent {SITE.version} is available now as a direct macOS download.
            </p>

            {/* CTA */}
            <Button variant="solid" href={SITE.latestDownloadUrl} className="text-lg px-10 py-5">
              <Download className="w-6 h-6" />
              DOWNLOAD FOR MAC
            </Button>

            {/* Requirement note */}
            <p className="text-muted text-sm mt-6">
              Latest direct build • requires macOS 14+
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
