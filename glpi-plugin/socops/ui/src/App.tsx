import { useCallback, useEffect, useState } from 'react';
import { AlertTriangle, ArrowRight, RefreshCw, Shield } from 'lucide-react';
import { fetchOverview } from './api';
import { Analytics } from './components/Analytics';
import { Dashboard } from './components/Dashboard';
import { Layout, type WorkspaceView } from './components/Layout';
import { TicketQueue } from './components/TicketQueue';
import { TicketWorkspace } from './components/TicketWorkspace';
import type { Overview } from './types';

const validViews: WorkspaceView[] = ['overview', 'incidents', 'investigations', 'assigned', 'analytics'];

function initialLocation(): { view: WorkspaceView; ticketId: number | null } {
  const parameters = new URLSearchParams(window.location.search);
  const requested = parameters.get('view') as WorkspaceView | null;
  const view = requested && validViews.includes(requested) ? requested : 'overview';
  const ticket = Number(parameters.get('ticket'));
  return { view, ticketId: Number.isInteger(ticket) && ticket > 0 ? ticket : null };
}

export default function App() {
  const [location, setLocation] = useState(initialLocation);
  const [overview, setOverview] = useState<Overview | null>(null);
  const [overviewError, setOverviewError] = useState('');
  const [theme, setTheme] = useState<'dark' | 'light'>(() => {
    const saved = window.localStorage.getItem('socops-theme');
    return saved === 'light' ? 'light' : 'dark';
  });

  useEffect(() => {
    const controller = new AbortController();
    fetchOverview()
      .then((result) => {
        if (!controller.signal.aborted) {
          setOverview(result);
          setOverviewError('');
        }
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) {
          setOverviewError(error instanceof Error ? error.message : 'GLPI could not load the overview.');
        }
      });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    document.documentElement.dataset.socTheme = theme;
    window.localStorage.setItem('socops-theme', theme);
  }, [theme]);

  useEffect(() => {
    const onPopState = () => setLocation(initialLocation());
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  const navigate = useCallback((destination: string, ticketId?: number) => {
    const [rawView, rawQuery] = destination.split('?');
    const requestedView = rawView as WorkspaceView;
    const view = validViews.includes(requestedView) ? requestedView : 'overview';
    const params = new URLSearchParams(rawQuery || '');
    if (ticketId) params.set('ticket', String(ticketId));
    const selected = Number(params.get('ticket'));
    const next = {
      view,
      ticketId: Number.isInteger(selected) && selected > 0 ? selected : null,
    };
    const search = new URLSearchParams();
    search.set('view', view);
    if (next.ticketId) search.set('ticket', String(next.ticketId));
    window.history.pushState({}, '', window.location.pathname + '?' + search.toString());
    setLocation(next);
    document.getElementById('soc-main')?.focus();
  }, []);

  const backToQueue = useCallback(() => {
    navigate(location.view === 'overview' ? 'incidents' : location.view);
  }, [location.view, navigate]);

  function pageContent() {
    if (location.ticketId) {
      return <TicketWorkspace id={location.ticketId} onBack={backToQueue} />;
    }
    if (location.view === 'incidents' || location.view === 'investigations' || location.view === 'assigned') {
      return <TicketQueue view={location.view} onOpen={(id) => navigate(location.view, id)} />;
    }
    if (!overviewError && overview === null) {
      return <LoadingPage />;
    }
    if (overviewError && overview === null) {
      return <ErrorPage message={overviewError} onRetry={() => window.location.reload()} />;
    }
    if (overview === null) {
      return <ErrorPage message="GLPI did not return dashboard data." onRetry={() => window.location.reload()} />;
    }
    if (location.view === 'analytics') {
      return <Analytics overview={overview} onNavigate={navigate} />;
    }
    return <Dashboard overview={overview} onNavigate={navigate} />;
  }

  return (
    <Layout
      view={location.view}
      selectedTicket={location.ticketId !== null}
      overview={overview}
      userName={window.SOCOPS_CONFIG.currentUser}
      theme={theme}
      onThemeToggle={() => setTheme((value) => (value === 'dark' ? 'light' : 'dark'))}
      onNavigate={navigate}
    >
      {pageContent()}
    </Layout>
  );
}

function LoadingPage() {
  return (
    <div className="loading-dashboard" role="status" aria-live="polite">
      <span className="spinner spinner--large" />
      <strong>Loading security operations data</strong>
      <span>Checking tickets visible to your GLPI account…</span>
    </div>
  );
}

function ErrorPage({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <section className="panel error-page" role="alert">
      <span className="error-icon"><AlertTriangle size={21} /></span>
      <span className="eyebrow">GLPI data unavailable</span>
      <h2>We could not load this view</h2>
      <p>{message}</p>
      <div className="error-actions">
        <button className="primary-button" onClick={onRetry}><RefreshCw size={15} /> Try again</button>
        <a className="secondary-button" href="/"><Shield size={15} /> Open GLPI</a>
        <ArrowRight size={14} className="error-arrow" aria-hidden="true" />
      </div>
    </section>
  );
}
