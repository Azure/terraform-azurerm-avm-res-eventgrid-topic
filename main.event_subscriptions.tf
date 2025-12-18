# Event subscriptions created via the root module's event_subscriptions variable
# This calls the event_subscription submodule for each subscription defined.
module "event_subscriptions" {
  source   = "./modules/event_subscription"
  for_each = var.event_subscriptions

  event_grid_topic_resource_id       = azapi_resource.this.id
  name                               = each.value.name
  dead_letter_destination            = each.value.dead_letter_destination
  dead_letter_with_resource_identity = each.value.dead_letter_with_resource_identity
  delivery_with_resource_identity    = each.value.delivery_with_resource_identity
  # Pass through all configuration
  destination           = each.value.destination
  event_delivery_schema = each.value.event_delivery_schema
  expiration_time_utc   = each.value.expiration_time_utc
  filter                = each.value.filter
  labels                = each.value.labels
  retry_policy          = each.value.retry_policy
}
