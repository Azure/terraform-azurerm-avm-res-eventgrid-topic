variable "event_grid_topic_resource_id" {
  type        = string
  description = <<DESCRIPTION
The resource ID of the Event Grid Topic to create the subscription on.
This can be an existing topic not managed by the parent module.
DESCRIPTION

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.EventGrid/topics/[^/]+$", var.event_grid_topic_resource_id))
    error_message = "event_grid_topic_resource_id must be a valid Event Grid Topic resource ID."
  }
}

variable "name" {
  type        = string
  description = "The name of the event subscription."

  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]{3,64}$", var.name))
    error_message = "The name must be between 3 and 64 characters and can contain only letters, numbers and hyphens."
  }
}

variable "dead_letter_destination" {
  type = object({
    storage_blob = object({
      resource_id         = string
      blob_container_name = string
    })
  })
  default     = null
  description = <<DESCRIPTION
Dead letter destination for failed event deliveries. Only StorageBlob is supported.

- `storage_blob` - Storage blob configuration:
  - `resource_id` - Resource ID of the storage account.
  - `blob_container_name` - Name of the blob container for dead letters.
DESCRIPTION
}

variable "dead_letter_with_resource_identity" {
  type = object({
    identity = object({
      type                   = string # "SystemAssigned" or "UserAssigned"
      user_assigned_identity = optional(string)
    })
    dead_letter_destination = object({
      storage_blob = object({
        resource_id         = string
        blob_container_name = string
      })
    })
  })
  default     = null
  description = <<DESCRIPTION
Dead letter destination using managed identity.

- `identity` - Identity configuration with `type` and optional `user_assigned_identity`.
- `dead_letter_destination` - Storage blob configuration for dead letters.
DESCRIPTION
}

