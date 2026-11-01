# GLPI appearance

The GLPI container includes a GLPI 11 custom palette named **SOC Ops**. Its
SCSS is copied into GLPI's supported custom-theme directory at container start;
it does not edit the GLPI database, existing ticket content, or Terraform
configuration.

To preview and use it for your account, open **Preferences → Personalization**
and choose **SOC Ops** under **Color palette**. The current theme preference is
left unchanged by deployment. The palette uses a dark slate surface with teal
accents and keeps GLPI's status colors intact.

Changes to `Dockerfile.glpi` or `glpi-theme/` build and deploy only the GLPI
container app through `.github/workflows/glpi-theme.yml`; the commerce app and
infrastructure deployment are not part of this workflow.
