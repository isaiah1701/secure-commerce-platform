import {
  Activity,
  AlertCircle,
  ArrowRight,
  CheckCircle2,
  ClipboardList,
  ShieldAlert,
  Users,
} from 'lucide-react';
import { MetricCard } from './MetricCard';
import { TrendChart } from './TrendChart';
import { formatDate } from '../lib/tickets';
import type { Overview } from '../types';

interface DashboardProps {
  overview: Overview;
  onNavigate: (view: string) => void;
}

const severityOrder = ['critical', 'high', 'medium', 'low', 'unknown'] as const;

export function Dashboard({ overview, onNavigate }: DashboardProps) {
  const totalSeverity = severityOrder.reduce((sum, key) => sum + overview.severity[key], 0);
  const bars = [
    { key: 'critical', label: 'Critical', className: 'severity-critical' },
    { key: 'high', label: 'High', className: 'severity-high' },
    { key: 'medium', label: 'Medium', className: 'severity-medium' },
    { key: 'low', label: 'Low', className: 'severity-low' },
    { key: 'unknown', label: 'Not provided', className: 'severity-unknown' },
  ] as const;

  return (
    <div className="page-stack">
      {overview.sampled ? (
        <div className="data-scope" role="status">
          These counts use the {overview.sampleSize} most recent tickets your GLPI profile can view.
          Search the queue to locate older tickets. Total visible tickets: {overview.totalVisibleTickets.toLocaleString()}.
        </div>
      ) : null}

      <section className="metric-grid" aria-label="Current incident metrics">
        <MetricCard
          label="Open SOC cases"
          value={overview.openCases}
          detail="Sentinel incidents not resolved or closed"
          icon={ShieldAlert}
          tone="amber"
        />
        <MetricCard
          label="Awaiting triage"
          value={overview.awaitingTriage}
          detail="New cases needing a first review"
          icon={AlertCircle}
          tone="cyan"
        />
        <MetricCard
          label="Assigned investigations"
          value={overview.assignedCases}
          detail="Open cases with an analyst assigned"
          icon={Users}
          tone="blue"
        />
        <MetricCard
          label="Resolved in 30 days"
          value={overview.resolvedLast30d}
          detail="Sentinel cases marked resolved"
          icon={CheckCircle2}
          tone="green"
        />
      </section>

      <div className="dashboard-grid dashboard-grid--wide">
        <section className="panel trend-panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">Activity</span>
              <h2>Incident trend</h2>
              <p>Sentinel cases created over the last 14 days</p>
            </div>
            <button className="quiet-button" onClick={() => onNavigate('analytics')}>
              View reports <ArrowRight size={15} />
            </button>
          </div>
          <TrendChart points={overview.trend} onSelect={() => onNavigate('incidents')} />
        </section>

        <section className="panel severity-panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">Queue</span>
              <h2>Severity breakdown</h2>
              <p>Severity recorded in the ticket</p>
            </div>
            <button className="icon-button" aria-label="Open incident queue" onClick={() => onNavigate('incidents')}>
              <ArrowRight size={17} />
            </button>
          </div>
          <div
            className="severity-stack"
            role="img"
            aria-label={bars.map((bar) => bar.label + ': ' + overview.severity[bar.key]).join(', ')}
          >
            {bars.map((bar) => {
              const count = overview.severity[bar.key];
              const percent = totalSeverity > 0 ? (count / totalSeverity) * 100 : 0;
              return <span key={bar.key} className={bar.className} style={{ width: percent + '%' }} />;
            })}
          </div>
          <ul className="severity-legend">
            {bars.map((bar) => (
              <li key={bar.key}>
                <span className={'legend-dot ' + bar.className} aria-hidden="true" />
                <span>{bar.label}</span>
                <strong>{overview.severity[bar.key].toLocaleString()}</strong>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <div className="dashboard-grid dashboard-grid--lower">
        <section className="panel activity-panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">Latest cases</span>
              <h2>Recent security activity</h2>
            </div>
            <button className="quiet-button" onClick={() => onNavigate('incidents')}>
              Incident queue <ArrowRight size={15} />
            </button>
          </div>
          {overview.recentActivity.length > 0 ? (
            <div className="activity-list">
              {overview.recentActivity.map((ticket) => (
                <button
                  key={ticket.id}
                  className="activity-row"
                  onClick={() => onNavigate('incidents?ticket=' + ticket.id)}
                >
                  <span className={'activity-symbol ' + (ticket.severity ? 'activity-symbol--' + ticket.severity : '')}>
                    <Activity size={16} />
                  </span>
                  <span className="activity-copy">
                    <strong>{ticket.title}</strong>
                    <span>
                      {ticket.incidentNumber ? 'Sentinel incident ' + ticket.incidentNumber : 'Sentinel detection'}
                      {' · ' + ticket.statusLabel}
                    </span>
                  </span>
                  <time dateTime={ticket.dateMod}>{formatDate(ticket.dateMod)}</time>
                  <ArrowRight size={16} className="activity-chevron" aria-hidden="true" />
                </button>
              ))}
            </div>
          ) : (
            <div className="empty-state empty-state--compact">
              <span className="empty-state__icon"><ClipboardList size={21} /></span>
              <strong>No Sentinel cases yet</strong>
              <span>Cases will appear here when Sentinel automation creates GLPI tickets.</span>
            </div>
          )}
        </section>

        <section className="panel workload-panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">Assignments</span>
              <h2>Analyst workload</h2>
              <p>Open cases grouped by assigned analyst</p>
            </div>
            <span className="panel-icon"><Users size={17} /></span>
          </div>
          {overview.workload.length > 0 ? (
            <ul className="workload-list">
              {overview.workload.slice(0, 6).map((analyst, index) => {
                const max = Math.max(...overview.workload.map((item) => item.count), 1);
                return (
                  <li key={analyst.name}>
                    <div className="workload-row">
                      <span className="analyst-avatar" aria-hidden="true">{analyst.name.charAt(0).toUpperCase()}</span>
                      <span className="workload-name">{analyst.name}</span>
                      <strong>{analyst.count}</strong>
                    </div>
                    <div className="workload-track" aria-hidden="true">
                      <span style={{ width: (analyst.count / max) * 100 + '%' }} className={'workload-fill workload-fill--' + (index % 4)} />
                    </div>
                  </li>
                );
              })}
            </ul>
          ) : (
            <div className="empty-state empty-state--compact">
              <span className="empty-state__icon"><Users size={21} /></span>
              <strong>No analyst assignments</strong>
              <span>Open GLPI tickets to assign a case to an analyst.</span>
            </div>
          )}
        </section>
      </div>

      <div className="dashboard-footnote">
        <span>Data from GLPI tickets visible to your current profile.</span>
        <span>Refreshed {formatDate(overview.generatedAt)}</span>
      </div>
    </div>
  );
}
