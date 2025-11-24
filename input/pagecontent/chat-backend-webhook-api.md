# Chat Application Backend Webhook API

> **⚠️ STATUS: DRAFT - FOR REVIEW**
>
> This specification is currently in draft status and is open for review and feedback. Implementation details may change based on community input and practical experience.

---
### Copyright

**Author**: roland@headease.nl

This document is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

---

## Overview

Simple webhook endpoints that the Chat Application Backend must implement to receive real-time event notifications from the Matrix Bridge. This follows the FHIR subscription pattern used in the OZO messaging implementation.

The Chat Application Backend should:
1. Receive lightweight event notifications via these webhooks
2. Fetch full details via the Matrix Bridge REST API if needed
3. Push notifications to connected frontend clients via WebSocket

---

## Architecture Flow

```
Matrix Event Occurs (new message, read receipt, etc.)
         ↓
Matrix Bridge detects event
         ↓
Matrix Bridge checks active subscriptions
         ↓
Matrix Bridge POST to webhook endpoint
         ↓
Chat Application Backend receives notification
         ↓
Chat Application Backend optionally fetches details via Matrix Bridge API
         ↓
Chat Application Backend pushes to frontend clients via WebSocket
```

---

## Webhook Endpoints

<img src="iznc-04-notification-interaction.svg" alt="Notification Interaction" style="max-width: 100%;" />

### 1. Unified Event Webhook

```
POST /webhooks/matrix-events
```

**Purpose:** Receive all types of events from Matrix Bridge in a single endpoint.

**Request Headers:**
```
Content-Type: application/json
X-Subscription-Id: sub-uuid-1234
```

**Request Body:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "message.new",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:00:00Z",
  "data": {
    "threadId": "!room456:homeserver.example.com",
    "messageId": "$event125",
    "sender": {
      "userId": "@dr.smith:homeserver.example.com",
      "name": "Dr. Smith"
    }
  }
}
```

**Response:**
```json
{
  "status": "received",
  "timestamp": "2025-01-15T12:00:01Z"
}
```

**Expected Behavior:**
1. Validate subscription ID exists and is active
2. Process event based on eventType
3. Return 200 OK quickly (process asynchronously if needed)
4. If endpoint returns error, Matrix Bridge should retry with exponential backoff

---

## Event Types and Handling

### Event Type: `message.new`

New message was sent in a thread.

**Webhook Payload:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "message.new",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:00:00Z",
  "data": {
    "threadId": "!room456:homeserver.example.com",
    "messageId": "$event125",
    "sender": {
      "userId": "@dr.smith:homeserver.example.com",
      "name": "Dr. Smith"
    },
    "hasAttachments": false,
    "preview": "Ja, u kunt het innemen..."
  }
}
```

**Recommended Handling:**
```javascript
// Pseudo-code
async function handleMessageNew(event) {
  // 1. Identify users to notify (thread participants)
  const subscription = await getSubscription(event.subscriptionId);
  const affectedBsn = subscription.bsn;

  // 2. Optional: Fetch full message details if needed
  const fullMessage = await matrixBridgeApi.getMessage(
    event.data.threadId,
    event.data.messageId,
    affectedBsn
  );

  // 3. Find connected WebSocket clients for this user
  const wsClients = getConnectedClients(affectedBsn);

  // 4. Push notification to clients
  wsClients.forEach(client => {
    client.send({
      type: 'message.new',
      threadId: event.data.threadId,
      message: fullMessage // or just use the preview
    });
  });

  // 5. Update unread counts, badges, etc.
  await incrementUnreadCount(affectedBsn, event.data.threadId);
}
```

---

### Event Type: `message.read`

Message was marked as read by a user.

