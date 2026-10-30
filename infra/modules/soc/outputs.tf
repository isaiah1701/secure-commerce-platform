output "rule_ids" {
  value = var.enable ? { for key, rule in azurerm_sentinel_alert_rule_scheduled.rule : key => rule.id } : {}
}
