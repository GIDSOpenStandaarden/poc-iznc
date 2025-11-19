# Matrix Bridge API Specification

> **⚠️ STATUS: DRAFT - FOR REVIEW**
>
> This specification is currently in draft status and is open for review and feedback. Implementation details may change based on community input and practical experience.

---
### Copyright

**Author**: roland@headease.nl

This document is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

---

## Overview
RESTful API exposed by the Matrix Bridge that the Chat Application Backend calls to interact with Matrix messaging.

**Identity Model:**
- Chat Application Backend only works with BSN (from DigID authentication)
- Matrix Bridge maintains internal BSN ↔ Matrix user ID mapping
- Matrix Bridge handles all Matrix user ID resolution transparently
- Each supplier provisions Matrix accounts in their own Matrix homeserver
- Users may have multiple Matrix identities across different supplier systems
- Chat Application Backend never sees or stores Matrix user IDs

The Matrix Bridge handles the translation between this API and the underlying Matrix protocol.

## Architecture

```
┌──────────────────────────────────────────┐
│   Chat Application Backend               │
│   - DigID authentication (BSN)           │
│   - User session management              │
│   - Frontend WebSocket connections       │
│   - Webhook endpoint for events          │
└──────────────────┬──────────────────┬────┘
                   │                  ▲
                   │ REST API (calls) │ Webhooks (pushed)
                   │                  │
                   ▼                  │
┌──────────────────────────────────────────┐
│   Matrix Bridge API (NEW)                │
│   - BSN-based user discovery             │
│   - Care network/thread management       │
│   - Message operations                   │
│   - Subscription management              │
│   - Event notification via webhooks      │
└──────────────────┬───────────────────────┘
                   │ Matrix Protocol
                   ▼
       ┌───────────────────────┐
       │  Matrix Homeserver    │
       │  (Synapse)            │
       └───────────────────────┘
```

---

## Security and Identity Model

### BSN Usage - Important Constraints

**BSN is NOT used for routine operations.** Per the NUTS Instant Communication specification:

1. **BSN only appears in:**
   - Initial account provisioning (Chat Backend → Matrix Bridge)
   - Care network space invite events (NUTS spec requirement)

2. **All API operations use BSN:**
   - Chat Application Backend sends BSN in all API requests
   - Matrix Bridge internally resolves BSN → Matrix user ID
   - Matrix Bridge stores BSN ↔ Matrix user ID mapping (encrypted)
   - Chat Application Backend never sees Matrix user IDs

3. **BSN transmission:**
   - BSN must be in POST request body, never URL parameters
   - HTTPS required (even on internal networks)
   - No logging of BSN values in web server logs

### Identity Flow

```
User DigID login → BSN obtained
         ↓
Chat Backend stores BSN in user session
         ↓
Chat Backend calls Matrix Bridge with BSN
         ↓
Matrix Bridge checks internal mapping: BSN → Matrix user ID?
         ↓
    NO → Matrix Bridge creates: @iznc_{hash}:homeserver.example.com
         Matrix Bridge stores mapping (encrypted): BSN ↔ Matrix user ID
         ↓
   YES → Matrix Bridge uses existing Matrix user ID
         ↓
Matrix Bridge performs operation using Matrix user ID
         ↓
Matrix Bridge returns result (no Matrix user ID exposed)
```

### Supplier-Specific Identities

- Each supplier provisions accounts in their own Matrix homeserver (e.g., `supplier-a.example.com`)
- Other suppliers provision in their own homeservers (e.g., `supplier-b.example.com`)
- Same patient may have different Matrix IDs: `@iznc_user:supplier-a.example.com` and `@iznc_user:supplier-b.example.com`
- Care networks federate across different Matrix homeservers

---

## API Endpoints

**Note:** All endpoints accept BSN in the request body. Matrix Bridge handles BSN → Matrix user ID resolution internally.

### 1. Care Network Discovery

<img src="iznc-01-discovery-interaction.png" alt="Discovery Interaction" style="max-width: 100%;" />

#### Discover Care Networks for Organizations
```
POST /api/v1/care-networks/discover
```

**Purpose:** Discover care networks (Matrix spaces) for the organizations (URA) that the user is involved with. Typically returns one care network per URA, but technically multiple networks per URA are possible.

