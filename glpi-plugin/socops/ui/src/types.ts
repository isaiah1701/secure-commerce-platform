export type Severity = 'critical' | 'high' | 'medium' | 'low';

export interface Analyst {
  id: number;
  name: string;
}

export interface SocTicket {
  id: number;
  title: string;
  status: number;
  statusLabel: string;
  priority: number;
  priorityLabel: string;
  severity: Severity | null;
  severityLabel: string;
  date: string;
  dateMod: string;
  isSocCase: boolean;
  incidentNumber: string | null;
  incidentGuid: string | null;
  detectionRule: string;
  sourceIp: string | null;
  affectedAsset: string | null;
  entities: string[];
  mitre: string | null;
  assignees: Analyst[];
  isAssignedToMe: boolean;
  summary: string;
}

export interface TimelineEvent {
  id: number;
  type: string;
  date: string;
  author: string;
  content: string;
}

export interface SocTicketDetail extends SocTicket {
  canUpdate: boolean;
  requester: Analyst[];
  affectedAssets: Array<{ type: string; name: string }>;
  description: string;
  references: Array<{ href: string; label: string }>;
  solution: string;
  timeline: TimelineEvent[];
}

export interface TrendPoint {
  date: string;
  count: number;
}

export interface WorkloadPoint {
  name: string;
  count: number;
}

export interface Overview {
  generatedAt: string;
  currentUser: string;
  currentUserId: number;
  openCases: number;
  awaitingTriage: number;
  assignedCases: number;
  resolvedLast30d: number;
  severity: Record<'critical' | 'high' | 'medium' | 'low' | 'unknown', number>;
  statusDistribution: Record<string, number>;
  trend: TrendPoint[];
  workload: WorkloadPoint[];
  recentActivity: SocTicket[];
  totalVisibleTickets: number;
  sampled: boolean;
  sampleSize: number;
  capabilities: {
    assets: boolean;
    knowledgeBase: boolean;
    administration: boolean;
  };
}

export interface TicketPage {
  tickets: SocTicket[];
  total: number;
  start: number;
  limit: number;
  currentUserId: number;
}

export interface ApiError {
  error: string;
}

declare global {
  interface Window {
    SOCOPS_CONFIG: {
      apiUrl: string;
      currentUser: string;
    };
  }
}