**Webhook Payload:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "message.read",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:05:00Z",
  "data": {
    "threadId": "!room456:homeserver.example.com",
    "messageId": "$event124",
    "reader": {
      "userId": "@jan.jansen:homeserver.example.com",
      "name": "Jan Jansen",
      "bsn": "123456789"
    }
  }
}
```

**Recommended Handling:**
```javascript
async function handleMessageRead(event) {
  // 1. Get subscription details
  const subscription = await getSubscription(event.subscriptionId);

  // 2. Find connected clients for users in this thread
  const threadParticipants = await getThreadParticipants(event.data.threadId);

  // 3. Push read receipt to other participants
  threadParticipants.forEach(participantBsn => {
    if (participantBsn !== event.data.reader.bsn) {
      const wsClients = getConnectedClients(participantBsn);
      wsClients.forEach(client => {
        client.send({
          type: 'message.read',
          threadId: event.data.threadId,
          messageId: event.data.messageId,
          reader: event.data.reader
        });
      });
    }
  });
}
```

---

### Event Type: `thread.new`

New conversation thread was created in the care network.

**Webhook Payload:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "thread.new",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:10:00Z",
  "data": {
    "threadId": "!newroom789:homeserver.example.com",
    "topic": "Nieuwe vraag over medicatie",
    "creator": {
      "userId": "@jan.jansen:homeserver.example.com",
      "name": "Jan Jansen",
      "bsn": "123456789"
    },
    "participants": [
      "@jan.jansen:homeserver.example.com",
      "@dr.smith:homeserver.example.com"
    ]
  }
}
```

**Recommended Handling:**
```javascript
async function handleThreadNew(event) {
  // 1. Fetch full thread details
  const subscription = await getSubscription(event.subscriptionId);
  const thread = await matrixBridgeApi.getThread(
    event.data.threadId,
    subscription.bsn
  );

  // 2. Notify all participants
  event.data.participants.forEach(async userId => {
    const bsn = await resolveToBsn(userId);
    const wsClients = getConnectedClients(bsn);

    wsClients.forEach(client => {
      client.send({
        type: 'thread.new',
        careNetworkId: event.careNetworkId,
        thread: thread
      });
    });
  });
}
```

---

### Event Type: `participant.joined`

User joined a thread or care network.

**Webhook Payload:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "participant.joined",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:15:00Z",
  "data": {
    "threadId": "!room456:homeserver.example.com",
    "participant": {
      "userId": "@nurse.jones:homeserver.example.com",
      "name": "Verpleegkundige Jones",
      "role": "care-professional"
    }
  }
}
```

---

### Event Type: `participant.left`

User left a thread or care network.

**Webhook Payload:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "participant.left",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:20:00Z",
  "data": {
    "threadId": "!room456:homeserver.example.com",
    "participant": {
      "userId": "@nurse.jones:homeserver.example.com",
      "name": "Verpleegkundige Jones"
    }
  }
}
```

---

## Webhook Reliability

### Delivery Guarantees

The Matrix Bridge will:
1. **Retry on failure**: If webhook returns non-2xx status, retry with exponential backoff
2. **Retry schedule**:
   - Immediate
   - After 5 seconds
   - After 30 seconds
   - After 2 minutes
   - After 10 minutes
   - Give up after 5 attempts
3. **Timeout**: 10 second timeout per request
4. **Ordering**: Events delivered in chronological order per subscription

### Idempotency

Webhooks may be delivered multiple times. The Chat Application Backend should:
- Use `subscriptionId` + `timestamp` + `data.messageId`/`data.threadId` as idempotency key
- Store processed event IDs to detect duplicates
- Return 200 OK even for duplicate events

Example idempotency check:
```javascript
async function handleWebhook(event) {
  const eventKey = `${event.subscriptionId}:${event.eventType}:${event.data.messageId}:${event.timestamp}`;

  if (await isEventProcessed(eventKey)) {
    console.log('Duplicate event, ignoring');
    return { status: 'received' };
  }

  await processEvent(event);
  await markEventProcessed(eventKey);

  return { status: 'received' };
}
```

---

## Error Handling

### Webhook Endpoint Down

If the Chat Application Backend webhook endpoint is unavailable:
1. Matrix Bridge will retry per the schedule above
2. After max retries, Matrix Bridge will:
   - Mark subscription as "failing"
   - Continue collecting events in a buffer (up to 100 events)
   - Attempt redelivery when endpoint recovers