**Request:**
```json
{
  "uras": ["90000001", "90000002"],
  "userBsn": "123456789"
}
```

**Request Fields:**
- `uras`: List of URA numbers (zorgorganisatie identificatie) that the user is involved with
- `userBsn`: BSN of the user requesting access (for authorization)

**Response:**
```json
{
  "careNetworks": [
    {
      "careNetworkId": "!space123:homeserver.example.com",
      "ura": "90000001",
      "organizationName": "Ziekenhuis Voorbeeld",
      "name": "Zorgnetwerk Jan Jansen - Ziekenhuis Voorbeeld",
      "subject": {
        "matrixUserId": "@iznc_abc123def:homeserver.example.com",
        "name": "Jan Jansen",
        "role": "patient"
      },
      "participants": [
        {
          "matrixUserId": "@iznc_abc123def:homeserver.example.com",
          "name": "Jan Jansen",
          "role": "patient"
        },
        {
          "userId": "@marie.jansen:homeserver.example.com",
          "name": "Marie Jansen",
          "role": "mantelzorger"
        },
        {
          "userId": "@dr.smith:homeserver.example.com",
          "name": "Dr. Smith",
          "role": "care-professional",
          "uziNumber": "12345678"
        }
      ],
      "createdAt": "2025-01-15T10:00:00Z",
      "threadCount": 5,
      "unreadCount": 2
    },
    {
      "careNetworkId": "!space456:homeserver.example.com",
      "ura": "90000002",
      "organizationName": "Huisartsenpraktijk De Hof",
      "name": "Zorgnetwerk Jan Jansen - De Hof",
      "subject": {
        "matrixUserId": "@iznc_abc123def:homeserver.example.com",
        "name": "Jan Jansen",
        "role": "patient"
      },
      "participants": [
        {
          "matrixUserId": "@iznc_abc123def:homeserver.example.com",
          "name": "Jan Jansen",
          "role": "patient"
        },
        {
          "userId": "@dr.jones:homeserver.example.com",
          "name": "Dr. Jones",
          "role": "care-professional",
          "uziNumber": "87654321"
        }
      ],
      "createdAt": "2025-01-14T09:00:00Z",
      "threadCount": 3,
      "unreadCount": 0
    }
  ]
}
```

**Response Fields:**
- `careNetworks`: Array of care networks (typically one per URA, but multiple per URA is possible)
- `ura`: The URA number this care network is associated with
- `organizationName`: Name of the care organization

**Backend Action:**
1. Resolve userBsn to Matrix user ID (from internal encrypted mapping)
2. If no mapping exists, auto-provision Matrix account:
   - Generate Matrix user ID: `@iznc_{hash}:homeserver.example.com`
   - Register account in Matrix homeserver
   - Store BSN → Matrix user ID mapping
3. For each URA in the request:
   - Query Matrix homeserver for spaces associated with this URA (via space metadata)
   - Verify user is a member of these spaces
4. For each discovered space, extract participants and metadata
5. Return care network information grouped by URA

---

### 2. Subscription Management

#### Subscribe to Care Network
```
POST /api/v1/subscriptions
```

**Purpose:** Create a subscription to receive real-time events for a care network. Similar to FHIR subscriptions.

**Request:**
```json
{
  "bsn": "123456789",
  "careNetworkId": "!space123:homeserver.example.com",
  "webhookUrl": "https://chat-backend.example.com/webhooks/events",
  "events": ["message.new", "message.read", "thread.new", "participant.joined"]
}
```

