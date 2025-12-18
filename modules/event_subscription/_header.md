# Event Subscription Submodule

This submodule creates an Event Grid event subscription on an Event Grid Topic.

## Purpose

This submodule can be used independently to create event subscriptions on:

- Event Grid Topics created by the parent module
- **Existing Event Grid Topics** not managed by Terraform

This enables scenarios where:

- The topic is managed by a different team
- The topic was created outside of Terraform
- Multiple subscriptions need to be added incrementally

## Usage

### On an existing topic (not managed by Terraform)

```hcl
module "my_subscription" {
  source = "Azure/avm-res-eventgrid-topic/azurerm//modules/event_subscription"

  name                         = "my-subscription"
  event_grid_topic_resource_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.EventGrid/topics/existing-topic"

  destination = {
    storage_queue = {
      resource_id                           = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/mystorageaccount"
      queue_name                            = "events"
      queue_message_time_to_live_in_seconds = 300
    }
  }

  filter = {
    subject_begins_with = "/myapp/"
  }
}
```

### With managed identity delivery

```hcl
module "my_subscription" {
  source = "Azure/avm-res-eventgrid-topic/azurerm//modules/event_subscription"

  name                         = "my-subscription"
  event_grid_topic_resource_id = module.eventgrid_topic.resource_id

  delivery_with_resource_identity = {
    identity = {
      type = "SystemAssigned"
    }
    destination = {
      storage_queue = {
        resource_id                           = azurerm_storage_account.example.id
        queue_name                            = "events"
        queue_message_time_to_live_in_seconds = 300
      }
    }
  }

  depends_on = [azurerm_role_assignment.eventgrid_to_storage]
}
```
