import type { SocTicket } from '../types';

export type SortKey = 'title' | 'severity' | 'statusLabel' | 'date' | 'dateMod';

export function filterTickets(
  tickets: SocTicket[],
  search: string,
  status: string,
  severity: string,
): SocTicket[] {
  const query = search.trim().toLocaleLowerCase();
  return tickets.filter((ticket) => {
    const matchesSearch =
      query.length === 0 ||
      [ticket.title, ticket.incidentNumber ?? '', ticket.sourceIp ?? '', ticket.summary]
        .join(' ')
        .toLocaleLowerCase()
        .includes(query);
    const matchesStatus = status === '' || String(ticket.status) === status;
    const matchesSeverity = severity === '' || ticket.severity === severity;
    return matchesSearch && matchesStatus && matchesSeverity;
  });
}

export function sortTickets(tickets: SocTicket[], key: SortKey, direction: 'asc' | 'desc'): SocTicket[] {
  return [...tickets].sort((left, right) => {
    const a = left[key] ?? '';
    const b = right[key] ?? '';
    const compare = String(a).localeCompare(String(b), undefined, { numeric: true });
    return direction === 'asc' ? compare : -compare;
  });
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value.replace(' ', 'T') + (value.includes('Z') ? '' : 'Z'));
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}

export function formatShortDate(value: string): string {
  const date = new Date(value + 'T00:00:00Z');
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short' }).format(date);
}

export function severityTone(severity: string | null): string {
  return severity ? 'severity-' + severity : 'severity-unknown';
}

export function statusTone(status: number): string {
  if (status === 1) return 'status-new';
  if (status === 5) return 'status-resolved';
  if (status === 6) return 'status-closed';
  if (status === 4) return 'status-waiting';
  return 'status-active';
}
