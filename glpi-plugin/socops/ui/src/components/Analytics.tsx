import { BarChart3, CheckCircle2, ListChecks } from 'lucide-react';
import { TrendChart } from './TrendChart';
import { formatDate } from '../lib/tickets';
import type { Overview } from '../types';

interface AnalyticsProps {
  overview: Overview;
  onNavigate: (view: string) => void;
}

export function Analytics({ overview, onNavigate }: AnalyticsProps) {
  const statusRows = Object.entries(overview.statusDistribution).sort((left, right) => right[1] - left[1]);
  const maxStatus = Math.max(1, ...statusRows.map((row) => row[1]));

  return (
    <div className="page-stack">
      {overview.sampled ? (
        <div className="data-scope" role="status">
          Charts use the {overview.sampleSize} most recent visible tickets. The list includes
          {overview.totalVisibleTickets.toLocaleString() + ' '}tickets in total; use the queue search to find older cases.
        </div>
      ) : null}
      <div className="dashboard-grid dashboard-grid--wide">
        <section className="panel trend-panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">14-day view</span>
              <h2>Sentinel case volume</h2>
              <p>Counts use each ticket’s GLPI creation time</p>
            </div>
            <span className="panel-icon"><BarChart3 size={18} /></span>
          </div>
          <TrendChart points={overview.trend} onSelect={() => onNavigate('incidents')} />
        </section>
        <section className="panel">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">Current work</span>
              <h2>Ticket status</h2>
              <p>Visible Sentinel cases in the current sample</p>
            </div>
            <span className="panel-icon"><ListChecks size={18} /></span>
          </div>
          {statusRows.length ? (
            <ul className="distribution-list">
              {statusRows.map(([name, count]) => (
                <li key={name}>
                  <div><span>{name}</span><strong>{count}</strong></div>
                  <span className="distribution-track" aria-hidden="true">
                    <span style={{ width: (count / maxStatus) * 100 + '%' }} />
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <div className="empty-state empty-state--compact">
              <span className="empty-state__icon"><CheckCircle2 size={21} /></span>
              <strong>No status data available</strong>
              <span>Sentinel tickets will be included after the first incident is created.</span>
            </div>
          )}
        </section>
      </div>
      <section className="panel analytics-note">
        <div className="panel-icon panel-icon--green"><CheckCircle2 size={18} /></div>
        <div>
          <h2>Source and scope</h2>
          <p>
            These charts are calculated from GLPI tickets your account can access. The workspace
            does not generate placeholder data or infer severity when the ticket has no severity.
          </p>
          <span>Last calculated {formatDate(overview.generatedAt)}</span>
        </div>
      </section>
    </div>
  );
}
