# Local functions to transform typed destination to Azure API format
locals {
  # Helper function to build delivery attribute mappings in Azure API format
  build_delivery_attribute_mappings = {
    for k, v in var.event_subscriptions : k => [
      for mapping in coalesce(
        try(v.destination.azure_function.delivery_attribute_mappings, null),
        try(v.destination.event_hub.delivery_attribute_mappings, null),
        try(v.destination.hybrid_connection.delivery_attribute_mappings, null),
        try(v.destination.service_bus_queue.delivery_attribute_mappings, null),
        try(v.destination.service_bus_topic.delivery_attribute_mappings, null),
        try(v.destination.webhook.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.azure_function.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.event_hub.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.hybrid_connection.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.service_bus_queue.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.service_bus_topic.delivery_attribute_mappings, null),
        try(v.delivery_with_resource_identity.destination.webhook.delivery_attribute_mappings, null),
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
    ]
  }
  # Azure Function properties for delivery_with_resource_identity
  delivery_identity_azure_function_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                    = v.delivery_with_resource_identity.destination.azure_function.resource_id
      maxEventsPerBatch             = v.delivery_with_resource_identity.destination.azure_function.max_events_per_batch
      preferredBatchSizeInKilobytes = v.delivery_with_resource_identity.destination.azure_function.preferred_batch_size_in_kilobytes
      deliveryAttributeMappings     = try(v.delivery_with_resource_identity.destination.azure_function.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.azure_function, null) != null
  }
  # Helper to determine endpoint type for delivery_with_resource_identity destination
  delivery_identity_endpoint_type = {
    for k, v in var.event_subscriptions : k => (
      v.delivery_with_resource_identity == null ? null :
      try(v.delivery_with_resource_identity.destination.azure_function, null) != null ? "AzureFunction" :
      try(v.delivery_with_resource_identity.destination.event_hub, null) != null ? "EventHub" :
      try(v.delivery_with_resource_identity.destination.hybrid_connection, null) != null ? "HybridConnection" :
      try(v.delivery_with_resource_identity.destination.monitor_alert, null) != null ? "MonitorAlert" :
      try(v.delivery_with_resource_identity.destination.namespace_topic, null) != null ? "NamespaceTopic" :
      try(v.delivery_with_resource_identity.destination.service_bus_queue, null) != null ? "ServiceBusQueue" :
      try(v.delivery_with_resource_identity.destination.service_bus_topic, null) != null ? "ServiceBusTopic" :
      try(v.delivery_with_resource_identity.destination.storage_queue, null) != null ? "StorageQueue" :
      try(v.delivery_with_resource_identity.destination.webhook, null) != null ? "WebHook" : null
    )
  }
  # Event Hub properties for delivery_with_resource_identity
  delivery_identity_event_hub_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.delivery_with_resource_identity.destination.event_hub.resource_id
      deliveryAttributeMappings = try(v.delivery_with_resource_identity.destination.event_hub.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.event_hub, null) != null
  }
  # Hybrid Connection properties for delivery_with_resource_identity
  delivery_identity_hybrid_connection_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.delivery_with_resource_identity.destination.hybrid_connection.resource_id
      deliveryAttributeMappings = try(v.delivery_with_resource_identity.destination.hybrid_connection.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.hybrid_connection, null) != null
  }
  # Monitor Alert properties for delivery_with_resource_identity
  delivery_identity_monitor_alert_props = {
    for k, v in var.event_subscriptions : k => {
      severity     = v.delivery_with_resource_identity.destination.monitor_alert.severity
      actionGroups = v.delivery_with_resource_identity.destination.monitor_alert.action_groups
      description  = v.delivery_with_resource_identity.destination.monitor_alert.description
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.monitor_alert, null) != null
  }
  # Namespace Topic properties for delivery_with_resource_identity
  delivery_identity_namespace_topic_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId = v.delivery_with_resource_identity.destination.namespace_topic.resource_id
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.namespace_topic, null) != null
  }
  # Lookup delivery_with_resource_identity properties using try() to avoid type unification
  delivery_identity_properties = {
    for k, v in var.event_subscriptions : k => (
      v.delivery_with_resource_identity == null ? null :
      try(local.delivery_identity_storage_queue_props[k], null) != null ? local.delivery_identity_storage_queue_props[k] :
      try(local.delivery_identity_azure_function_props[k], null) != null ? local.delivery_identity_azure_function_props[k] :
      try(local.delivery_identity_event_hub_props[k], null) != null ? local.delivery_identity_event_hub_props[k] :
      try(local.delivery_identity_hybrid_connection_props[k], null) != null ? local.delivery_identity_hybrid_connection_props[k] :
      try(local.delivery_identity_monitor_alert_props[k], null) != null ? local.delivery_identity_monitor_alert_props[k] :
      try(local.delivery_identity_namespace_topic_props[k], null) != null ? local.delivery_identity_namespace_topic_props[k] :
      try(local.delivery_identity_service_bus_queue_props[k], null) != null ? local.delivery_identity_service_bus_queue_props[k] :
      try(local.delivery_identity_service_bus_topic_props[k], null) != null ? local.delivery_identity_service_bus_topic_props[k] :
      try(local.delivery_identity_webhook_props[k], null) != null ? local.delivery_identity_webhook_props[k] :
      null
    )
  }
  # Service Bus Queue properties for delivery_with_resource_identity
  delivery_identity_service_bus_queue_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.delivery_with_resource_identity.destination.service_bus_queue.resource_id
      deliveryAttributeMappings = try(v.delivery_with_resource_identity.destination.service_bus_queue.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.service_bus_queue, null) != null
  }
  # Service Bus Topic properties for delivery_with_resource_identity
  delivery_identity_service_bus_topic_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.delivery_with_resource_identity.destination.service_bus_topic.resource_id
      deliveryAttributeMappings = try(v.delivery_with_resource_identity.destination.service_bus_topic.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.service_bus_topic, null) != null
  }
  # Separate typed locals for each destination type - avoids Terraform type unification issues
  # Storage Queue properties for delivery_with_resource_identity
  delivery_identity_storage_queue_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                      = v.delivery_with_resource_identity.destination.storage_queue.resource_id
      queueName                       = v.delivery_with_resource_identity.destination.storage_queue.queue_name
      queueMessageTimeToLiveInSeconds = v.delivery_with_resource_identity.destination.storage_queue.queue_message_time_to_live_in_seconds
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.storage_queue, null) != null
  }
  # WebHook properties for delivery_with_resource_identity
  delivery_identity_webhook_props = {
    for k, v in var.event_subscriptions : k => {
      endpointUrl                            = v.delivery_with_resource_identity.destination.webhook.endpoint_url
      maxEventsPerBatch                      = v.delivery_with_resource_identity.destination.webhook.max_events_per_batch
      preferredBatchSizeInKilobytes          = v.delivery_with_resource_identity.destination.webhook.preferred_batch_size_in_kilobytes
      azureActiveDirectoryTenantId           = v.delivery_with_resource_identity.destination.webhook.azure_active_directory_tenant_id
      azureActiveDirectoryApplicationIdOrUri = v.delivery_with_resource_identity.destination.webhook.azure_active_directory_app_id_or_uri
      minimumTlsVersionAllowed               = v.delivery_with_resource_identity.destination.webhook.minimum_tls_version_allowed
      deliveryAttributeMappings              = try(v.delivery_with_resource_identity.destination.webhook.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.delivery_with_resource_identity != null && try(v.delivery_with_resource_identity.destination.webhook, null) != null
  }
  # Azure Function properties
  dest_azure_function_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                    = v.destination.azure_function.resource_id
      maxEventsPerBatch             = v.destination.azure_function.max_events_per_batch
      preferredBatchSizeInKilobytes = v.destination.azure_function.preferred_batch_size_in_kilobytes
      deliveryAttributeMappings     = try(v.destination.azure_function.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.azure_function, null) != null
  }
  # Event Hub properties
  dest_event_hub_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.destination.event_hub.resource_id
      deliveryAttributeMappings = try(v.destination.event_hub.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.event_hub, null) != null
  }
  # Hybrid Connection properties
  dest_hybrid_connection_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.destination.hybrid_connection.resource_id
      deliveryAttributeMappings = try(v.destination.hybrid_connection.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.hybrid_connection, null) != null
  }
  # Monitor Alert properties
  dest_monitor_alert_props = {
    for k, v in var.event_subscriptions : k => {
      severity     = v.destination.monitor_alert.severity
      actionGroups = v.destination.monitor_alert.action_groups
      description  = v.destination.monitor_alert.description
    } if v.destination != null && try(v.destination.monitor_alert, null) != null
  }
  # Namespace Topic properties
  dest_namespace_topic_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId = v.destination.namespace_topic.resource_id
    } if v.destination != null && try(v.destination.namespace_topic, null) != null
  }
  # Service Bus Queue properties
  dest_service_bus_queue_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.destination.service_bus_queue.resource_id
      deliveryAttributeMappings = try(v.destination.service_bus_queue.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.service_bus_queue, null) != null
  }
  # Service Bus Topic properties
  dest_service_bus_topic_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                = v.destination.service_bus_topic.resource_id
      deliveryAttributeMappings = try(v.destination.service_bus_topic.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.service_bus_topic, null) != null
  }
  # Separate typed locals for each direct destination type
  # Storage Queue properties
  dest_storage_queue_props = {
    for k, v in var.event_subscriptions : k => {
      resourceId                      = v.destination.storage_queue.resource_id
      queueName                       = v.destination.storage_queue.queue_name
      queueMessageTimeToLiveInSeconds = v.destination.storage_queue.queue_message_time_to_live_in_seconds
    } if v.destination != null && try(v.destination.storage_queue, null) != null
  }
  # WebHook properties
  dest_webhook_props = {
    for k, v in var.event_subscriptions : k => {
      endpointUrl                            = v.destination.webhook.endpoint_url
      maxEventsPerBatch                      = v.destination.webhook.max_events_per_batch
      preferredBatchSizeInKilobytes          = v.destination.webhook.preferred_batch_size_in_kilobytes
      azureActiveDirectoryTenantId           = v.destination.webhook.azure_active_directory_tenant_id
      azureActiveDirectoryApplicationIdOrUri = v.destination.webhook.azure_active_directory_app_id_or_uri
      minimumTlsVersionAllowed               = v.destination.webhook.minimum_tls_version_allowed
      deliveryAttributeMappings              = try(v.destination.webhook.delivery_attribute_mappings, null) != null ? local.build_delivery_attribute_mappings[k] : null
    } if v.destination != null && try(v.destination.webhook, null) != null
  }
  # Helper to determine endpoint type for direct destination
  destination_endpoint_type = {
    for k, v in var.event_subscriptions : k => (
      v.destination == null ? null :
      try(v.destination.azure_function, null) != null ? "AzureFunction" :
      try(v.destination.event_hub, null) != null ? "EventHub" :
      try(v.destination.hybrid_connection, null) != null ? "HybridConnection" :
      try(v.destination.monitor_alert, null) != null ? "MonitorAlert" :
      try(v.destination.namespace_topic, null) != null ? "NamespaceTopic" :
      try(v.destination.service_bus_queue, null) != null ? "ServiceBusQueue" :
      try(v.destination.service_bus_topic, null) != null ? "ServiceBusTopic" :
      try(v.destination.storage_queue, null) != null ? "StorageQueue" :
      try(v.destination.webhook, null) != null ? "WebHook" : null
    )
  }
  # Lookup direct destination properties using try() to avoid type unification
  destination_properties = {
    for k, v in var.event_subscriptions : k => (
      v.destination == null ? null :
      try(local.dest_storage_queue_props[k], null) != null ? local.dest_storage_queue_props[k] :
      try(local.dest_azure_function_props[k], null) != null ? local.dest_azure_function_props[k] :
      try(local.dest_event_hub_props[k], null) != null ? local.dest_event_hub_props[k] :
      try(local.dest_hybrid_connection_props[k], null) != null ? local.dest_hybrid_connection_props[k] :
      try(local.dest_monitor_alert_props[k], null) != null ? local.dest_monitor_alert_props[k] :
      try(local.dest_namespace_topic_props[k], null) != null ? local.dest_namespace_topic_props[k] :
      try(local.dest_service_bus_queue_props[k], null) != null ? local.dest_service_bus_queue_props[k] :
      try(local.dest_service_bus_topic_props[k], null) != null ? local.dest_service_bus_topic_props[k] :
      try(local.dest_webhook_props[k], null) != null ? local.dest_webhook_props[k] :
      null
    )
  }
  # Transform filter configuration
  event_subscription_filters = {
    for k, v in var.event_subscriptions : k => (
      v.filter != null ? {
        subjectBeginsWith               = v.filter.subject_begins_with
        subjectEndsWith                 = v.filter.subject_ends_with
        includedEventTypes              = v.filter.included_event_types
        isSubjectCaseSensitive          = v.filter.is_subject_case_sensitive
        enableAdvancedFilteringOnArrays = v.filter.enable_advanced_filtering_on_arrays
        advancedFilters = v.filter.advanced_filters != null ? [
          for f in v.filter.advanced_filters : {
            key          = f.key
            operatorType = f.operator_type
            value        = f.value
            values       = f.values
          }
        ] : null
      } : null
    )
  }
  # Transform retry policy
  event_subscription_retry_policies = {
    for k, v in var.event_subscriptions : k => (
      v.retry_policy != null ? {
        maxDeliveryAttempts      = v.retry_policy.max_delivery_attempts != null ? tonumber(v.retry_policy.max_delivery_attempts) : null
        eventTimeToLiveInMinutes = v.retry_policy.event_time_to_live_in_minutes != null ? tonumber(v.retry_policy.event_time_to_live_in_minutes) : null
      } : null
    )
  }
}

