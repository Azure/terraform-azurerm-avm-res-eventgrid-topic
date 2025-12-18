output "name" {
  description = "The name of the event subscription."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full event subscription resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the event subscription."
  value       = azapi_resource.this.id
}
