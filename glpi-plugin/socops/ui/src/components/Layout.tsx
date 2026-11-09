import { useState, type ReactNode } from 'react';
import {
  Activity,
  BarChart3,
  BookOpen,
  Boxes,
  ChevronRight,
  ClipboardList,
  Command,
  Home,
  Menu,
  Moon,
  Settings,
  Shield,
  Sun,
  X,
} from 'lucide-react';
import type { Overview } from '../types';

export type WorkspaceView = 'overview' | 'incidents' | 'investigations' | 'assigned' | 'analytics';

interface LayoutProps {
  view: WorkspaceView;
  selectedTicket: boolean;
  overview: Overview | null;
  userName: string;
  theme: 'dark' | 'light';
  onThemeToggle: () => void;
  onNavigate: (view: string) => void;
  children: ReactNode;
}

interface NavigationItem {
  label: string;
  view?: WorkspaceView;
  href?: string;
  icon: typeof Home;
  capability?: 'assets' | 'knowledgeBase' | 'administration';
  always?: boolean;
}

const primaryNavigation: NavigationItem[] = [
  { label: 'Overview', view: 'overview', icon: Home },
  { label: 'Incident Queue', view: 'incidents', icon: Shield },
  { label: 'Investigations', view: 'investigations', icon: Activity },
  { label: 'My Assigned Tickets', view: 'assigned', icon: ClipboardList },
];

const supportNavigation: NavigationItem[] = [
  { label: 'Assets', href: '/front/computer.php', capability: 'assets', icon: Boxes },
  { label: 'Reports & Analytics', view: 'analytics', icon: BarChart3, always: true },
  { label: 'Knowledge Base', href: '/front/knowbaseitem.php', capability: 'knowledgeBase', icon: BookOpen },
];

const systemNavigation: NavigationItem[] = [
  { label: 'Administration', href: '/front/config.form.php', capability: 'administration', icon: Settings },
  { label: 'Settings', href: '/front/preference.php', icon: Settings, always: true },
];

