import { useEffect, useState } from 'react';
import {
  ArrowLeft,
  ArrowUpRight,
  CheckCircle2,
  Clock3,
  ExternalLink,
  FileSearch,
  Flag,
  Globe2,
  Link2,
  LockKeyhole,
  MessageSquareText,
  Server,
  Shield,
  UserRound,
  Users,
} from 'lucide-react';
import { fetchTicket } from '../api';
import { formatDate, severityTone, statusTone } from '../lib/tickets';
import type { SocTicketDetail } from '../types';

interface TicketWorkspaceProps {
  id: number;
  onBack: () => void;
}

export function TicketWorkspace({ id, onBack }: TicketWorkspaceProps) {
  const [response, setResponse] = useState<{
    id: number;
    ticket?: SocTicketDetail;
    error?: string;
  }>({ id: 0 });
  const loading = response.id !== id;
  const ticket = response.id === id ? response.ticket ?? null : null;
  const error = response.id === id ? response.error ?? '' : '';

  useEffect(() => {
    const controller = new AbortController();
    fetchTicket(id)
      .then((result) => {
        if (!controller.signal.aborted) setResponse({ id, ticket: result });
      })
      .catch((reason: unknown) => {
        if (controller.signal.aborted) return;
        setResponse({
          id,
          error: reason instanceof Error ? reason.message : 'GLPI could not load this ticket.',
        });
      });
    return () => controller.abort();
  }, [id]);

  if (loading) {
    return <div className="panel loading-panel" role="status"><span className="spinner" />Loading ticket details…</div>;
  }
  if (error || !ticket) {
    return (
      <section className="panel detail-error" role="alert">
        <span className="empty-state__icon"><FileSearch size={22} /></span>
        <h2>Ticket unavailable</h2>
        <p>{error || 'This ticket is not available to your GLPI profile.'}</p>
        <button className="primary-button" onClick={onBack}><ArrowLeft size={16} /> Back to queue</button>
      </section>
    );
  }

  const ticketUrl = '/front/ticket.form.php?id=' + ticket.id;
  const iocs = [
    ticket.sourceIp ? { label: 'Source IP', value: ticket.sourceIp, icon: Globe2 } : null,
    ticket.incidentGuid ? { label: 'Sentinel incident ID', value: ticket.incidentGuid, icon: Link2 } : null,
    ticket.mitre ? { label: 'MITRE ATT&CK', value: ticket.mitre, icon: Shield } : null,
  ].filter((item): item is { label: string; value: string; icon: typeof Globe2 } => item !== null);

  return (
    <div className="page-stack">
      <button className="back-link" onClick={onBack}><ArrowLeft size={16} /> Back to incident queue</button>

      <section className="case-hero panel">
        <div className="case-hero__main">
          <div className="case-title-row">
            <span className="case-shield"><Shield size={19} /></span>
            <span className="eyebrow">GLPI ticket #{ticket.id}{ticket.incidentNumber ? ' · Sentinel incident ' + ticket.incidentNumber : ''}</span>
          </div>
          <h2>{ticket.title}</h2>
          <p>{ticket.summary || 'No incident summary was provided in the GLPI ticket.'}</p>
          <div className="case-badges">
            <span className={'severity-pill ' + severityTone(ticket.severity)}>
              <span className="severity-pip" aria-hidden="true" />{ticket.severityLabel}
            </span>
            <span className={'status-pill ' + statusTone(ticket.status)}>{ticket.statusLabel}</span>
            <span className="priority-pill">Priority: {ticket.priorityLabel}</span>
          </div>
        </div>
        <div className="case-hero__actions">
          <a className="primary-button" href={ticketUrl}>
            {ticket.canUpdate ? 'Continue investigation in GLPI' : 'Open ticket in GLPI'}
            <ArrowUpRight size={16} />
          </a>
          <span>GLPI enforces your ticket permissions for every update.</span>
        </div>
      </section>

      <div className="detail-grid">
        <main className="detail-main">
          <section className="panel detail-section">
            <div className="panel-heading">
              <div>
                <span className="eyebrow">Case context</span>
                <h2>Incident summary</h2>
              </div>
              <span className="panel-icon"><FileSearch size={17} /></span>
            </div>
            {ticket.description ? (
              <div className="incident-description">{ticket.description}</div>
            ) : (
              <div className="empty-inline">The ticket does not include a description.</div>
            )}
            <div className="context-grid">
              <ContextField label="Detection source" value={ticket.isSocCase ? 'Microsoft Sentinel' : 'GLPI ticket'} />
              <ContextField label="Detection rule" value={ticket.detectionRule || 'Not provided'} />
              <ContextField label="Created" value={formatDate(ticket.date)} />
              <ContextField label="Last updated" value={formatDate(ticket.dateMod)} />
            </div>
          </section>

          <section className="panel detail-section">
            <div className="panel-heading">
              <div>
                <span className="eyebrow">Investigation record</span>
                <h2>Event timeline</h2>
              </div>
              <span className="panel-icon"><Clock3 size={17} /></span>
            </div>
            {ticket.timeline.length > 0 ? (
              <ol className="timeline-list">
                {ticket.timeline.map((event) => (
                  <li key={event.id + event.date}>
                    <span className="timeline-marker" aria-hidden="true" />
                    <div className="timeline-entry">
                      <div className="timeline-entry__header">
                        <strong>{event.type}</strong>
                        <time dateTime={event.date}>{formatDate(event.date)}</time>
                      </div>
                      <span className="timeline-author"><UserRound size={13} />{event.author}</span>
                      <p>{event.content}</p>
                    </div>
                  </li>
                ))}
              </ol>
            ) : (
              <div className="empty-state empty-state--compact">
                <span className="empty-state__icon"><MessageSquareText size={21} /></span>
                <strong>No investigation notes recorded</strong>
                <span>Add a follow-up through the existing GLPI ticket page to document your findings.</span>
              </div>
            )}
          </section>

          <section className="panel detail-section solution-section">
            <div className="panel-heading">
              <div>
                <span className="eyebrow">Disposition</span>
                <h2>Resolution and closure</h2>
              </div>
              <span className="panel-icon panel-icon--green"><CheckCircle2 size={17} /></span>
            </div>
            {ticket.solution ? (
              <div className="incident-description">{ticket.solution}</div>
            ) : (
              <div className="empty-inline">No resolution note is recorded on this ticket.</div>
            )}
            <a className="inline-link" href={ticketUrl}>
              Record disposition in GLPI <ExternalLink size={14} />
            </a>
          </section>
        </main>

        <aside className="detail-aside">
          <section className="panel aside-section">
            <div className="panel-heading">
              <div><span className="eyebrow">Entities</span><h2>What is involved</h2></div>
            </div>
            <div className="entity-card">
              <Server size={16} />
              <div><span>Affected asset</span><strong>{ticket.affectedAssets.length
                ? ticket.affectedAssets.map((asset) => asset.name).join(', ')
                : ticket.affectedAsset || 'Not identified in ticket'}</strong></div>
            </div>
            <div className="entity-card">
              <Users size={16} />
              <div>
                <span>Accounts named in the alert</span>
                <strong>{ticket.entities.length ? ticket.entities.join(', ') : 'Not identified in ticket'}</strong>
              </div>
            </div>
            <div className="entity-card">
              <UserRound size={16} />
              <div>
                <span>Ticket participants</span>
                <strong>
                  {[
                    ...ticket.requester.map((person) => 'Requester: ' + person.name),
                    ...ticket.assignees.map((person) => 'Assigned analyst: ' + person.name),
                  ].join(' · ') || 'No participants recorded'}
                </strong>
              </div>
            </div>
          </section>

          <section className="panel aside-section">
            <div className="panel-heading">
              <div><span className="eyebrow">Evidence</span><h2>Indicators and references</h2></div>
            </div>
            {iocs.length > 0 ? (
              <ul className="ioc-list">
                {iocs.map((ioc) => {
                  const Icon = ioc.icon;
                  return (
                    <li key={ioc.label}>
                      <span className="ioc-icon"><Icon size={15} /></span>
                      <span><small>{ioc.label}</small><strong>{ioc.value}</strong></span>
                    </li>
                  );
                })}
              </ul>
            ) : (
              <div className="empty-inline">No indicators were included in the ticket.</div>
            )}
            <div className="reference-list">
              <ReferenceLink href={ticketUrl} label="Open the GLPI ticket" />
              {ticket.references?.map((reference) => (
                <ReferenceLink key={reference.href} href={reference.href} label={reference.label} external />
              ))}
            </div>
          </section>

          <section className="panel action-panel">
            <span className="action-icon"><LockKeyhole size={17} /></span>
            <h2>Analyst actions</h2>
            <p>Assignment, escalation, investigation notes and status transitions stay inside GLPI’s permission-checked ticket workflow.</p>
            <a className="secondary-button" href={ticketUrl}>
              {ticket.canUpdate ? 'Update ticket or add note' : 'View ticket'}
              <ArrowUpRight size={15} />
            </a>
            {ticket.canUpdate ? (
              <span className="action-caption"><Flag size={13} /> Your GLPI role can update this ticket.</span>
            ) : (
              <span className="action-caption"><LockKeyhole size={13} /> Your GLPI role is read-only for this ticket.</span>
            )}
          </section>
        </aside>
      </div>
    </div>
  );
}

function ContextField({ label, value }: { label: string; value: string }) {
  return <div className="context-field"><span>{label}</span><strong>{value}</strong></div>;
}

function ReferenceLink({ href, label, external = false }: { href: string; label: string; external?: boolean }) {
  return (
    <a href={href} target={external ? '_blank' : undefined} rel={external ? 'noopener noreferrer' : undefined}>
      <span>{label}</span><ExternalLink size={14} aria-hidden="true" />
    </a>
  );
}
