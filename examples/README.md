# Examples

- Create a directory for each example.
- Create a `_header.md` file in each directory to describe the example.
- See the `default` example provided as a skeleton - this must remain, but you can add others.
- Run `make fmt && make docs` from the repo root to generate the required documentation.
- If you want an example to be ignored by the end to end pipeline add a `.e2eignore` file to the example directory. 

> **Note:** Examples must be deployable and idempotent. Ensure that no input variables are required to run the example and that random values are used to ensure unique resource names. E.g. use the [naming module](https://registry.terraform.io/modules/Azure/naming/azurerm/latest) to generate a unique name for a resource.

## Available Examples

### default
The default example demonstrates basic usage of the Event Grid Topic module with:
- Private endpoint configuration
- Managed identity (system and user-assigned)
- Event subscriptions to Storage Queue
- Diagnostic settings to Log Analytics

### day2-operations
Comprehensive example for testing Day 2 operations scenarios including:
- Adding and removing event subscriptions
- Modifying event subscription filters
- Adding and removing private endpoints
- Changing managed identities
- Updating network access rules
- Modifying diagnostic settings
- Testing resource locks

This example includes commented-out sections for each test scenario with detailed instructions.

### idempotency-validation
Focused example for validating idempotency fixes in the module:
- Tests string vs number type conversion in event subscription properties
- Validates diagnostic settings destination type handling
- Demonstrates correct configuration patterns to avoid drift
- Provides automated testing procedures

Use this example to verify that the module maintains idempotency after deployment.
