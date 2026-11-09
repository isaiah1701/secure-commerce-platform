import { describe, expect, it } from 'vitest';
import { filterTickets, formatDate, severityTone, sortTickets, statusTone } from './tickets';
import type { SocTicket } from '../types';

const tickets: SocTicket[] = [
  {
    id: 1,
    title: 'Repeated failed sign-ins — Sentinel incident 12',
    status: 1,
    statusLabel: 'New',
    priority: 4,
    priorityLabel: 'High',
    severity: 'high',
    severityLabel: 'High',
    date: '2026-11-09 10:00:00',
    dateMod: '2026-11-09 10:05:00',
    isSocCase: true,
    incidentNumber: '12',
    incidentGuid: null,
    detectionRule: 'Repeated failed sign-ins',
    sourceIp: '203.0.113.8',
    affectedAsset: null,
    entities: [],
    mitre: 'T1110.003',
    assignees: [],
    isAssignedToMe: false,
    summary: 'Review the failed sign-ins.',
  },
  {
    id: 2,
    title: 'API availability',
    status: 5,
    statusLabel: 'Resolved',
    priority: 2,
    priorityLabel: 'Low',
    severity: null,
    severityLabel: 'Not provided',
    date: '2026-11-08 10:00:00',
    dateMod: '2026-11-08 11:00:00',
    isSocCase: false,
    incidentNumber: null,
    incidentGuid: null,
    detectionRule: 'API availability',
    sourceIp: null,
    affectedAsset: null,
    entities: [],
    mitre: null,
    assignees: [],
    isAssignedToMe: false,
    summary: 'A routine service ticket.',
  },
];

describe('ticket table helpers', () => {
  it('filters by case-insensitive search, status and recorded severity', () => {
    expect(filterTickets(tickets, 'sentinel', '', '')).toHaveLength(1);
    expect(filterTickets(tickets, '', '5', '')[0].id).toBe(2);
    expect(filterTickets(tickets, '', '', 'high')[0].id).toBe(1);
    expect(filterTickets(tickets, '', '', 'critical')).toHaveLength(0);
  });

  it('sorts values without mutating the source list', () => {
    expect(sortTickets(tickets, 'title', 'asc').map((ticket) => ticket.id)).toEqual([2, 1]);
    expect(tickets.map((ticket) => ticket.id)).toEqual([1, 2]);
  });

  it('formats invalid and valid timestamps safely', () => {
    expect(formatDate('not-a-date')).toBe('—');
    expect(formatDate('2026-11-09 10:00:00')).not.toBe('—');
  });

  it('exposes distinct severity and status styles', () => {
    expect(severityTone('high')).toBe('severity-high');
    expect(severityTone(null)).toBe('severity-unknown');
    expect(statusTone(1)).toBe('status-new');
    expect(statusTone(5)).toBe('status-resolved');
  });
});
