import {
  Hero,
  Showcase,
  PainPoints,
  Features,
  Comparison,
  OpenSource,
  Pricing,
  FinalCTA,
  Footer,
} from '@/sections'

export default function App() {
  return (
    <div className="min-h-screen bg-background bg-crosshatch">
      <main>
        <Hero />
        <Showcase />
        <PainPoints />
        <Features />
        <Comparison />
        <OpenSource />
        <Pricing />
        <FinalCTA />
      </main>
      <Footer />
    </div>
  )
}
