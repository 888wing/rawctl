import { motion } from 'framer-motion'
import { ArrowRight, FolderOpen, SlidersHorizontal, Star, Zap } from 'lucide-react'
import { Card, SectionHeader } from '@/components'

const showcases = [
  {
    eyebrow: 'Library View',
    title: 'Start working before the full card scan is done',
    description:
      'Latent 1.6 opens large folders in stages so you can begin rating, filtering, and selecting while the rest of the library continues loading in the background.',
    image: '/captures/latent-library.png',
    alt: 'Latent library browser with staged thumbnail loading and filters',
    icon: FolderOpen,
    bullets: [
      'Smart collections, picks, rejects, and folder browsing stay in one native sidebar.',
      'Filter bar, ratings, and tags are available immediately after the first batch appears.',
      'The faster staged scan path is tuned for large cards and removable volumes.',
    ],
  },
  {
    eyebrow: 'Edit View',
    title: 'Move from selection to grading without leaving the app',
    description:
      'Single-image editing keeps the histogram, looks, compare mode, and AI tools in reach while a lighter interactive preview path makes slider scrubbing feel faster.',
    image: '/captures/latent-edit.png',
    alt: 'Latent single-photo editing view with histogram and grading controls',
    icon: SlidersHorizontal,
    bullets: [
      'Original, neutral, vivid, portrait, landscape, and cinematic looks stay one click away.',
      'Compare, Smart Sync, Nano Banana, and Lightroom preset import live beside manual tools.',
      'The 1.6 performance pass prioritizes responsiveness during active editing.',
    ],
  },
]

const workflow = [
  { icon: FolderOpen, label: 'Open folders directly', detail: 'No catalog import wall' },
  { icon: Star, label: 'Cull with AI or manually', detail: 'Ratings and picks stay local' },
  { icon: SlidersHorizontal, label: 'Grade in the editor', detail: 'Interactive preview tuned for speed' },
  { icon: Zap, label: 'Ship the final set', detail: 'Export without leaving the workspace' },
]

export function Showcase() {
  return (
    <section className="px-6 py-24">
      <div className="mx-auto max-w-7xl">
        <SectionHeader
          title="SEE THE WORKFLOW"
          subtitle="Real captured UI from the current Latent 1.6 build, covering browse and edit states."
        />

        <div className="space-y-10">
          {showcases.map((showcase, index) => (
            <motion.div
              key={showcase.title}
              className="grid gap-8 lg:grid-cols-[1.1fr,0.9fr] lg:items-center"
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2 }}
              transition={{ duration: 0.6 }}
            >
              <div className={index % 2 === 1 ? 'lg:order-2' : ''}>
                <div className="relative overflow-hidden rounded-[1.75rem] border border-gold/30 bg-card/80 p-3 shadow-gold-glow-lg backdrop-blur">
                  <div className="mb-3 flex items-center justify-between rounded-2xl border border-gold/10 bg-background/40 px-4 py-3 text-xs uppercase tracking-[0.24em] text-foreground/55">
                    <span>{showcase.eyebrow}</span>
                    <span>Captured From App</span>
                  </div>
                  <img
                    src={showcase.image}
                    alt={showcase.alt}
                    className="w-full rounded-[1.25rem] border border-white/5"
                  />
                </div>
              </div>

              <Card
                className={`h-full rounded-[1.75rem] p-10 ${index % 2 === 1 ? 'lg:order-1' : ''}`}
                hover={false}
              >
                <div className="mb-5 inline-flex items-center gap-3 rounded-full border border-gold/25 bg-gold/10 px-4 py-2 text-xs uppercase tracking-[0.28em] text-gold">
                  <showcase.icon className="h-4 w-4" />
                  {showcase.eyebrow}
                </div>

                <h3 className="max-w-xl text-3xl font-display leading-tight text-foreground md:text-4xl">
                  {showcase.title}
                </h3>

                <p className="mt-5 max-w-xl text-lg leading-8 text-foreground/72">
                  {showcase.description}
                </p>

                <div className="mt-8 space-y-4">
                  {showcase.bullets.map((bullet) => (
                    <div key={bullet} className="flex gap-4">
                      <ArrowRight className="mt-1 h-4 w-4 flex-none text-gold" />
                      <p className="text-foreground/70">{bullet}</p>
                    </div>
                  ))}
                </div>
              </Card>
            </motion.div>
          ))}
        </div>

        <motion.div
          className="mt-10 grid gap-4 rounded-[1.75rem] border border-gold/25 bg-card/70 p-6 md:grid-cols-4"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          {workflow.map((step) => (
            <div key={step.label} className="rounded-2xl border border-gold/10 bg-background/35 p-5">
              <step.icon className="h-5 w-5 text-gold" />
              <h4 className="mt-4 font-display text-sm tracking-[0.22em] text-foreground">
                {step.label}
              </h4>
              <p className="mt-2 text-sm leading-6 text-foreground/60">{step.detail}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
