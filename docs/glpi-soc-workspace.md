# GLPI SOC analyst workspace

The GLPI SOC workspace is an upgrade-safe GLPI 11 plugin that presents the
existing Sentinel-to-GLPI cases in a purpose-built analyst interface. GLPI
remains the source of truth for tickets, users, assets, notes, attachments,
status, and permissions.

## What analysts see

- **Overview:** open and new cases, assignments, resolved cases, severity,
  14-day ticket trend, recent activity, and analyst workload.
- **Incident queue:** searchable Sentinel cases with status and severity
  filters, sortable columns, and pagination.
- **Investigations:** open Sentinel cases that need analyst work.
- **My assigned tickets:** tickets assigned to the signed-in GLPI user.
- **Case workspace:** ticket description, source IP, affected asset, alert
  entities, MITRE ATT&CK identifier, Azure references, GLPI timeline, ticket
  participants, and resolution notes where those fields exist.
- **Reports & Analytics:** ticket status and trend views.

Counts and charts are calculated from tickets visible to the current GLPI
profile. If more than 500 visible tickets exist, the dashboard explains that
it uses the 500 most recent tickets; the queue remains paginated and searchable.
Missing fields are shown as unavailable instead of being inferred. GLPI's
existing ticket form remains the place to assign tickets, escalate, add notes,
change status, and record resolution.

Navigation to Assets, Knowledge Base, Administration, and Settings uses the
existing GLPI pages. Links are shown only when the GLPI profile has the
corresponding rights.

## Data access and safety

The plugin adds no database tables, columns, API credentials, or external
services. It uses GLPI's native ticket search and ticket classes, so list
results use GLPI's entity and ticket visibility rules. It checks access again
when opening a ticket and asks GLPI for timeline items with view-right checks
enabled. The JSON endpoint accepts GET requests only, requires the existing
GLPI login session, and is same-origin.

Ticket updates continue through GLPI's native form and permission checks. The
plugin does not create or edit tickets and does not modify the Sentinel,
Logic Apps, KQL, or duplicate-prevention workflows. Azure portal references
are rendered only when the ticket contains HTTPS links to portal.azure.com.

## Development and validation

The React + TypeScript interface lives in glpi-plugin/socops/ui; Vite builds
hashed static assets into glpi-plugin/socops/public, which is copied into the
GLPI image. The dashboard and JSON API use GLPI 11 plugin controllers, with
the existing-session API route at /plugins/socops/api. To validate the UI
locally, run:

    cd glpi-plugin/socops/ui
    npm ci --no-audit --no-fund
    npm test
    npm run lint
    npm run build

The Docker build also runs php -l against the plugin's PHP files.

## Deployment

.github/workflows/glpi-theme.yml builds and validates the UI, builds the
existing Dockerfile.glpi image in Azure Container Registry, and updates only
the GLPI Container App image. It waits for a healthy revision and an HTTPS
response from https://ticket.platf0rm.site/. No Terraform operation is part of
this workflow.

On the first start of the SOC-enabled image, the entrypoint waits for the
existing GLPI database, installs and activates the plugin through GLPI's
console, and stores a completion marker in the existing GLPI Files share.
Plugin installation adds GLPI's plugin registration only; it does not migrate
or rewrite ticket records. If bootstrap fails, GLPI continues starting and the
console message identifies the incomplete step for follow-up.

The prior container image remains available in ACR for rollback. A rollback is
an image-only Container App update; do not use Terraform to recreate the
database, Azure Files share, networking, or other lab resources.
