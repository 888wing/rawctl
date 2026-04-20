import { motion } from 'framer-motion'
import { Sun, Spline, Thermometer, Star, Zap, FolderOpen } from 'lucide-react'
import { SectionHeader, Card } from '@/components'

const features = [
  {
    icon: Sun,
    title: 'AI CULL',
    description: 'Scores sharpness, saliency, and exposure so bursts and duplicates can be ranked automatically.',
  },
  {
    icon: Spline,
    title: 'AI COLOUR GRADE',
    description: 'Build a full starting look from scene analysis or a mood prompt, then keep editing manually.',
  },
  {
    icon: Thermometer,
    title: 'SMART SYNC',
    description: 'Transfer a recipe to visually similar scenes while adapting for changing light and composition.',
  },
  {
    icon: Star,
    title: 'AI MASK',
    description: 'Point-click subject masking powered by Mobile-SAM, designed to fit the existing local adjustment workflow.',
  },
  {
    icon: Zap,
    title: 'FAST PREVIEW',
    description: 'Staged scans and a lighter interactive render path keep large-card startup and slider scrubbing responsive.',
  },
  {
    icon: FolderOpen,
    title: 'LOCAL-FIRST',
    description: 'Your originals stay in your folders and edits are stored in open sidecars next to the images.',
  },
]

export function Features() {
  return (
    <section className="py-32 px-6 bg-sunburst" id="features">
      <div className="max-w-6xl mx-auto">
        <SectionHeader
          title="LATENT 1.6"
          subtitle="AI-assisted editing without moving your library into a cloud catalog"
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