export function Layout({
  view,
  selectedTicket,
  overview,
  userName,
  theme,
  onThemeToggle,
  onNavigate,
  children,
}: LayoutProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const capability = overview?.capabilities;

  function renderItem(item: NavigationItem) {
    const canAccess = item.always || !item.capability || capability?.[item.capability] === true;
    const active = !selectedTicket && item.view === view;
    const Icon = item.icon;

    if (item.href) {
      return canAccess ? (
        <a key={item.label} href={item.href} className="nav-item">
          <Icon size={17} strokeWidth={1.8} />
          <span>{item.label}</span>
          <ChevronRight size={14} className="nav-external" aria-hidden="true" />
        </a>
      ) : (
        <span key={item.label} className="nav-item nav-item--disabled" aria-disabled="true" title="Restricted by your GLPI profile">
          <Icon size={17} strokeWidth={1.8} />
          <span>{item.label}</span>
          <span className="nav-lock">Restricted</span>
        </span>
      );
    }

    return (
      <button
        key={item.label}
        className={'nav-item' + (active ? ' nav-item--active' : '')}
        aria-current={active ? 'page' : undefined}
        onClick={() => {
          onNavigate(item.view || 'overview');
          setMenuOpen(false);
        }}
      >
        <Icon size={17} strokeWidth={1.8} />
        <span>{item.label}</span>
        {active ? <span className="nav-active-mark" aria-hidden="true" /> : null}
      </button>
    );
  }

  return (
    <div className="soc-shell">
      {menuOpen ? <button className="mobile-backdrop" aria-label="Close navigation" onClick={() => setMenuOpen(false)} /> : null}
      <aside className={'soc-sidebar' + (menuOpen ? ' soc-sidebar--open' : '')} aria-label="SOC navigation">
        <div className="brand-lockup">
          <span className="brand-mark"><Shield size={21} strokeWidth={2} /></span>
          <span className="brand-copy"><strong>SECURITY OPERATIONS</strong><span>Analyst workspace</span></span>
          <button className="sidebar-close" aria-label="Close navigation" onClick={() => setMenuOpen(false)}><X size={19} /></button>
        </div>

        <div className="workspace-switch">
          <span className="workspace-switch__icon"><Command size={16} /></span>
          <span><strong>Secure Commerce</strong><small>Operations</small></span>
          <ChevronRight size={15} aria-hidden="true" />
        </div>

        <nav className="sidebar-nav">
          <span className="nav-section-label">Workspace</span>
          {primaryNavigation.map(renderItem)}
          <span className="nav-section-label nav-section-label--spaced">Operations</span>
          {supportNavigation.map(renderItem)}
          <span className="nav-section-label nav-section-label--spaced">System</span>
          {systemNavigation.map(renderItem)}
        </nav>

        <div className="sidebar-bottom">
          <div className="sidebar-context">
            <span className="context-dot" aria-hidden="true" />
            <span><strong>GLPI session</strong><small>Permissions are enforced by GLPI</small></span>
          </div>
          <a className="glpi-link" href="/">
            <span className="glpi-mini-mark">G</span>
            <span>Open GLPI service desk</span>
            <ChevronRight size={14} />
          </a>
        </div>
      </aside>

      <div className="soc-main-column">
        <header className="topbar">
          <button className="mobile-menu" aria-label="Open navigation" onClick={() => setMenuOpen(true)}>
            <Menu size={19} />
          </button>
          <div className="topbar-context">
            <span>Security Operations</span>
            <ChevronRight size={14} aria-hidden="true" />
            <strong>{selectedTicket ? 'Investigation workspace' : pageTitle(view)}</strong>
          </div>
          <div className="topbar-actions">
            <span className="session-chip"><span className="context-dot" />GLPI session</span>
            <button className="icon-button theme-toggle" onClick={onThemeToggle} aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}>
              {theme === 'dark' ? <Sun size={17} /> : <Moon size={17} />}
            </button>
            <span className="topbar-divider" aria-hidden="true" />
            <span className="user-summary">
              <span className="user-avatar" aria-hidden="true">{initials(userName)}</span>
              <span><strong>{userName || 'GLPI analyst'}</strong><small>Analyst</small></span>
            </span>
          </div>
        </header>

        <main className="soc-main" id="soc-main" tabIndex={-1}>
          <div className="page-heading">
            <div>
              <span className="eyebrow">{selectedTicket ? 'Case management' : pageEyebrow(view)}</span>
              <h1>{selectedTicket ? 'Investigation workspace' : pageTitle(view)}</h1>
              <p>{selectedTicket ? 'Review evidence and continue the case in GLPI.' : pageDescription(view)}</p>
            </div>
            <div className="page-heading__right">
              <span className="data-source-chip"><span className="source-dot" />GLPI ticket data</span>
            </div>
          </div>
          {children}
        </main>

        <footer className="soc-footer">
          <span>Secure Commerce SOC workspace</span>
          <span>GLPI 11 · Existing ticket permissions and workflows</span>
        </footer>
      </div>
    </div>
  );
}

function pageTitle(view: WorkspaceView): string {
  if (view === 'incidents') return 'Incident queue';
  if (view === 'investigations') return 'Investigations';
  if (view === 'assigned') return 'My assigned tickets';
  if (view === 'analytics') return 'Reports & analytics';
  return 'Operations overview';
}

function pageEyebrow(view: WorkspaceView): string {
  if (view === 'incidents') return 'Sentinel cases';
  if (view === 'investigations') return 'Active response';
  if (view === 'assigned') return 'Your workload';
  if (view === 'analytics') return 'Ticket reporting';
  return 'Security operations';
}

function pageDescription(view: WorkspaceView): string {
  if (view === 'incidents') return 'Search, triage and open security cases generated from Sentinel.';
  if (view === 'investigations') return 'Continue open investigations and record the outcome in GLPI.';
  if (view === 'assigned') return 'Review the GLPI tickets assigned to your account.';
  if (view === 'analytics') return 'Explore trends and workload calculated from visible GLPI tickets.';
  return 'A clear view of current security cases and analyst work.';
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0].toUpperCase()).join('') || 'GL';
}