**Response:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "careNetworkId": "!space123:homeserver.example.com",
  "webhookUrl": "https://chat-backend.example.com/webhooks/events",
  "status": "active",
  "createdAt": "2025-01-15T10:30:00Z"
}
```

**Note:** Response does not include BSN for security reasons.

**Backend Action:**
1. Validate user has access to the care network
2. Store subscription configuration
3. Start monitoring Matrix events for this space/user combination
4. Return subscription details

---

#### List Subscriptions
```
POST /api/v1/subscriptions/search
```

**Request:**
```json
{
  "bsn": "123456789"
}
```

**Response:**
```json
{
  "subscriptions": [
    {
      "subscriptionId": "sub-uuid-1234",
      "careNetworkId": "!space123:homeserver.example.com",
      "status": "active",
      "createdAt": "2025-01-15T10:30:00Z"
    }
  ]
}
```

---

#### Delete Subscription
```
DELETE /api/v1/subscriptions/{subscriptionId}
```

**Purpose:** Remove a subscription when user logs out or care network is no longer needed.

**Response:**
```json
{
  "subscriptionId": "sub-uuid-1234",
  "status": "deleted",
  "deletedAt": "2025-01-15T12:00:00Z"
}
```

---

### 3. Thread Management

<img src="iznc-02-read-interaction.png" alt="Read Interaction" style="max-width: 100%;" />

#### Get Threads in Care Network
```
POST /api/v1/care-networks/{careNetworkId}/threads/search
```

**Purpose:** List all conversation threads (Matrix rooms) within a care network.

**Request:**
```json
{
  "bsn": "123456789"
}
```

**Response:**
```json
{
  "careNetworkId": "!space123:homeserver.example.com",
  "threads": [
    {
      "threadId": "!room456:homeserver.example.com",
      "topic": "Medicatie vraag",
      "participants": [
        {
          "userId": "@jan.jansen:homeserver.example.com",
          "name": "Jan Jansen",
          "role": "patient"
        },
        {
          "userId": "@dr.smith:homeserver.example.com",
          "name": "Dr. Smith",
          "role": "care-professional"
        }
      ],
      "lastMessage": {
        "text": "U kunt het innemen met of zonder voedsel",
        "sender": {
          "userId": "@dr.smith:homeserver.example.com",
          "name": "Dr. Smith"
        },
        "timestamp": "2025-01-15T11:30:00Z"
      },
      "unreadCount": 1,
      "createdAt": "2025-01-15T10:00:00Z"
    }
  ]
}
```

**Backend Action:**
1. Verify user (BSN) has access to care network
2. Get all child rooms of the space
3. For each room, get latest message and unread count for this user
4. Return thread list

---

#### Create New Thread
```
POST /api/v1/threads
```

**Purpose:** Start a new conversation thread within a care network, targeting specific participants.

**Request:**
```json
{
  "initiatorBsn": "123456789",
  "careNetworkId": "!space123:homeserver.example.com",
  "topic": "Afspraak maken voor controle",
  "participantIds": [
    { "type": "bsn", "value": "123456789" },
    { "type": "matrixUserId", "value": "@dr.smith:homeserver.example.com" }
  ],
  "initialMessage": {
    "text": "Ik wil graag een afspraak maken voor een controle"
  }
}
```

**Note:** Participants can be identified by BSN (for users in the same organization) or Matrix user ID (for users from other suppliers in federated care networks).

**Response:**
```json
{
  "threadId": "!newroom789:homeserver.example.com",
  "careNetworkId": "!space123:homeserver.example.com",
  "topic": "Afspraak maken voor controle",
  "participants": [
    {
      "userId": "@jan.jansen:homeserver.example.com",
      "name": "Jan Jansen"
    },
    {
      "userId": "@dr.smith:homeserver.example.com",
      "name": "Dr. Smith"
    }
  ],
  "createdAt": "2025-01-15T12:00:00Z",
  "initialMessageId": "$msg123"
}
```

**Backend Action:**
1. Resolve initiatorBsn to Matrix user ID
2. Resolve all participant IDs (BSN → Matrix user ID where needed)
3. Verify initiator and all participants are members of the care network
4. Create Matrix room as child of the space
5. Invite all participants
6. Send initial message if provided
7. Return thread details

---

### 4. Message Operations

<img src="iznc-03-create-interaction.png" alt="Create Interaction" style="max-width: 100%;" />

#### Get Messages in Thread
```
POST /api/v1/threads/{threadId}/messages/search
```

**Purpose:** Retrieve message history for a conversation thread.

**Request:**
```json
{
  "bsn": "123456789",
  "limit": 50,
  "before": "$event123",
  "after": "$event456"
}
```

**Request Fields:**
- `bsn`: User BSN (required)
- `limit`: Number of messages to return (optional, default: 50)
- `before`: Event ID to paginate before (optional)
- `after`: Event ID to paginate after (optional)

**Response:**
```json
{
  "threadId": "!room456:homeserver.example.com",
  "messages": [
    {
      "messageId": "$event123",
      "sender": {
        "userId": "@jan.jansen:homeserver.example.com",
        "name": "Jan Jansen",
        "role": "patient"
      },
      "text": "Kan ik deze medicatie met eten innemen?",
      "attachments": [],
      "timestamp": "2025-01-15T11:00:00Z",
      "readBy": [
        {
          "userId": "@dr.smith:homeserver.example.com",
          "name": "Dr. Smith",
          "timestamp": "2025-01-15T11:05:00Z"
        }
      ],
      "replyTo": null
    },
    {
      "messageId": "$event124",
      "sender": {
        "userId": "@dr.smith:homeserver.example.com",
        "name": "Dr. Smith",
        "role": "care-professional"
      },
      "text": "Ja, u kunt het innemen met of zonder voedsel",
      "timestamp": "2025-01-15T11:30:00Z",
      "readBy": [],
      "replyTo": "$event123"
    }
  ],
  "pagination": {
    "prevBatch": "t123-456",
    "nextBatch": "t789-012",
    "hasMore": false
  }
}
```

**Backend Action:**
1. Verify user (BSN) has access to thread
2. Query Matrix messages API
3. Extract read receipts from Matrix
4. Transform to simple JSON format
5. Return messages with pagination

---

#### Send Message
```
POST /api/v1/threads/{threadId}/messages
```

**Request:**
```json
{
  "senderBsn": "123456789",
  "text": "Dank voor de informatie",
  "attachments": [
    {
      "filename": "recept.pdf",
      "contentType": "application/pdf",
      "data": "base64-encoded-data"
    }
  ],
  "replyTo": "$event124"
}
```

**Note:** Sender identified by BSN.

**Response:**
```json
{
  "messageId": "$event125",
  "threadId": "!room456:homeserver.example.com",
  "sender": {
    "userId": "@jan.jansen:homeserver.example.com",
    "name": "Jan Jansen"
  },
  "text": "Dank voor de informatie",
  "timestamp": "2025-01-15T11:45:00Z",
  "status": "sent"
}
```

**Backend Action:**
1. Resolve senderBsn to Matrix user ID
2. Verify sender is member of thread
3. Upload attachments to Matrix media repository
4. Send Matrix message event
5. Trigger webhook notifications to other subscribers
6. Return message details

---

#### Mark Messages as Read
```
POST /api/v1/threads/{threadId}/read
```

**Request:**
```json
{
  "bsn": "123456789",
  "lastReadMessageId": "$event124"
}
```

**Response:**
```json
{
  "threadId": "!room456:homeserver.example.com",
  "lastReadMessageId": "$event124",
  "timestamp": "2025-01-15T11:50:00Z"
}
```

**Backend Action:**
1. Resolve BSN to Matrix user ID
2. Send Matrix read receipt for the message
3. Trigger webhook notification to other subscribers
4. Return confirmation

---

### 5. User Information

#### Get User Profile
```
GET /api/v1/users/{userId}
```

**Response:**
```json
{
  "userId": "@dr.smith:homeserver.example.com",
  "name": "Dr. Smith",
  "role": "care-professional",
  "uziNumber": "12345678",
  "email": "dr.smith@hospital.nl",
  "avatarUrl": "mxc://homeserver.example.com/avatar123"
}
```

---

## Webhook Notifications

The Matrix Bridge pushes events to the Chat Application Backend via webhooks configured in subscriptions.

### Webhook Event Format

All webhook POSTs have this structure:

```json
{
  "subscriptionId": "sub-uuid-1234",
  "eventType": "message.new",
  "careNetworkId": "!space123:homeserver.example.com",
  "timestamp": "2025-01-15T12:00:00Z",
  "data": {
    // Event-specific data
  }
}
```

### Event Types

#### 1. New Message Event
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

**Action:** Chat Application Backend should:
1. Identify affected users (thread participants)
2. Optionally fetch full message details via `GET /api/v1/threads/{threadId}/messages`
3. Push notification to connected frontend clients via WebSocket

---

#### 2. Read Notification Event
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
      "name": "Jan Jansen"
    }
  }
}
```

