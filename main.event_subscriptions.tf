resource "azapi_resource" "event_subscriptions" {
  for_each = var.event_subscriptions

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = "Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15"
  body = jsondecode(jsonencode({
    properties = merge(
      {
        destination = each.value.destination
      },
      each.value.delivery_with_resource_identity != null ? {
        deliveryWithResourceIdentity = each.value.delivery_with_resource_identity
      } : {},
      each.value.dead_letter_destination != null ? {
        deadLetterDestination = each.value.dead_letter_destination
      } : {},
      each.value.dead_letter_with_resource_identity != null ? {
        deadLetterWithResourceIdentity = each.value.dead_letter_with_resource_identity
      } : {},
      each.value.event_delivery_schema != null ? {
        eventDeliverySchema = each.value.event_delivery_schema
      } : {},
      each.value.expiration_time_utc != null ? {
        expirationTimeUtc = each.value.expiration_time_utc
      } : {},
      each.value.filter != null ? {
        filter = each.value.filter
      } : {},
      each.value.labels != null ? {
        labels = each.value.labels
      } : {},
      each.value.retry_policy != null ? {
        retryPolicy = each.value.retry_policy
      } : {}
    )
  }))
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property      = true
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  schema_validation_enabled = false
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}
