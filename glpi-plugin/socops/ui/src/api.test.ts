import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchOverview, fetchTicket, fetchTickets } from './api';
import type { Overview, SocTicketDetail, TicketPage } from './types';

const apiUrl = '/plugins/socops/api';

function responseWith(data: unknown, status = 200): Response {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

describe('GLPI SOC API client', () => {
  beforeEach(() => {
    vi.stubGlobal('window', {
      SOCOPS_CONFIG: { apiUrl, currentUser: 'Analyst' },
      location: { origin: 'https://ticket.platf0rm.site' },
    });
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('loads the overview through the current GLPI session', async () => {
    const overview = { openCases: 3 } as Overview;
    vi.mocked(fetch).mockResolvedValue(responseWith(overview));

    await expect(fetchOverview()).resolves.toEqual(overview);
    const [requestUrl, requestOptions] = vi.mocked(fetch).mock.calls[0];
    expect(String(requestUrl)).toBe('https://ticket.platf0rm.site/plugins/socops/api?action=overview');
    expect(requestOptions).toMatchObject({
      method: 'GET',
      credentials: 'same-origin',
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    });
  });

  it('sends queue search, filters, and pagination to GLPI', async () => {
    const page = { tickets: [], total: 0, start: 25, limit: 25, currentUserId: 4 } as TicketPage;
    vi.mocked(fetch).mockResolvedValue(responseWith(page));

    await expect(fetchTickets({
      view: 'investigations',
      q: 'spray',
      status: '2',
      severity: 'high',
      start: 25,
      limit: 25,
    })).resolves.toEqual(page);

    const requestUrl = new URL(vi.mocked(fetch).mock.calls[0][0] as string);
    expect(requestUrl.searchParams.get('view')).toBe('investigations');
    expect(requestUrl.searchParams.get('q')).toBe('spray');
    expect(requestUrl.searchParams.get('status')).toBe('2');
    expect(requestUrl.searchParams.get('severity')).toBe('high');
    expect(requestUrl.searchParams.get('start')).toBe('25');
    expect(requestUrl.searchParams.get('limit')).toBe('25');
  });

  it('loads one ticket and surfaces GLPI authorization errors', async () => {
    const ticket = { id: 46, canUpdate: false } as SocTicketDetail;
    vi.mocked(fetch).mockResolvedValueOnce(responseWith(ticket));
    await expect(fetchTicket(46)).resolves.toEqual(ticket);

    vi.mocked(fetch).mockResolvedValueOnce(new Response(
      JSON.stringify({ error: 'Your GLPI profile does not allow access to tickets.' }),
      { status: 403, headers: { 'Content-Type': 'application/json' } },
    ));
    await expect(fetchOverview()).rejects.toThrow('Your GLPI profile does not allow access to tickets.');
  });
});
