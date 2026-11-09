import type { Overview, SocTicketDetail, TicketPage } from './types';

async function request<T>(parameters: Record<string, string>): Promise<T> {
  const url = new URL(window.SOCOPS_CONFIG.apiUrl, window.location.origin);
  for (const [key, value] of Object.entries(parameters)) {
    url.searchParams.set(key, value);
  }

  const response = await fetch(url, {
    method: 'GET',
    credentials: 'same-origin',
    cache: 'no-store',
    headers: { Accept: 'application/json' },
  });
  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.includes('application/json')) {
    throw new Error('Your GLPI session has expired. Sign in again to continue.');
  }

  const result = (await response.json()) as { data?: T; error?: string };
  if (!response.ok || result.data === undefined) {
    throw new Error(result.error || 'GLPI could not load this data.');
  }
  return result.data;
}

export function fetchOverview(): Promise<Overview> {
  return request<Overview>({ action: 'overview' });
}

export function fetchTickets(options: {
  view: string;
  q: string;
  status: string;
  severity: string;
  start: number;
  limit: number;
}): Promise<TicketPage> {
  return request<TicketPage>({
    action: 'tickets',
    view: options.view,
    q: options.q,
    status: options.status,
    severity: options.severity,
    start: String(options.start),
    limit: String(options.limit),
  });
}

export function fetchTicket(id: number): Promise<SocTicketDetail> {
  return request<SocTicketDetail>({ action: 'ticket', id: String(id) });
}