### Subscription Recovery

When Chat Application Backend comes back online:
1. Restart and check active subscriptions
2. For each subscription, call Matrix Bridge to get missed events:
   ```
   GET /api/v1/subscriptions/{subscriptionId}/missed-events?since={timestamp}
   ```
3. Process missed events before resuming normal webhook flow

---

## Implementation Example

### Express.js Webhook Handler

```javascript
const express = require('express');
const app = express();

app.use(express.json());

// Webhook endpoint
app.post('/webhooks/matrix-events', async (req, res) => {
  const event = req.body;

  try {
    // Validate subscription exists
    const subscription = await getSubscription(event.subscriptionId);
    if (!subscription) {
      return res.status(404).json({ error: 'Subscription not found' });
    }

    // Return 200 immediately (process async)
    res.status(200).json({
      status: 'received',
      timestamp: new Date().toISOString()
    });

    // Process event asynchronously
    processEventAsync(event).catch(err => {
      console.error('Failed to process event:', err);
      // Log for manual investigation
    });

  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function processEventAsync(event) {
  switch (event.eventType) {
    case 'message.new':
      await handleMessageNew(event);
      break;
    case 'message.read':
      await handleMessageRead(event);
      break;
    case 'thread.new':
      await handleThreadNew(event);
      break;
    case 'participant.joined':
    case 'participant.left':
      await handleParticipantChange(event);
      break;
    default:
      console.warn('Unknown event type:', event.eventType);
  }
}

app.listen(3000, () => {
  console.log('Webhook server listening on port 3000');
});
```

---

## Testing Webhooks

### Manual Testing

Use curl to simulate Matrix Bridge webhook calls:

```bash
curl -X POST http://localhost:3000/webhooks/matrix-events \
  -H "Content-Type: application/json" \
  -H "X-Subscription-Id: test-sub-123" \
  -d '{
    "subscriptionId": "test-sub-123",
    "eventType": "message.new",
    "careNetworkId": "!testspace:matrix.local",
    "timestamp": "2025-01-15T12:00:00Z",
    "data": {
      "threadId": "!testroom:matrix.local",
      "messageId": "$testevent123",
      "sender": {
        "userId": "@test:matrix.local",
        "name": "Test User"
      }
    }
  }'
```

### Health Check Endpoint

Implement a health check for the Matrix Bridge to verify webhook endpoint:

```
GET /webhooks/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T12:00:00Z"
}
```

---

## Security Considerations

### Webhook Verification

Since this is an internal network deployment, authentication is not required. However, for production:

**Optional:** Implement webhook signature verification:
1. Matrix Bridge includes `X-Webhook-Signature` header
2. HMAC-SHA256 signature of request body with shared secret
3. Chat Backend verifies signature before processing

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(body, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(body))
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}
```

### Rate Limiting

Implement rate limiting on webhook endpoints to prevent abuse:
- Max 1000 events per minute per subscription
- Return 429 Too Many Requests if exceeded

---

## Monitoring and Logging

### Recommended Metrics

Track these metrics for webhook health:
- **Webhook latency**: Time to return 200 OK
- **Event processing time**: Time to fully process event
- **Error rate**: Failed webhook deliveries
- **Event types**: Distribution of event types received
- **Duplicate rate**: Percentage of duplicate events

### Logging

Log all webhook calls with:
```javascript
console.log({
  timestamp: new Date().toISOString(),
  subscriptionId: event.subscriptionId,
  eventType: event.eventType,
  careNetworkId: event.careNetworkId,
  processingTime: processingTimeMs,
  status: 'success' // or 'error'
});
```

---

## References

- **Matrix Bridge API**: See `matrix-bridge-api.md`
- **OZO Messaging**: https://ozo-implementation-guide.headease.nl/interaction-messaging.html
- **FHIR Subscriptions**: https://www.hl7.org/fhir/subscription.html
