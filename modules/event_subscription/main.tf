# Event Subscription submodule for Event Grid Topics
# This submodule can be used to create event subscriptions on existing Event Grid Topics
# that may not be managed by the parent module.

locals {
  # Build delivery attribute mappings in Azure API format
  delivery_attribute_mappings = var.destination != null ? [
    for mapping in coalesce(
      var.destination.azure_function.delivery_attribute_mappings,
      var.destination.event_hub.delivery_attribute_mappings,
      var.destination.hybrid_connection.delivery_attribute_mappings,
      var.destination.service_bus_queue.delivery_attribute_mappings,
      var.destination.service_bus_topic.delivery_attribute_mappings,
      var.destination.webhook.delivery_attribute_mappings,
      []
      ) : {
      name = mapping.name
      type = mapping.type
      properties = mapping.type == "Static" ? {
        value    = mapping.value
        isSecret = mapping.is_secret
        } : {
        sourceField = mapping.source_field
      }
    }
  ] : []
  # Build delivery attribute mappings for delivery_with_resource_identity
  delivery_identity_attribute_mappings = var.delivery_with_resource_identity != null ? [
    for mapping in coalesce(
      var.delivery_with_resource_identity.destination.azure_function.delivery_attribute_mappings,
      var.delivery_with_resource_identity.destination.event_hub.delivery_attribute_mappings,
      var.delivery_with_resource_identity.destination.hybrid_connection.delivery_attribute_mappings,
      var.delivery_with_resource_identity.destination.service_bus_queue.delivery_attribute_mappings,
      var.delivery_with_resource_identity.destination.service_bus_topic.delivery_attribute_mappings,
      var.delivery_with_resource_identity.destination.webhook.delivery_attribute_mappings,
      []
      ) : {
      name = mapping.name
      type = mapping.type
      properties = mapping.type == "Static" ? {
        value    = mapping.value
        isSecret = mapping.is_secret
        } : {
        sourceField = mapping.source_field
      }
    }
  ] : []
  delivery_identity_azure_function_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.azure_function != null ? {
    resourceId                    = var.delivery_with_resource_identity.destination.azure_function.resource_id
    maxEventsPerBatch             = var.delivery_with_resource_identity.destination.azure_function.max_events_per_batch
    preferredBatchSizeInKilobytes = var.delivery_with_resource_identity.destination.azure_function.preferred_batch_size_in_kilobytes
    deliveryAttributeMappings     = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  # Determine endpoint type for delivery_with_resource_identity
  delivery_identity_endpoint_type = (
    var.delivery_with_resource_identity == null ? null :
    var.delivery_with_resource_identity.destination.azure_function != null ? "AzureFunction" :
    var.delivery_with_resource_identity.destination.event_hub != null ? "EventHub" :
    var.delivery_with_resource_identity.destination.hybrid_connection != null ? "HybridConnection" :
    var.delivery_with_resource_identity.destination.monitor_alert != null ? "MonitorAlert" :
    var.delivery_with_resource_identity.destination.namespace_topic != null ? "NamespaceTopic" :
    var.delivery_with_resource_identity.destination.service_bus_queue != null ? "ServiceBusQueue" :
    var.delivery_with_resource_identity.destination.service_bus_topic != null ? "ServiceBusTopic" :
    var.delivery_with_resource_identity.destination.storage_queue != null ? "StorageQueue" :
    var.delivery_with_resource_identity.destination.webhook != null ? "WebHook" : null
  )
  delivery_identity_event_hub_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.event_hub != null ? {
    resourceId                = var.delivery_with_resource_identity.destination.event_hub.resource_id
    deliveryAttributeMappings = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  delivery_identity_hybrid_connection_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.hybrid_connection != null ? {
    resourceId                = var.delivery_with_resource_identity.destination.hybrid_connection.resource_id
    deliveryAttributeMappings = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  delivery_identity_monitor_alert_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.monitor_alert != null ? {
    severity     = var.delivery_with_resource_identity.destination.monitor_alert.severity
    actionGroups = var.delivery_with_resource_identity.destination.monitor_alert.action_groups
    description  = var.delivery_with_resource_identity.destination.monitor_alert.description
  } : null
  delivery_identity_namespace_topic_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.namespace_topic != null ? {
    resourceId = var.delivery_with_resource_identity.destination.namespace_topic.resource_id
  } : null
  delivery_identity_properties = var.delivery_with_resource_identity == null ? null : (
    length(local.delivery_identity_properties_list) > 0 ? jsondecode(local.delivery_identity_properties_list[0]) : null
  )
  # Lookup delivery_with_resource_identity properties - use compact() and jsonencode/jsondecode
  # to avoid type unification issues by selecting from a list instead of chained conditionals
  delivery_identity_properties_list = compact([
    local.delivery_identity_storage_queue_props != null ? jsonencode(local.delivery_identity_storage_queue_props) : "",
    local.delivery_identity_azure_function_props != null ? jsonencode(local.delivery_identity_azure_function_props) : "",
    local.delivery_identity_event_hub_props != null ? jsonencode(local.delivery_identity_event_hub_props) : "",
    local.delivery_identity_hybrid_connection_props != null ? jsonencode(local.delivery_identity_hybrid_connection_props) : "",
    local.delivery_identity_monitor_alert_props != null ? jsonencode(local.delivery_identity_monitor_alert_props) : "",
    local.delivery_identity_namespace_topic_props != null ? jsonencode(local.delivery_identity_namespace_topic_props) : "",
    local.delivery_identity_service_bus_queue_props != null ? jsonencode(local.delivery_identity_service_bus_queue_props) : "",
    local.delivery_identity_service_bus_topic_props != null ? jsonencode(local.delivery_identity_service_bus_topic_props) : "",
    local.delivery_identity_webhook_props != null ? jsonencode(local.delivery_identity_webhook_props) : "",
  ])
  delivery_identity_service_bus_queue_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.service_bus_queue != null ? {
    resourceId                = var.delivery_with_resource_identity.destination.service_bus_queue.resource_id
    deliveryAttributeMappings = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  delivery_identity_service_bus_topic_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.service_bus_topic != null ? {
    resourceId                = var.delivery_with_resource_identity.destination.service_bus_topic.resource_id
    deliveryAttributeMappings = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  # Build delivery_with_resource_identity properties - separate locals per type
  delivery_identity_storage_queue_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.storage_queue != null ? {
    resourceId                      = var.delivery_with_resource_identity.destination.storage_queue.resource_id
    queueName                       = var.delivery_with_resource_identity.destination.storage_queue.queue_name
    queueMessageTimeToLiveInSeconds = var.delivery_with_resource_identity.destination.storage_queue.queue_message_time_to_live_in_seconds
  } : null
  delivery_identity_webhook_props = var.delivery_with_resource_identity != null && var.delivery_with_resource_identity.destination.webhook != null ? {
    endpointUrl                            = var.delivery_with_resource_identity.destination.webhook.endpoint_url
    maxEventsPerBatch                      = var.delivery_with_resource_identity.destination.webhook.max_events_per_batch
    preferredBatchSizeInKilobytes          = var.delivery_with_resource_identity.destination.webhook.preferred_batch_size_in_kilobytes
    azureActiveDirectoryTenantId           = var.delivery_with_resource_identity.destination.webhook.azure_active_directory_tenant_id
    azureActiveDirectoryApplicationIdOrUri = var.delivery_with_resource_identity.destination.webhook.azure_active_directory_app_id_or_uri
    minimumTlsVersionAllowed               = var.delivery_with_resource_identity.destination.webhook.minimum_tls_version_allowed
    deliveryAttributeMappings              = length(local.delivery_identity_attribute_mappings) > 0 ? local.delivery_identity_attribute_mappings : null
  } : null
  dest_azure_function_props = var.destination != null && var.destination.azure_function != null ? {
    resourceId                    = var.destination.azure_function.resource_id
    maxEventsPerBatch             = var.destination.azure_function.max_events_per_batch
    preferredBatchSizeInKilobytes = var.destination.azure_function.preferred_batch_size_in_kilobytes
    deliveryAttributeMappings     = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  dest_event_hub_props = var.destination != null && var.destination.event_hub != null ? {
    resourceId                = var.destination.event_hub.resource_id
    deliveryAttributeMappings = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  dest_hybrid_connection_props = var.destination != null && var.destination.hybrid_connection != null ? {
    resourceId                = var.destination.hybrid_connection.resource_id
    deliveryAttributeMappings = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  dest_monitor_alert_props = var.destination != null && var.destination.monitor_alert != null ? {
    severity     = var.destination.monitor_alert.severity
    actionGroups = var.destination.monitor_alert.action_groups
    description  = var.destination.monitor_alert.description
  } : null
  dest_namespace_topic_props = var.destination != null && var.destination.namespace_topic != null ? {
    resourceId = var.destination.namespace_topic.resource_id
  } : null
  dest_service_bus_queue_props = var.destination != null && var.destination.service_bus_queue != null ? {
    resourceId                = var.destination.service_bus_queue.resource_id
    deliveryAttributeMappings = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  dest_service_bus_topic_props = var.destination != null && var.destination.service_bus_topic != null ? {
    resourceId                = var.destination.service_bus_topic.resource_id
    deliveryAttributeMappings = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  # Build destination properties - separate locals per type to avoid Terraform type unification
  dest_storage_queue_props = var.destination != null && var.destination.storage_queue != null ? {
    resourceId                      = var.destination.storage_queue.resource_id
    queueName                       = var.destination.storage_queue.queue_name
    queueMessageTimeToLiveInSeconds = var.destination.storage_queue.queue_message_time_to_live_in_seconds
  } : null
  dest_webhook_props = var.destination != null && var.destination.webhook != null ? {
    endpointUrl                            = var.destination.webhook.endpoint_url
    maxEventsPerBatch                      = var.destination.webhook.max_events_per_batch
    preferredBatchSizeInKilobytes          = var.destination.webhook.preferred_batch_size_in_kilobytes
    azureActiveDirectoryTenantId           = var.destination.webhook.azure_active_directory_tenant_id
    azureActiveDirectoryApplicationIdOrUri = var.destination.webhook.azure_active_directory_app_id_or_uri
    minimumTlsVersionAllowed               = var.destination.webhook.minimum_tls_version_allowed
    deliveryAttributeMappings              = length(local.delivery_attribute_mappings) > 0 ? local.delivery_attribute_mappings : null
  } : null
  # Determine endpoint type for direct destination
  destination_endpoint_type = (
    var.destination == null ? null :
    var.destination.azure_function != null ? "AzureFunction" :
    var.destination.event_hub != null ? "EventHub" :
    var.destination.hybrid_connection != null ? "HybridConnection" :
    var.destination.monitor_alert != null ? "MonitorAlert" :
    var.destination.namespace_topic != null ? "NamespaceTopic" :
    var.destination.service_bus_queue != null ? "ServiceBusQueue" :
    var.destination.service_bus_topic != null ? "ServiceBusTopic" :
    var.destination.storage_queue != null ? "StorageQueue" :
    var.destination.webhook != null ? "WebHook" : null
  )
  destination_properties = var.destination == null ? null : (
    length(local.destination_properties_list) > 0 ? jsondecode(local.destination_properties_list[0]) : null
  )
  # Lookup destination properties - use compact() and one() to avoid type unification issues
  # by selecting from a list instead of chained conditionals
  destination_properties_list = compact([
    local.dest_storage_queue_props != null ? jsonencode(local.dest_storage_queue_props) : "",
    local.dest_azure_function_props != null ? jsonencode(local.dest_azure_function_props) : "",
    local.dest_event_hub_props != null ? jsonencode(local.dest_event_hub_props) : "",
    local.dest_hybrid_connection_props != null ? jsonencode(local.dest_hybrid_connection_props) : "",
    local.dest_monitor_alert_props != null ? jsonencode(local.dest_monitor_alert_props) : "",
    local.dest_namespace_topic_props != null ? jsonencode(local.dest_namespace_topic_props) : "",
    local.dest_service_bus_queue_props != null ? jsonencode(local.dest_service_bus_queue_props) : "",
    local.dest_service_bus_topic_props != null ? jsonencode(local.dest_service_bus_topic_props) : "",
    local.dest_webhook_props != null ? jsonencode(local.dest_webhook_props) : "",
  ])
  # Transform filter configuration
  filter = var.filter != null ? {
    subjectBeginsWith               = var.filter.subject_begins_with
    subjectEndsWith                 = var.filter.subject_ends_with
    includedEventTypes              = var.filter.included_event_types
    isSubjectCaseSensitive          = var.filter.is_subject_case_sensitive
    enableAdvancedFilteringOnArrays = var.filter.enable_advanced_filtering_on_arrays
    advancedFilters = var.filter.advanced_filters != null ? [
      for f in var.filter.advanced_filters : {
        key          = f.key
        operatorType = f.operator_type
        value        = f.value
        values       = f.values
      }
    ] : null
  } : null
  # Transform retry policy
  retry_policy = var.retry_policy != null ? {
    maxDeliveryAttempts      = var.retry_policy.max_delivery_attempts
    eventTimeToLiveInMinutes = var.retry_policy.event_time_to_live_in_minutes
  } : null
}

resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.event_grid_topic_resource_id
  type      = "Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15"
  body = {
    properties = merge(
      # Direct destination (without managed identity)
      local.destination_endpoint_type != null ? {
        destination = {
          endpointType = local.destination_endpoint_type
          properties   = local.destination_properties
        }
      } : {},

      # Delivery with resource identity
      var.delivery_with_resource_identity != null ? {
        deliveryWithResourceIdentity = {
          identity = {
            type                 = var.delivery_with_resource_identity.identity.type
            userAssignedIdentity = var.delivery_with_resource_identity.identity.user_assigned_identity
          }
          destination = {
            endpointType = local.delivery_identity_endpoint_type
            properties   = local.delivery_identity_properties
          }
        }
      } : {},

      # Dead letter destination
      var.dead_letter_destination != null ? {
        deadLetterDestination = {
          endpointType = "StorageBlob"
          properties = {
            resourceId        = var.dead_letter_destination.storage_blob.resource_id
            blobContainerName = var.dead_letter_destination.storage_blob.blob_container_name
          }
        }
      } : {},

      # Dead letter with resource identity
      var.dead_letter_with_resource_identity != null ? {
        deadLetterWithResourceIdentity = {
          identity = {
            type                 = var.dead_letter_with_resource_identity.identity.type
            userAssignedIdentity = var.dead_letter_with_resource_identity.identity.user_assigned_identity
          }
          deadLetterDestination = {
            endpointType = "StorageBlob"
            properties = {
              resourceId        = var.dead_letter_with_resource_identity.dead_letter_destination.storage_blob.resource_id
              blobContainerName = var.dead_letter_with_resource_identity.dead_letter_destination.storage_blob.blob_container_name
            }
          }
        }
      } : {},

      # Event delivery schema
      var.event_delivery_schema != null ? {
        eventDeliverySchema = var.event_delivery_schema
      } : {},

      # Expiration time
      var.expiration_time_utc != null ? {
        expirationTimeUtc = var.expiration_time_utc
      } : {},

      # Filter
      local.filter != null ? {
        filter = local.filter
      } : {},

      # Labels
      var.labels != null ? {
        labels = var.labels
      } : {},

      # Retry policy
      local.retry_policy != null ? {
        retryPolicy = local.retry_policy
      } : {}
    )
  }
  ignore_casing             = true
  ignore_missing_property   = true
  ignore_null_property      = true
  response_export_values    = ["*"]
  schema_validation_enabled = false
}
