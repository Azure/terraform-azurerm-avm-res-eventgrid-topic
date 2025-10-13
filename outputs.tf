# output "private_endpoint_network_interface_ids" {
#   description = <<DESCRIPTION
# A map of the private endpoints created to their network interface ids.
# DESCRIPTION
#   value       = { for k, v in azapi_resource.private_endpoints : k => v.output.properties.networkInterfaces[*].id }
# }

# output "private_endpoint_resource_ids" {
#   description = <<DESCRIPTION
# A map of the private endpoints created to their resource ids.
# DESCRIPTION
#   value       = { for k, v in azapi_resource.private_endpoints : k => v.id }
# }

output "event_subscription_ids" {
  description = <<DESCRIPTION
A map of event subscription keys to their Azure Resource Manager IDs.
DESCRIPTION
  value       = { for k, v in azapi_resource.event_subscriptions : k => v.id }
}

output "event_subscription_names" {
  description = <<DESCRIPTION
A map of event subscription keys to their names.
DESCRIPTION
  value       = { for k, v in azapi_resource.event_subscriptions : k => v.name }
}

output "name" {
  description = <<DESCRIPTION
The name of the resource.
DESCRIPTION
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = <<DESCRIPTION
The Azure Resource Manager ID of the primary resource created by this module.
DESCRIPTION
  value       = azapi_resource.this.id
}

output "topic_id" {
  description = <<DESCRIPTION
The Azure Resource Manager ID of the Event Grid Topic.
DESCRIPTION
  value       = azapi_resource.this.id
}

output "topic_location" {
  description = <<DESCRIPTION
The Azure location of the Event Grid Topic.
DESCRIPTION
  value       = azapi_resource.this.location
}

output "topic_name" {
  description = <<DESCRIPTION
The name of the Event Grid Topic.
DESCRIPTION
  value       = azapi_resource.this.name
}

output "topic_tags" {
  description = <<DESCRIPTION
The tags assigned to the Event Grid Topic.
DESCRIPTION
  value       = azapi_resource.this.tags
}
