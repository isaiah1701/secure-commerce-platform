import type { LucideIcon } from 'lucide-react';

interface MetricCardProps {
  label: string;
  value: number;
  detail: string;
  icon: LucideIcon;
  tone?: 'cyan' | 'amber' | 'blue' | 'green';
}

export function MetricCard({ label, value, detail, icon: Icon, tone = 'cyan' }: MetricCardProps) {
  return (
    <article className="metric-card">
      <div className="metric-card__copy">
        <span className="metric-card__label">{label}</span>
        <strong className="metric-card__value">{value.toLocaleString()}</strong>
        <span className="metric-card__detail">{detail}</span>
      </div>
      <span className={'metric-card__icon metric-card__icon--' + tone} aria-hidden="true">
        <Icon size={19} strokeWidth={1.8} />
      </span>
    </article>
  );
}
