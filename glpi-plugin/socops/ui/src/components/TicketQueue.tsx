import { useEffect, useMemo, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  ChevronLeft,
  ChevronRight,
  ExternalLink,
  Filter,
  Search,
  Shield,
} from 'lucide-react';
import { fetchTickets } from '../api';
import { formatDate, severityTone, sortTickets, statusTone } from '../lib/tickets';
import type { SortKey } from '../lib/tickets';
import type { TicketPage } from '../types';

interface TicketQueueProps {
  view: 'incidents' | 'investigations' | 'assigned';
  onOpen: (id: number) => void;
}

const PAGE_SIZE = 25;
const EMPTY_TICKETS: TicketPage['tickets'] = [];

const viewCopy = {
  incidents: {
    eyebrow: 'Alert cases',
    title: 'Incident queue',
    description: 'Security tickets created from Microsoft Sentinel incidents.',
  },
  investigations: {
    eyebrow: 'Active work',
    title: 'Investigations',
    description: 'Open Sentinel cases ready for an analyst to investigate.',
  },
  assigned: {
    eyebrow: 'My work',
    title: 'My assigned tickets',
    description: 'Tickets assigned to your GLPI account.',
  },
};

export function TicketQueue({ view, onOpen }: TicketQueueProps) {
  const [queryInput, setQueryInput] = useState('');
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('');
  const [severity, setSeverity] = useState('');
  const [page, setPage] = useState(0);
  const [response, setResponse] = useState<{
    key: string;
    data?: TicketPage;
    error?: string;
  }>({ key: '' });
  const [sortKey, setSortKey] = useState<SortKey>('dateMod');
  const [direction, setDirection] = useState<'asc' | 'desc'>('desc');
  const requestKey = [view, query, status, severity, page].join('|');
  const loading = response.key !== requestKey;
  const tickets = response.key === requestKey ? response.data?.tickets ?? EMPTY_TICKETS : EMPTY_TICKETS;
  const total = response.key === requestKey ? response.data?.total ?? 0 : 0;
  const error = response.key === requestKey ? response.error ?? '' : '';

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setQuery(queryInput.trim());
      setPage(0);
    }, 250);
    return () => window.clearTimeout(timer);
  }, [queryInput]);

  useEffect(() => {
    const controller = new AbortController();
    fetchTickets({
      view,
      q: query,
      status,
      severity,
      start: page * PAGE_SIZE,
      limit: PAGE_SIZE,
    })
      .then((result) => {
        if (controller.signal.aborted) return;
        setResponse({ key: requestKey, data: result });
      })
      .catch((reason: unknown) => {
        if (controller.signal.aborted) return;
        setResponse({
          key: requestKey,
          error: reason instanceof Error ? reason.message : 'GLPI could not load the ticket queue.',
        });
      });
    return () => controller.abort();
  }, [view, query, status, severity, page, requestKey]);

  const orderedTickets = useMemo(
    () => sortTickets(tickets, sortKey, direction),
    [tickets, sortKey, direction],
  );
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const first = total === 0 ? 0 : page * PAGE_SIZE + 1;
  const last = Math.min(total, page * PAGE_SIZE + tickets.length);
  const copy = viewCopy[view];

  function changeSort(key: SortKey) {
    if (sortKey === key) {
      setDirection((value) => (value === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setDirection(key === 'title' ? 'asc' : 'desc');
    }
  }

  function sortIcon(key: SortKey) {
    if (sortKey !== key) return <ArrowUpDown size={14} aria-hidden="true" />;
    return direction === 'asc'
      ? <ArrowUp size={14} aria-hidden="true" />
      : <ArrowDown size={14} aria-hidden="true" />;
  }

  return (
    <div className="page-stack">
      <section className="queue-toolbar panel">
        <div className="queue-search">
          <Search size={17} aria-hidden="true" />
          <label className="sr-only" htmlFor="soc-ticket-search">Search tickets</label>
          <input
            id="soc-ticket-search"
            value={queryInput}
            onChange={(event) => setQueryInput(event.target.value)}
            placeholder="Search title, incident number, source IP…"
            autoComplete="off"
          />
          {queryInput ? (
            <button className="search-clear" onClick={() => setQueryInput('')} aria-label="Clear search">
              ×
            </button>
          ) : null}
        </div>
        <div className="queue-filters">
          <label className="filter-control">
            <Filter size={15} aria-hidden="true" />
            <span className="sr-only">Filter by status</span>
            <select
              value={status}
              onChange={(event) => {
                setStatus(event.target.value);
                setPage(0);
              }}
            >
              <option value="">All statuses</option>
              <option value="1">New</option>
              <option value="2">Assigned</option>
              <option value="3">Planned</option>
              <option value="4">Waiting</option>
              <option value="5">Resolved</option>
              <option value="6">Closed</option>
            </select>
          </label>
          <label className="filter-control">
            <Shield size={15} aria-hidden="true" />
            <span className="sr-only">Filter by severity</span>
            <select
              value={severity}
              onChange={(event) => {
                setSeverity(event.target.value);
                setPage(0);
              }}
            >
              <option value="">All severities</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
          </label>
        </div>
      </section>

      {error ? <div className="inline-error" role="alert">{error}</div> : null}

      <section className="panel queue-panel" aria-labelledby="queue-title">
        <div className="panel-heading queue-heading">
          <div>
            <span className="eyebrow">{copy.eyebrow}</span>
            <h2 id="queue-title">{copy.title}</h2>
            <p>{copy.description}</p>
          </div>
          <div className="queue-total">
            <strong>{total.toLocaleString()}</strong>
            <span>{total === 1 ? 'ticket' : 'tickets'}</span>
          </div>
        </div>

        <div className="table-scroll">
          <table className="ticket-table">
            <thead>
              <tr>
                <th aria-sort={sortKey === 'title' ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => changeSort('title')}>Incident {sortIcon('title')}</button>
                </th>
                <th aria-sort={sortKey === 'severity' ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => changeSort('severity')}>Severity {sortIcon('severity')}</button>
                </th>
                <th aria-sort={sortKey === 'statusLabel' ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => changeSort('statusLabel')}>Status {sortIcon('statusLabel')}</button>
                </th>
                <th>Assigned analyst</th>
                <th>Detection source</th>
                <th aria-sort={sortKey === 'date' ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => changeSort('date')}>Created {sortIcon('date')}</button>
                </th>
                <th aria-sort={sortKey === 'dateMod' ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => changeSort('dateMod')}>Updated {sortIcon('dateMod')}</button>
                </th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td className="table-message" colSpan={7}><span className="spinner" />Loading tickets from GLPI…</td></tr>
              ) : orderedTickets.length > 0 ? (
                orderedTickets.map((ticket) => (
                  <tr key={ticket.id}>
                    <td>
                      <button className="table-ticket-link" onClick={() => onOpen(ticket.id)}>
                        <span>{ticket.title}</span>
                        <ExternalLink size={14} aria-hidden="true" />
                      </button>
                      <span className="table-ticket-meta">
                        {ticket.incidentNumber ? 'Incident ' + ticket.incidentNumber : 'GLPI ticket #' + ticket.id}
                      </span>
                    </td>
                    <td>
                      <span className={'severity-pill ' + severityTone(ticket.severity)}>
                        <span className="severity-pip" aria-hidden="true" />
                        {ticket.severityLabel}
                      </span>
                      <span className="priority-caption">Priority: {ticket.priorityLabel}</span>
                    </td>
                    <td><span className={'status-pill ' + statusTone(ticket.status)}>{ticket.statusLabel}</span></td>
                    <td className="assigned-cell">
                      {ticket.assignees.length > 0
                        ? ticket.assignees.map((analyst) => analyst.name).join(', ')
                        : <span className="muted">Unassigned</span>}
                    </td>
                    <td>
                      <span className="source-label">
                        <span className="source-dot" aria-hidden="true" />
                        {ticket.isSocCase ? 'Microsoft Sentinel' : 'GLPI'}
                      </span>
                    </td>
                    <td><time dateTime={ticket.date}>{formatDate(ticket.date)}</time></td>
                    <td><time dateTime={ticket.dateMod}>{formatDate(ticket.dateMod)}</time></td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state table-empty">
                      <span className="empty-state__icon"><Search size={20} /></span>
                      <strong>No matching tickets</strong>
                      <span>Change the search or filters, or check that your GLPI profile can see this queue.</span>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="table-footer">
          <span>
            {loading ? 'Loading…' : 'Showing ' + first.toLocaleString() + '–' + last.toLocaleString() + ' of ' + total.toLocaleString()}
          </span>
          <div className="pagination" role="group" aria-label="Ticket queue pagination">
            <button
              className="icon-button"
              aria-label="Previous page"
              disabled={page <= 0 || loading}
              onClick={() => setPage((value) => Math.max(0, value - 1))}
            >
              <ChevronLeft size={17} />
            </button>
            <span>Page {Math.min(page + 1, pageCount)} of {pageCount}</span>
            <button
              className="icon-button"
              aria-label="Next page"
              disabled={page + 1 >= pageCount || loading}
              onClick={() => setPage((value) => Math.min(pageCount - 1, value + 1))}
            >
              <ChevronRight size={17} />
            </button>
          </div>
        </div>
      </section>
      <p className="queue-hint">Ticket changes, notes, assignment and closure are handled by GLPI’s existing ticket workflow.</p>
    </div>
  );
}
