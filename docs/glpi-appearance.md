# GLPI appearance

The GLPI container includes a GLPI 11 custom palette named **SOC Ops**. Its
SCSS lives in the image and uses GLPI's supported `GLPI_THEMES_DIR` setting;
deployment does not write into the persisted Azure Files mount.
The visual treatment also applies to the existing Aurora palette, so it appears
immediately without changing a stored GLPI preference. It does not edit the
GLPI database, existing ticket content, or Terraform configuration.

To preview and use it for your account, open **Preferences → Personalization**
and choose **SOC Ops** under **Color palette** if you want the palette available
as an explicit choice. The current theme preference is left unchanged by
deployment. It uses a clean slate-and-teal interface and keeps GLPI's status
colors intact.

The ticket view also has a narrow-screen layout: ticket details and timeline use
the available width, timeline entries and long evidence wrap, and the action bar
stacks for touch use. Ticket controls keep a 44 px target and 16 px input text,
and keyboard focus remains visible. These rules apply to both Aurora and SOC
Ops without changing ticket data or user preferences.

The SOC Analyst Platform plugin adds a separate dark-first analyst workspace
alongside GLPI's standard interface. See docs/glpi-soc-workspace.md for its
data sources, access checks, analyst views, build, and deployment behavior.

Changes to `Dockerfile.glpi`, `glpi-theme/`, or `glpi-plugin/socops/` build and
deploy only the GLPI container app through `.github/workflows/glpi-theme.yml`;
the commerce app and infrastructure deployment are not part of this workflow.
