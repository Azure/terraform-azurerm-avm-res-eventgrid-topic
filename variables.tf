variable "location" {
  type        = string
  description = <<DESCRIPTION
Azure region where the resource should be deployed.
DESCRIPTION
  nullable    = false
}

variable "name" {
  type        = string
  description = <<DESCRIPTION
The name of the this resource.
DESCRIPTION

  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]{1,63}$", var.name))
    error_message = "The name must be between 1 and 63 characters and can contain only letters, numbers and hyphens."
  }
}

variable "parent_id" {
  type        = string
  description = <<DESCRIPTION
(Optional) The ID of the resource group where the virtual network will be deployed.
DESCRIPTION

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.parent_id))
    error_message = "parent_id must be a valid resource group ID."
  }
}

variable "data_residency_boundary" {
  type        = string
  default     = null
  description = <<DESCRIPTION
(Optional) Data residency boundary to set on the Event Grid Topic. Maps to the ARM property `dataResidencyBoundary`. Allowed values: 'WithinGeopair' (API default) and 'WithinRegion'. If `null`, the module will set `WithinGeopair` in the ARM payload to make the default explicit.
DESCRIPTION

  validation {
    condition     = var.data_residency_boundary == null ? true : contains(["WithinGeopair", "WithinRegion"], var.data_residency_boundary)
    error_message = "data_residency_boundary must be one of: 'WithinGeopair', 'WithinRegion' or null."
  }
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Event Grid Topic. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}

variable "disable_local_auth" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
When true the Event Grid Topic will have local authentication disabled (ARM property `disableLocalAuth`). The module will always set this property; default is `true` (local auth disabled).
DESCRIPTION
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "event_subscriptions" {
  type = map(object({
    name = string

    # Destination configuration - exactly one destination type should be specified
    destination = optional(object({
      # Azure Function destination
      azure_function = optional(object({
        resource_id                       = string
        max_events_per_batch              = optional(number)
        preferred_batch_size_in_kilobytes = optional(number)
        delivery_attribute_mappings = optional(list(object({
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
          source_field = optional(string)
        })))
      }))

      # Event Hub destination
      event_hub = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
          source_field = optional(string)
        })))
      }))

      # Hybrid Connection destination
      hybrid_connection = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
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
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
          source_field = optional(string)
        })))
      }))

      # Service Bus Topic destination
      service_bus_topic = optional(object({
        resource_id = string
        delivery_attribute_mappings = optional(list(object({
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
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
          name = string
          type = string # "Static" or "Dynamic"
          # For Static type
          value     = optional(string)
          is_secret = optional(bool)
          # For Dynamic type
          source_field = optional(string)
        })))
      }))
    }))

    # Delivery with managed identity - use this for RBAC-based delivery
    delivery_with_resource_identity = optional(object({
      identity = object({
        type                   = string # "SystemAssigned" or "UserAssigned"
        user_assigned_identity = optional(string)
      })
      destination = object({
        # Same destination types as above
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
    }))

    # Dead letter destination (StorageBlob only)
    dead_letter_destination = optional(object({
      storage_blob = object({
        resource_id         = string
        blob_container_name = string
      })
    }))

    # Dead letter with managed identity
    dead_letter_with_resource_identity = optional(object({
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
    }))

    # Event delivery schema
    event_delivery_schema = optional(string) # "EventGridSchema", "CloudEventSchemaV1_0", "CustomInputSchema"

    # Expiration time
    expiration_time_utc = optional(string)

    # Filter configuration
    filter = optional(object({
      subject_begins_with                 = optional(string)
      subject_ends_with                   = optional(string)
      included_event_types                = optional(list(string))
      is_subject_case_sensitive           = optional(bool)
      enable_advanced_filtering_on_arrays = optional(bool)
      advanced_filters = optional(list(object({
        key           = string
        operator_type = string
        # For single value operators (NumberGreaterThan, NumberLessThan, etc.)
        value = optional(any)
        # For multi-value operators (StringIn, NumberIn, etc.)
        values = optional(list(any))
      })))
    }))

    # Labels
    labels = optional(list(string))

    # Retry policy
    retry_policy = optional(object({
      max_delivery_attempts         = optional(number)
      event_time_to_live_in_minutes = optional(number)
    }))
  }))
  default     = {}
  description = <<DESCRIPTION
A map of event subscriptions to create on the Event Grid Topic.

Each event subscription supports the following:

- `name` - (Required) The name of the event subscription.