variable "delivery_with_resource_identity" {
  type = object({
    identity = object({
      type                   = string # "SystemAssigned" or "UserAssigned"
      user_assigned_identity = optional(string)
    })
    destination = object({
      azure_function = optional(object({
        resource_id                       = string
        max_events_per_batch              = optional(number)
        preferred_batch_size_in_kilobytes = optional(number)
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
      event_hub = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
      hybrid_connection = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
      monitor_alert = optional(object({
        severity      = string
        action_groups = optional(list(string))
        description   = optional(string)
      }))
      namespace_topic = optional(object({
        resource_id = string
      }))
      service_bus_queue = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
      service_bus_topic = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
      storage_queue = optional(object({
        resource_id                           = string
        queue_name                            = string
        queue_message_time_to_live_in_seconds = optional(number)
      }))
      webhook = optional(object({
        endpoint_url                         = string
        max_events_per_batch                 = optional(number)
        preferred_batch_size_in_kilobytes    = optional(number)
        azure_active_directory_tenant_id     = optional(string)
        azure_active_directory_app_id_or_uri = optional(string)
        minimum_tls_version_allowed          = optional(string)
        delivery_attribute_mappings = optional(list(object({
          name         = string
          type         = string
          value        = optional(string)
          is_secret    = optional(bool)
          source_field = optional(string)
        })))
      }))
    })
  })
  default     = null
  description = <<DESCRIPTION
Delivery configuration using managed identity (recommended for secure RBAC-based delivery).

- `identity` - Identity configuration:
  - `type` - "SystemAssigned" or "UserAssigned"
  - `user_assigned_identity` - Resource ID of user-assigned identity (required if type is "UserAssigned")
- `destination` - Same destination types as `destination` variable.

Note: When using this, ensure the managed identity has appropriate RBAC permissions on the destination resource.
DESCRIPTION
}

variable "destination" {
  type = object({
    # Azure Function destination
    azure_function = optional(object({
      resource_id                       = string
      max_events_per_batch              = optional(number)
      preferred_batch_size_in_kilobytes = optional(number)
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string # "Static" or "Dynamic"
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))

    # Event Hub destination
    event_hub = optional(object({
      resource_id = string
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))

    # Hybrid Connection destination
    hybrid_connection = optional(object({
      resource_id = string
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))

    # Monitor Alert destination
    monitor_alert = optional(object({
      severity      = string # "Sev0", "Sev1", "Sev2", "Sev3", "Sev4"
      action_groups = optional(list(string))
      description   = optional(string)
    }))

    # Namespace Topic destination
    namespace_topic = optional(object({
      resource_id = string
    }))

    # Service Bus Queue destination
    service_bus_queue = optional(object({
      resource_id = string
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))

    # Service Bus Topic destination
    service_bus_topic = optional(object({
      resource_id = string
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))

    # Storage Queue destination
    storage_queue = optional(object({
      resource_id                           = string
      queue_name                            = string
      queue_message_time_to_live_in_seconds = optional(number)
    }))

    # WebHook destination
    webhook = optional(object({
      endpoint_url                         = string
      max_events_per_batch                 = optional(number)
      preferred_batch_size_in_kilobytes    = optional(number)
      azure_active_directory_tenant_id     = optional(string)
      azure_active_directory_app_id_or_uri = optional(string)
      minimum_tls_version_allowed          = optional(string) # "1.0", "1.1", "1.2"
      delivery_attribute_mappings = optional(list(object({
        name         = string
        type         = string
        value        = optional(string)
        is_secret    = optional(bool)
        source_field = optional(string)
      })))
    }))
  })
  default     = null
  description = <<DESCRIPTION
Direct delivery destination configuration. Specify exactly one destination type.

Supported destination types:
- `azure_function` - Azure Function with `resource_id`, optional `max_events_per_batch`, `preferred_batch_size_in_kilobytes`, and `delivery_attribute_mappings`.
- `event_hub` - Event Hub with `resource_id` and optional `delivery_attribute_mappings`.
- `hybrid_connection` - Hybrid Connection with `resource_id` and optional `delivery_attribute_mappings`.
- `monitor_alert` - Monitor Alert with `severity` (Sev0-Sev4), optional `action_groups` and `description`.
- `namespace_topic` - Event Grid Namespace Topic with `resource_id`.
- `service_bus_queue` - Service Bus Queue with `resource_id` and optional `delivery_attribute_mappings`.
- `service_bus_topic` - Service Bus Topic with `resource_id` and optional `delivery_attribute_mappings`.
- `storage_queue` - Storage Queue with `resource_id`, `queue_name`, and optional `queue_message_time_to_live_in_seconds`.
- `webhook` - WebHook with `endpoint_url` and optional batching/security settings.

Note: Use `destination` for direct delivery or `delivery_with_resource_identity` for managed identity-based delivery, not both.
DESCRIPTION
}

variable "event_delivery_schema" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The schema for delivered events. Possible values:
- "EventGridSchema" (default)
- "CloudEventSchemaV1_0"
- "CustomInputSchema"
DESCRIPTION

  validation {
    condition     = var.event_delivery_schema == null ? true : contains(["EventGridSchema", "CloudEventSchemaV1_0", "CustomInputSchema"], var.event_delivery_schema)
    error_message = "event_delivery_schema must be one of: 'EventGridSchema', 'CloudEventSchemaV1_0', 'CustomInputSchema'."
  }
}

variable "expiration_time_utc" {
  type        = string
  default     = null
  description = "The expiration time of the event subscription in UTC (ISO 8601 format)."
}

variable "filter" {
  type = object({
    subject_begins_with                 = optional(string)
    subject_ends_with                   = optional(string)
    included_event_types                = optional(list(string))
    is_subject_case_sensitive           = optional(bool)
    enable_advanced_filtering_on_arrays = optional(bool)
    advanced_filters = optional(list(object({
      key           = string
      operator_type = string
      value         = optional(any)
      values        = optional(list(any))
    })))
  })
  default     = null
  description = <<DESCRIPTION
Event filtering configuration.

- `subject_begins_with` - Filter events with subjects beginning with this prefix.
- `subject_ends_with` - Filter events with subjects ending with this suffix.
- `included_event_types` - List of event types to include.
- `is_subject_case_sensitive` - Whether subject matching is case-sensitive.
- `enable_advanced_filtering_on_arrays` - Enable advanced filtering on arrays.
- `advanced_filters` - List of advanced filters with:
  - `key` - The field to filter on.
  - `operator_type` - The operator (e.g., "StringIn", "NumberGreaterThan").
  - `value` - Single value for comparison operators.
  - `values` - Multiple values for "In" operators.
DESCRIPTION
}

variable "labels" {
  type        = list(string)
  default     = null
  description = "A list of labels to apply to the event subscription."
}

variable "retry_policy" {
  type = object({
    max_delivery_attempts         = optional(number)
    event_time_to_live_in_minutes = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry policy for event delivery.

- `max_delivery_attempts` - Maximum number of delivery attempts (1-30, default 30).
- `event_time_to_live_in_minutes` - Time to live for events in minutes (1-1440, default 1440).
DESCRIPTION
}
