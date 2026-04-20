import { motion } from 'framer-motion'
import { Download, FolderOpen, Github, Star, Zap } from 'lucide-react'
import { Button } from '@/components'
import { SITE } from '@/site'

export function Hero() {
  const callouts = [
    {
      title: 'Staged startup',
      description: 'Open large folders faster and start sorting before the full scan finishes.',
      icon: Zap,
    },
    {
      title: 'Open sidecars',
      description: 'Edits stay next to your originals in plain .latent.json files.',
      icon: FolderOpen,
    },
    {
      title: 'Flexible AI',
      description: 'Manual editing stays free. AI can be unlocked with Pro or credits.',
      icon: Star,
    },
  ]

  const pills = ['AI Cull', 'AI Colour Grade', 'Smart Sync', 'AI Mask', 'MIT source available']

  return (
    <section className="relative overflow-hidden px-6 pb-24 pt-24">
      <div className="absolute inset-0 bg-crosshatch opacity-60" />
      <div className="absolute inset-x-0 top-0 h-[34rem] bg-[radial-gradient(circle_at_top,rgba(212,175,55,0.16),transparent_62%)]" />
      <div className="absolute left-[-8rem] top-24 h-72 w-72 rounded-full bg-gold/10 blur-3xl" />
      <div className="absolute right-[-6rem] top-44 h-80 w-80 rounded-full bg-midnight/25 blur-3xl" />

      <div className="relative mx-auto grid max-w-7xl gap-16 xl:grid-cols-[0.95fr,1.05fr] xl:items-center">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
        >
          <div className="mb-6 inline-flex items-center gap-3 rounded-full border border-gold/20 bg-card/80 px-4 py-2 text-xs uppercase tracking-[0.28em] text-gold backdrop-blur">
            <span>{SITE.brand}</span>
            <span className="h-1.5 w-1.5 rounded-full bg-gold" />
            <span>Version {SITE.version}</span>
          </div>

          <h1 className="max-w-3xl text-5xl font-display leading-[1.05] text-foreground md:text-6xl lg:text-7xl">
            Local-first RAW editing, now fast enough for real shoots.
          </h1>

          <p className="mt-6 max-w-2xl text-lg leading-8 text-foreground/72 md:text-xl">
            Latent {SITE.version} brings AI Cull, AI Colour Grade, Smart Sync, and AI Mask into a
            native macOS workflow that keeps your folders local, your sidecars open, and your
            interactive preview noticeably lighter during actual editing.
          </p>

          <div className="mt-10 flex flex-col gap-4 sm:flex-row">
            <Button variant="solid" href={SITE.latestDownloadUrl} className="sm:min-w-[220px]">
              <Download className="h-5 w-5" />
              Download For macOS
            </Button>
            <Button variant="primary" href={SITE.repoUrl} target="_blank" className="sm:min-w-[180px]">
              <Github className="h-5 w-5" />
              View GitHub
            </Button>
          </div>

          <div className="mt-8 flex flex-wrap gap-3">
            {pills.map((pill) => (
              <span
                key={pill}
                className="rounded-full border border-gold/15 bg-background/55 px-4 py-2 text-xs uppercase tracking-[0.24em] text-foreground/62 backdrop-blur"
              >
                {pill}
              </span>
            ))}
          </div>

          <div className="mt-10 grid gap-4 md:grid-cols-3">
            {callouts.map((callout, index) => (
              <motion.div
                key={callout.title}
                className="rounded-[1.5rem] border border-gold/20 bg-card/75 p-5 backdrop-blur"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 + index * 0.1, duration: 0.5 }}
              >
                <callout.icon className="h-5 w-5 text-gold" />
                <h2 className="mt-4 text-sm font-display tracking-[0.22em] text-foreground">
                  {callout.title}
                </h2>
                <p className="mt-2 text-sm leading-6 text-foreground/62">{callout.description}</p>
              </motion.div>
            ))}
          </div>
        </motion.div>

        <motion.div
          className="relative xl:min-h-[46rem]"
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.1 }}
        >
          <div className="relative rounded-[2rem] border border-gold/25 bg-card/80 p-3 shadow-gold-glow-lg backdrop-blur">
            <div className="mb-3 flex items-center justify-between rounded-2xl border border-gold/10 bg-background/35 px-4 py-3 text-xs uppercase tracking-[0.24em] text-foreground/55">
              <span>Library Workflow</span>
              <span>Real 1.6 Capture</span>
            </div>
            <img
              src="/captures/latent-library.png"
              alt="Latent library browser with filters, folders, and thumbnails"
              className="w-full rounded-[1.35rem] border border-white/5"
            />
          </div>

          <div className="mt-5 rounded-[1.75rem] border border-gold/18 bg-background/70 p-4 xl:absolute xl:-bottom-12 xl:-right-8 xl:mt-0 xl:w-[47%]">
            <div className="mb-3 flex items-center justify-between text-[11px] uppercase tracking-[0.24em] text-foreground/50">
              <span>Edit View</span>
              <span>Histogram + Looks</span>
            </div>
            <img
              src="/captures/latent-edit.png"
              alt="Latent single-image editing interface"
              className="w-full rounded-[1.15rem] border border-white/5"
            />
          </div>
        </motion.div>
      </div>
    </section>
  )
}