**Action:** Chat Application Backend should:
1. Identify users in the thread
2. Push read receipt to connected frontend clients
3. Update unread counts

---

#### 3. New Thread Event
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
      "name": "Jan Jansen"
    }
  }
}
```

---

#### 4. Participant Events
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
      "name": "Verpleegkundige Jones"
    }
  }
}
```

---

## Error Responses

All endpoints use standard HTTP status codes and return errors in this format:

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "No user found with BSN 123456789",
    "details": {
      "bsn": "123456789"
    }
  }
}
```

**Error Codes:**
- `USER_NOT_FOUND`: BSN cannot be resolved to Matrix user
- `CARE_NETWORK_NOT_FOUND`: Care network (space) does not exist
- `THREAD_NOT_FOUND`: Thread (room) does not exist
- `ACCESS_DENIED`: User does not have access to resource
- `INVALID_BSN`: BSN format is invalid
- `SUBSCRIPTION_NOT_FOUND`: Subscription ID does not exist
- `WEBHOOK_FAILED`: Failed to deliver webhook notification

---

## Implementation Notes

### BSN to Matrix User ID Resolution

The Matrix Bridge maintains an encrypted database mapping between BSN and Matrix user IDs:

1. **Storage**: PostgreSQL database with encrypted BSN values
2. **Auto-provisioning**: On first BSN use, creates Matrix account: `@iznc_{hash}:homeserver.example.com`
3. **Caching**: In-memory cache for performance
4. **Privacy**: BSN never logged, never in URLs

### Care Network (Space) Structure

A care network is represented as:
- **Matrix Space**: Container for all threads related to a patient's care
- **Room Alias**: `#careteam/{careTeamId}:homeserver.example.com`
- **Child Rooms**: Individual conversation threads within the care network