- `destination` - (Optional) Direct delivery destination. Specify exactly one destination type:
  - `azure_function` - Azure Function destination with `resource_id`, optional `max_events_per_batch`, `preferred_batch_size_in_kilobytes`, and `delivery_attribute_mappings`.
  - `event_hub` - Event Hub destination with `resource_id` and optional `delivery_attribute_mappings`.
  - `hybrid_connection` - Hybrid Connection destination with `resource_id` and optional `delivery_attribute_mappings`.
  - `monitor_alert` - Monitor Alert destination with `severity` (Sev0-Sev4), optional `action_groups` and `description`.
  - `namespace_topic` - Event Grid Namespace Topic destination with `resource_id`.
  - `service_bus_queue` - Service Bus Queue destination with `resource_id` and optional `delivery_attribute_mappings`.
  - `service_bus_topic` - Service Bus Topic destination with `resource_id` and optional `delivery_attribute_mappings`.
  - `storage_queue` - Storage Queue destination with `resource_id`, `queue_name`, and optional `queue_message_time_to_live_in_seconds`.
  - `webhook` - WebHook destination with `endpoint_url`, optional `max_events_per_batch`, `preferred_batch_size_in_kilobytes`, `azure_active_directory_tenant_id`, `azure_active_directory_app_id_or_uri`, `minimum_tls_version_allowed`, and `delivery_attribute_mappings`.

- `delivery_with_resource_identity` - (Optional) Delivery using managed identity (recommended for secure RBAC-based delivery):
  - `identity` - Identity configuration with `type` ("SystemAssigned" or "UserAssigned") and optional `user_assigned_identity`.
  - `destination` - Same destination types as above.

- `dead_letter_destination` - (Optional) Dead letter destination (only StorageBlob supported):
  - `storage_blob` - Storage blob with `resource_id` and `blob_container_name`.

- `dead_letter_with_resource_identity` - (Optional) Dead letter using managed identity.

- `event_delivery_schema` - (Optional) Schema for delivered events: "EventGridSchema", "CloudEventSchemaV1_0", "CustomInputSchema".

- `filter` - (Optional) Event filtering configuration:
  - `subject_begins_with` - Subject prefix filter.
  - `subject_ends_with` - Subject suffix filter.
  - `included_event_types` - List of event types to include.
  - `is_subject_case_sensitive` - Case sensitivity for subject filters.
  - `enable_advanced_filtering_on_arrays` - Enable advanced filtering on arrays.
  - `advanced_filters` - List of advanced filters with `key`, `operator_type`, `value`, and `values`.

- `labels` - (Optional) List of labels.

- `retry_policy` - (Optional) Retry policy with `max_delivery_attempts` and `event_time_to_live_in_minutes`.

Example - Storage Queue with managed identity:
```hcl
event_subscriptions = {
  storage_queue_sub = {
    name = "my-storage-queue-subscription"
    delivery_with_resource_identity = {
      identity = {
        type = "SystemAssigned"
      }
      destination = {
        storage_queue = {
          resource_id                          = "/subscriptions/.../storageAccounts/mystorageaccount"
          queue_name                           = "myqueue"
          queue_message_time_to_live_in_seconds = 300
        }
      }
    }
    filter = {
      subject_begins_with = "/myapp/"
      included_event_types = ["Microsoft.Storage.BlobCreated"]
    }
  }
}
```

Example - WebHook destination:
```hcl
event_subscriptions = {
  webhook_sub = {
    name = "my-webhook-subscription"
    destination = {
      webhook = {
        endpoint_url          = "https://example.com/webhook"
        max_events_per_batch  = 10
        minimum_tls_version_allowed = "1.2"
      }
    }
  }
}
```
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for k, v in var.event_subscriptions :
      v.name != null && (v.destination != null || v.delivery_with_resource_identity != null)
    ])
    error_message = "Each event subscription must have a 'name' and either 'destination' or 'delivery_with_resource_identity'."
  }
  validation {
    condition = alltrue([
      for k, v in var.event_subscriptions :
      v.event_delivery_schema == null ? true : contains(["EventGridSchema", "CloudEventSchemaV1_0", "CustomInputSchema"], v.event_delivery_schema)
    ])
    error_message = "event_delivery_schema must be one of: 'EventGridSchema', 'CloudEventSchemaV1_0', 'CustomInputSchema'."
  }
}

variable "inbound_ip_rules" {
  type = list(object({
    ip_mask = string
    action  = string
  }))
  default     = []
  description = <<DESCRIPTION
A list of inbound IP rules to restrict network access to the topic. Each rule must have an `ip_mask` and an `action` (e.g. 'Allow' or 'Deny').
DESCRIPTION
}

