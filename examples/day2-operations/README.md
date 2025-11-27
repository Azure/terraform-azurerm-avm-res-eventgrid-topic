# Day 2 Operations Example

This example demonstrates various Day 2 operations scenarios for the Event Grid Topic module and validates idempotency after each operation.

## Purpose

This example is designed to test and validate:

1. **Idempotency**: Ensuring that repeated `terraform apply` commands produce no changes when configuration is unchanged
2. **Day 2 Operations**: Common operational changes that occur after initial deployment
3. **Incremental Updates**: Verifying that changes can be made to individual components without affecting others

## Testing Scenarios

### Initial Deployment

Deploy the example as-is to create the baseline infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

**Verify Idempotency**:
```bash
terraform plan
# Should show "No changes. Your infrastructure matches the configuration."
```

### Test 1: Adding an Event Subscription

**Objective**: Add a new event subscription to an existing topic without affecting other resources.

**Steps**:
1. Uncomment the `es_queue_2` block in the `event_subscriptions` map
2. Run `terraform plan` - should show only the new subscription being created
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes (validates idempotency)

**Expected Result**: Only the new event subscription is created; the topic and existing subscription remain unchanged.

### Test 2: Modifying Event Subscription Filters

**Objective**: Update the filter on an existing event subscription.

**Steps**:
1. In the `es_queue_1` subscription, change `subjectBeginsWith` to a different value
2. Run `terraform plan` - should show the subscription being updated in place
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: The event subscription filter is updated without recreating the subscription or topic.

### Test 3: Removing an Event Subscription

**Objective**: Remove an event subscription without affecting the topic.

**Steps**:
1. Comment out the `es_queue_2` block
2. Run `terraform plan` - should show only that subscription being destroyed
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Only the specified subscription is removed; other resources remain unchanged.

### Test 4: Adding EventHub Destination

**Objective**: Add an event subscription with a different destination type (EventHub).

**Steps**:
1. Uncomment the `es_eventhub` block
2. Run `terraform plan` - should show only the new subscription being created
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: EventHub subscription is created with advanced filters working correctly.

### Test 5: Adding User-Assigned Identity

**Objective**: Add a second user-assigned managed identity to the topic.

**Steps**:
1. Uncomment `azurerm_user_assigned_identity.uai2.id` in the `user_assigned_resource_ids` list
2. Run `terraform plan` - should show the topic being updated with the new identity
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: The identity is added without recreating the topic or subscriptions.

### Test 6: Removing User-Assigned Identity

**Objective**: Remove a user-assigned identity from the topic.

**Steps**:
1. Comment out `azurerm_user_assigned_identity.uai2.id`
2. Run `terraform plan` - should show the identity being removed
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Identity is removed cleanly without affecting other resources.

### Test 7: Disabling System-Assigned Identity

**Objective**: Disable the system-assigned managed identity.

**Steps**:
1. Set `system_assigned = false`
2. Run `terraform plan` - should show the identity being removed
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Note**: Be cautious if the system identity is used by event subscriptions or other resources.

### Test 8: Adding a Private Endpoint

**Objective**: Add a second private endpoint without disrupting the first.

**Steps**:
1. Uncomment the `pe2` block in `private_endpoints`
2. Run `terraform plan` - should show only the new PE being created
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Second private endpoint is created independently.

### Test 9: Removing a Private Endpoint

**Objective**: Remove a private endpoint cleanly.

**Steps**:
1. Comment out the `pe2` block
2. Run `terraform plan` - should show only that PE being destroyed
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Private endpoint is removed without affecting the topic or other PEs.

### Test 10: Enabling Public Network Access

**Objective**: Change network access configuration.

**Steps**:
1. Change `public_network_access = "Enabled"`
2. Run `terraform plan` - should show the topic being updated
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Public access is enabled without recreating the topic.

### Test 11: Adding Inbound IP Rules

**Objective**: Add IP-based network access rules.

**Steps**:
1. Uncomment the IP rule in `inbound_ip_rules`
2. Run `terraform plan` - should show the topic being updated
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: IP rules are applied without recreation.

### Test 12: Adding a Diagnostic Setting

**Objective**: Add a second diagnostic target.

**Steps**:
1. Uncomment the `secondary` diagnostic setting
2. Run `terraform plan` - should show only the new diagnostic setting being created
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Second diagnostic setting is created independently.

### Test 13: Modifying Diagnostic Categories

**Objective**: Update which log categories are collected.

**Steps**:
1. In the `primary` diagnostic setting, modify `log_categories` (e.g., remove "DataPlaneRequests")
2. Run `terraform plan` - should show the diagnostic setting being updated
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Log categories are updated in place.

### Test 14: Removing a Diagnostic Setting

**Objective**: Remove a diagnostic target.

**Steps**:
1. Comment out the `secondary` diagnostic setting
2. Run `terraform plan` - should show only that diagnostic setting being destroyed
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Diagnostic setting is removed cleanly.

### Test 15: Adding a Management Lock

**Objective**: Add resource lock protection.

**Steps**:
1. Uncomment the `lock` block
2. Run `terraform plan` - should show the lock being created
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Lock is created without affecting other resources.

### Test 16: Modifying Lock Type

**Objective**: Change lock type from CanNotDelete to ReadOnly.

**Steps**:
1. Change `kind = "ReadOnly"` in the lock block
2. Run `terraform plan` - should show the lock being updated
3. Run `terraform apply`
4. Run `terraform plan` again - should show no changes

**Expected Result**: Lock type is updated (may require recreation of lock resource).

## Idempotency Validation Checklist

After each test scenario, verify:

- [ ] `terraform plan` shows "No changes" after applying changes
- [ ] No resources show "(drift)" in their state
- [ ] No unexpected updates or recreations occur
- [ ] The operation completed successfully without errors

## Known Idempotency Issues

### Event Subscription Destination Properties

The module includes a lifecycle block to ignore changes to `body.properties.destination.properties` because Azure API may return numeric values as strings. This is expected behavior and prevents spurious drift.

**Impact**: Changes to destination properties (like `maxEventsPerBatch`) may not be detected by Terraform. To update these properties:
1. Remove the event subscription from configuration
2. Apply to destroy it
3. Add it back with new values
4. Apply to recreate it

### Diagnostic Settings Log Analytics Destination Type

Azure API does not return `log_analytics_destination_type` in responses, so the module ignores changes to this property. This is an Azure API limitation.

## Common Pitfalls

1. **String vs Number for Numeric Properties**: Always specify numeric properties in event subscriptions as strings to match Azure API responses:
   ```hcl
   queueMessageTimeToLiveInSeconds = "300"  # Correct
   queueMessageTimeToLiveInSeconds = 300    # Will cause drift
   ```

2. **Input Schema**: Once set, `input_schema` cannot be changed without recreating the topic. Always specify it explicitly.

3. **WebHook Validation**: When adding webhook subscriptions, ensure the endpoint is ready to respond to validation requests before creating the subscription.

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Note**: If you added a management lock, you may need to remove it first (comment out the lock block and apply) before destroying resources.
