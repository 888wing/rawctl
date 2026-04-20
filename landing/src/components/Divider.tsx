export function Divider({ className = '' }: { className?: string }) {
  return (
    <div className={`divider-gold py-8 ${className}`}>
      <span className="text-gold text-xl">✦</span>
    </div>
  )
}