resource "azapi_resource" "event_subscriptions" {
  for_each = var.event_subscriptions

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = "Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15"
  body = {
    properties = merge(
      # Direct destination (without managed identity)
      local.destination_endpoint_type[each.key] != null ? {
        destination = {
          endpointType = local.destination_endpoint_type[each.key]
          properties   = local.destination_properties[each.key]
        }
      } : {},

      # Delivery with resource identity
      each.value.delivery_with_resource_identity != null ? {
        deliveryWithResourceIdentity = {
          identity = {
            type                 = each.value.delivery_with_resource_identity.identity.type
            userAssignedIdentity = each.value.delivery_with_resource_identity.identity.user_assigned_identity
          }
          destination = {
            endpointType = local.delivery_identity_endpoint_type[each.key]
            properties   = local.delivery_identity_properties[each.key]
          }
        }
      } : {},

      # Dead letter destination
      each.value.dead_letter_destination != null ? {
        deadLetterDestination = {
          endpointType = "StorageBlob"
          properties = {
            resourceId        = each.value.dead_letter_destination.storage_blob.resource_id
            blobContainerName = each.value.dead_letter_destination.storage_blob.blob_container_name
          }
        }
      } : {},

      # Dead letter with resource identity
      each.value.dead_letter_with_resource_identity != null ? {
        deadLetterWithResourceIdentity = {
          identity = {
            type                 = each.value.dead_letter_with_resource_identity.identity.type
            userAssignedIdentity = each.value.dead_letter_with_resource_identity.identity.user_assigned_identity
          }
          deadLetterDestination = {
            endpointType = "StorageBlob"
            properties = {
              resourceId        = each.value.dead_letter_with_resource_identity.dead_letter_destination.storage_blob.resource_id
              blobContainerName = each.value.dead_letter_with_resource_identity.dead_letter_destination.storage_blob.blob_container_name
            }
          }
        }
      } : {},

      # Event delivery schema
      each.value.event_delivery_schema != null ? {
        eventDeliverySchema = each.value.event_delivery_schema
      } : {},

      # Expiration time
      each.value.expiration_time_utc != null ? {
        expirationTimeUtc = each.value.expiration_time_utc
      } : {},

      # Filter
      local.event_subscription_filters[each.key] != null ? {
        filter = local.event_subscription_filters[each.key]
      } : {},

      # Labels
      each.value.labels != null ? {
        labels = each.value.labels
      } : {},

      # Retry policy
      local.event_subscription_retry_policies[each.key] != null ? {
        retryPolicy = local.event_subscription_retry_policies[each.key]
      } : {}
    )
  }
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_casing             = true
  ignore_missing_property   = true
  ignore_null_property      = true
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = ["*"]
  schema_validation_enabled = false
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}
