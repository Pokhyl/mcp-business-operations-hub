# M3 KeyCRM communications API investigation

Last verified: 2026-09-09.

## Goal

Determine whether customer communication history visible in the keyCRM UI can be read through an official, stable, read-only keyCRM interface suitable for a production MCP tool.

The required capability was broader than email. It needed to cover CRM-native chats/messages from connected channels (email, WhatsApp, Instagram and other supported channels), with enough provider data to relate messages to a buyer/lead and normalize timestamps, direction, operator and attachments where available.

## Official sources inspected

Primary sources:

- keyCRM OpenAPI documentation: `https://docs.keycrm.app/`
- the OpenAPI document loaded by that documentation UI: `https://docs.keycrm.app/api.yaml`
- keyCRM knowledge-base article describing OpenAPI capabilities
- keyCRM knowledge-base article describing outgoing webhooks
- keyCRM knowledge-base documentation for the Chats/Communications UI

The OpenAPI UI currently identifies the specification as OpenAPI v1.2.0 and uses the server base URL:

```text
https://openapi.keycrm.app/v1
```

## Result: no supported communications read endpoint

The current official OpenAPI document exposes these top-level resource paths:

```text
/order
/order/{orderId}
/order/import
/order/{orderId}/payment
/order/{orderId}/payment/{paymentId}
/order/{orderId}/expense
/order/{orderId}/expense/{expenseId}
/order/{orderId}/tag/{tagId}
/order/{orderId}/attachment/{fileId}
/order/tag
/order/source
/order/status
/order/payment-method
/order/expense-type
/order/delivery-service
/order/product-status
/pipelines
/pipelines/{pipelineId}/statuses
/pipelines/cards
/pipelines/cards/{cardId}
/pipelines/cards/{cardId}/payment
/pipelines/cards/{cardId}/payment/{paymentId}
/pipelines/cards/{cardId}/attachment/{fileId}
/buyer
/buyer/{buyerId}
/buyer/import
/companies
/companies/{companyId}
/products
/products/{productId}
/products/import
/products/{productId}/offers
/products/categories
/offers
/offers/stocks
/custom-fields
/storage
/storage/attachment/{entityType}/{entityId}
/storage/upload
/payments/external-transactions
/payments/{paymentId}/external-transactions
/calls
/users
```

There is no official path for:

```text
communications
chats
chat threads
messages
conversations
email history
WhatsApp message history
Instagram message history
```

Searching the official OpenAPI document for communication-resource terms did not reveal a hidden chat/message operation. Generic schema fields named `message` are error/response fields, not a communications resource.

## Buyer relation check

The official `GET /buyer/{buyerId}` operation supports only these documented `include` associations:

```text
manager
shipping
company
loyalty
custom_fields
```

There is no documented `communications`, `chats`, `messages`, `threads`, or equivalent buyer include.

Therefore buyer detail retrieval cannot be extended into customer communication history through a documented include parameter.

## Webhook check

The official keyCRM webhook documentation currently documents outgoing webhook events for:

```text
order.change_order_status
order.change_payment_status
lead.change_lead_status
```

The webhook payload provides basic order/pipeline-card context. No documented new-message/chat-message event is exposed.

Therefore the official webhook mechanism cannot be used as a supported source for reconstructing general CRM chat history, nor as a supported future-message mirror for this requirement.

## UI versus API boundary

The keyCRM UI does contain a Chats/Communications area and can aggregate customer communication from connected messengers, social networks, email, marketplace chats and the website chat widget.

That UI capability must not be treated as evidence of a public API capability. The current official OpenAPI does not expose the underlying communication history.

## Real-account probe rule

The production account already has accepted live GET-only KeyCRM reads through the existing `KeyCRM MCP` credential, including `GET /buyer/{buyer_id}` in `get_customer_details` and other accepted read workflows.

For communications specifically, there is no documented endpoint or include to probe. A request such as `/messages`, `/chats`, or a private UI endpoint would be an invented/unsupported path and was deliberately not introduced into production testing.

This investigation therefore stops at the supported-interface boundary instead of guessing an endpoint or extracting an internal/private API from the UI.

## Production decision

Do **not** implement `get_customer_communications` against the current public OpenAPI because there is no supported provider operation to back the tool.

Do **not**:

- scrape the keyCRM UI;
- call private/internal UI endpoints as production architecture;
- silently substitute Gmail for a generic CRM communication-history request;
- fabricate historical messages or channel metadata.

Keep `search_emails` as the independent Gmail/mailbox tool for explicit Gmail questions.

## Supported options

Current supported choices are:

1. Keep CRM customer/details and manager analytics on official KeyCRM read APIs plus the existing local read-only indexes.
2. Use `search_emails` only when the user explicitly asks for Gmail/mailbox data.
3. For full keyCRM chat history, use the keyCRM UI until keyCRM publishes a supported read API for chats/messages.
4. Ask keyCRM support whether a public communications endpoint is planned or available under a documented stable program not present in the current OpenAPI; if such an endpoint is published later, reopen this item and implement it through the normal read-only MCP boundary.
5. Any future decision to use a private/internal endpoint requires a separate explicit architecture/security decision; it is not part of M3 production architecture.

## M3 impact

The official/stable communications-API investigation is complete, with result `unsupported by current public OpenAPI`.

No new MCP workflow was deployed, no existing tool was removed, and no production KeyCRM write was performed.

M4 Controlled Writes remains out of scope.
