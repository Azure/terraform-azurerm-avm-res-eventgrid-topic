locals {
  private_endpoint_parent_ids = {
    for k, v in var.private_endpoints : k => v.resource_group_name == null ? var.parent_id : (
      can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", v.resource_group_name)) ? v.resource_group_name :
      "/subscriptions/${provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id}/resourceGroups/${v.resource_group_name}"
    )
  }
  private_endpoints = {
    for k, v in var.private_endpoints : k => merge(v, {
      lock = v.lock == null ? (var.lock == null ? null : {
        kind  = var.lock.kind
        name  = var.lock.name
        notes = null
      }) : (v.lock.kind == "None" ? null : v.lock)
      network_interface_name = coalesce(v.network_interface_name, "nic-${coalesce(v.name, "pe-${var.name}-${k}")}")
    })
  }
}
