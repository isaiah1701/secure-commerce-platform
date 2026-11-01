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

Changes to `Dockerfile.glpi` or `glpi-theme/` build and deploy only the GLPI
container app through `.github/workflows/glpi-theme.yml`; the commerce app and
infrastructure deployment are not part of this workflow.
