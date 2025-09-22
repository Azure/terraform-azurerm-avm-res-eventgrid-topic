# Resolve the current subscription so we can construct a resource id for the resource group
data "azurerm_client_config" "current" {}

# Build the resource id of the resource group from the current subscription and the provided name.
# This avoids a data lookup that would fail when the resource group is also created in the same plan.
locals {
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

# Create the Event Grid Topic using the AzAPI provider and the 2025-02-15 API version
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.EventGrid/topics@2025-02-15"
  # Build the ARM body as an HCL object. Include identity at the top level of the ARM resource when requested.
  body = merge(
    { properties = merge(var.properties, local.topic_properties) },
    local.identity_block
  )
  create_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property = true
  read_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}

# Diagnostic settings for the Topic
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = coalesce(each.value.name, "${var.name}-diag-${each.key}")
  target_resource_id             = azapi_resource.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  # Destinations - set if provided by the caller
  log_analytics_workspace_id = each.value.workspace_resource_id
  partner_solution_id        = each.value.marketplace_partner_resource_id
  storage_account_id         = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = length(each.value.log_categories) > 0 ? each.value.log_categories : []

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_metric" {
    for_each = length(each.value.metric_categories) > 0 ? each.value.metric_categories : []

    content {
      category = enabled_metric.value
    }
  }
}

# required AVM resources interfaces (scoped to the created topic)
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azapi_resource.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