variable "input_schema" {
  type        = string
  default     = "EventGridSchema"
  description = <<DESCRIPTION
Optional input schema for the topic. Allowed values: 'EventGridSchema' (default), 'CloudEventSchemaV1_0', 'Custom'.
DESCRIPTION

  validation {
    condition     = contains(["EventGridSchema", "CloudEventSchemaV1_0", "CustomEventSchema"], var.input_schema)
    error_message = "input_schema must be one of: 'EventGridSchema', 'CloudEventSchemaV1_0', or 'CustomEventSchema'."
  }
}

variable "input_schema_mapping" {
  type = object({
    input_schema_mapping_type = string
    properties = optional(object({
      data_version = optional(object({
        default_value = optional(string)
        source_field  = optional(string)
      }))
      event_time = optional(object({
        source_field = optional(string)
      }))
      event_type = optional(object({
        default_value = optional(string)
        source_field  = optional(string)
      }))
      id = optional(object({
        source_field = optional(string)
      }))
      subject = optional(object({
        default_value = optional(string)
        source_field  = optional(string)
      }))
      topic = optional(object({
        source_field = optional(string)
      }))
    }))
  })
  default     = null
  description = <<DESCRIPTION
Optional input schema mapping object. Use this to provide mappings when `input_schema` is 'CustomEventSchema'. The structure follows the ARM schema for JSON input mappings. Set `input_schema_mapping_type` to 'Json' and provide field mappings in the `properties` object.
DESCRIPTION

  validation {
    condition     = var.input_schema_mapping == null ? true : var.input_schema_mapping.input_schema_mapping_type == "Json"
    error_message = "input_schema_mapping_type must be 'Json' when input_schema_mapping is provided."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION
  nullable    = false
}

variable "minimum_tls_version_allowed" {
  type        = string
  default     = "1.2"
  description = <<DESCRIPTION
Minimum TLS version allowed for the Event Grid Topic. This maps to the ARM property `minimumTlsVersionAllowed`.
DESCRIPTION

  validation {
    condition     = contains(["1.0", "1.1", "1.2"], var.minimum_tls_version_allowed)
    error_message = "minimum_tls_version_allowed must be one of: '1.0', '1.1', '1.2'."
  }
}

variable "private_endpoints" {
  type = map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time. See `var.role_assignments` for more information.
- `lock` - (Optional) The lock level to apply to the private endpoint. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint.
- `subnet_resource_id` - The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. One will be generated if not set.
- `private_dns_zone_resource_ids` - (Optional) A set of resource IDs of private DNS zones to associate with the private endpoint. If not set, no zone groups will be created and the private endpoint will not be associated with any private DNS zones. DNS records must be managed external to this module.
- `application_security_group_resource_ids` - (Optional) A map of resource IDs of application security groups to associate with the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The Azure location where the resources will be deployed. Defaults to the location of the resource group.
- `resource_group_name` - (Optional) The resource group where the resources will be deployed. Defaults to the resource group of this resource.
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint. If not specified the platform will create one. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `name` - The name of the IP configuration.
- `private_ip_address` - The private IP address of the IP configuration.
DESCRIPTION
  nullable    = false
}

# Whether the module should create/manage private DNS zone groups for private endpoints.
variable "private_endpoints_manage_dns_zone_group" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
Whether the module should create/manage private DNS zone group(s) for private endpoints. If set to false, DNS zone group management is left to the caller (e.g., managed externally or via Azure Policy).
DESCRIPTION
  nullable    = false
}

# Passthrough for resource properties that map directly to the ARM schema for Microsoft.EventGrid/topics
variable "properties" {
  type        = map(string)
  default     = {}
  description = "A map of additional string properties to set on the Event Grid Topic resource. This allows passing ARM schema properties that are not explicitly modeled by this module. For complex object properties, use the explicitly-defined module variables. See schema at: https://learn.microsoft.com/en-us/azure/templates/microsoft.eventgrid/2025-02-15/topics"
  nullable    = false
}

variable "public_network_access" {
  type        = string
  default     = "Disabled"
  description = <<DESCRIPTION
Controls public network access for the topic. Must be one of: 'Enabled', 'Disabled'. Defaults to 'Disabled' to reduce public exposure by default.
DESCRIPTION

  validation {
    condition     = contains(["Enabled", "Disabled"], var.public_network_access)
    error_message = "public_network_access must be one of: 'Enabled' or 'Disabled'."
  }
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.
- `delegated_managed_identity_resource_id` - The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created.
- `principal_type` - The type of the principal_id. Possible values are `User`, `Group` and `ServicePrincipal`. Changing this forces a new resource to be created. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = <<DESCRIPTION
(Optional) Tags of the resource.
DESCRIPTION
}