### Subscription Lifecycle

1. **Creation**: User opens care network in chat app → Backend creates subscription
2. **Active**: Matrix Bridge monitors events and sends webhooks
3. **Deletion**: User closes app or logs out → Backend deletes subscription
4. **Cleanup**: Subscriptions auto-expire after 24 hours of inactivity

---

## Security Model

- **Internal Network**: All communication happens on trusted internal network
- **No Authentication**: Services trust each other
- **BSN Privacy**: BSN is used for user identification but not logged or exposed unnecessarily
- **Access Control**: Matrix Bridge verifies user membership before returning data

---

## Specification Extensions

### URA-based Care Network Discovery

**Status**: Extension to Matrix Specification

This POC introduces a **URA-based discovery mechanism** for care networks that is not currently part of the Matrix specificatie instante netwerk communicatie:

**Current Matrix Spec**:
- Discovery via UZI/URA for healthcare professionals
- mCSD for practitioner lookup
- BSN only appears in Matrix invite events

**POC Extension**:
- `POST /api/v1/care-networks/discover` with URA identifiers in request body
- Chat Application Backend provides list of URA numbers the user is involved with
- Matrix Bridge discovers care networks associated with these organizations
- Returns one or more care networks per URA (typically one, but multiple is technically possible)
- Matrix Bridge resolves BSN → Matrix user ID internally for authorization

**Rationale**:
- Chat applications work primarily with organizational context (URA) and user identity (BSN after DigID login)
- User is involved with specific care organizations, each with their own care networks
- Simplifies integration for commercial healthcare chat platforms
- Abstracts Matrix complexity away from chat backend
- Maintains BSN privacy (BSN used for auth, not for discovery keys)

**Future Actions**:
- This discovery mechanism should be documented in Matrix specification
- Define how URA information is stored in Matrix space metadata
- Security review of URA-based filtering
- Community alignment on organization-based discovery endpoints

### Other Extensions

- **Auto-provisioning**: Automatically create Matrix accounts on first BSN use
- **Webhook pattern**: Event notifications for push-based updates (not in current spec)
- **BSN mapping storage**: Encrypted storage requirements need documentation

---

## References

- **Matrix specificatie instante netwerk communicatie**: https://github.com/nuts-foundation/toepassing-instante-communicatie/blob/main/specificatie.md
- **Matrix Client-Server API**: https://spec.matrix.org/latest/client-server-api/
- **Matrix Spaces**: https://spec.matrix.org/latest/client-server-api/#spaces
