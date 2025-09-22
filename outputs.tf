output "private_endpoints" {
  description = <<DESCRIPTION
  A map of the private endpoints created.
  DESCRIPTION
  value       = var.private_endpoints_manage_dns_zone_group ? azurerm_private_endpoint.this_managed_dns_zone_groups : azurerm_private_endpoint.this_unmanaged_dns_zone_groups
}

output "topic_id" {
  description = "The Azure Resource Manager ID of the Event Grid Topic."
  value       = azapi_resource.this.id
}

output "topic_location" {
  description = "The Azure location of the Event Grid Topic."
  value       = azapi_resource.this.location
}

output "topic_name" {
  description = "The name of the Event Grid Topic."
  value       = azapi_resource.this.name
}

output "topic_tags" {
  description = "The tags assigned to the Event Grid Topic."
  value       = azapi_resource.this.tags
}
