# FHIR-First Approach: Direct FHIR API Integration

---
### Copyright

**Author**: roland@headease.nl

This document is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

---

## 📋 Overview

This document describes an alternative architecture where the Chat Application **communicates directly with the FHIR API** instead of via a custom Matrix Bridge API. The existing matrix-bridge automatically synchronizes between Matrix and FHIR, allowing the FHIR server to function as the primary client API.

**Core Idea**: Use the OZO implementation of FHIR messaging (CommunicationRequest, Communication, Task) as the client API and let the matrix-bridge handle synchronization with Matrix.

## 🏗️ Architecture Comparison

### Original POC Architecture (Custom Matrix Bridge API)

```
Chat Backend → Matrix Bridge API → Matrix Bridge → Matrix Homeserver
             ↓
              Database (BSN mapping, state)
```

**Characteristics**:
- Custom REST API with BSN in request bodies
- Database for BSN ↔ Matrix user ID mapping
- Webhook notifications to Chat Backend
- No FHIR in this layer

### FHIR-First Architecture

```
Chat Backend → FHIR Server ← Matrix Bridge → Matrix Homeserver
               ↓         ↓
               └─────────┘
        FHIR Subscriptions
    (webhooks to Chat Backend)
```

**Characteristics**:
- Standard FHIR R4 REST API
- No extra database (FHIR server is data store)
- FHIR Subscriptions send webhooks to Chat Backend
- Matrix Bridge polls FHIR server for changes (existing behavior)
- Matrix Bridge as pure sync layer

## 🎯 Advantages of FHIR-First

### 1. **No Custom API Development**
- Use standard FHIR R4 REST API
- **No Matrix Bridge API database needed** (was required for BSN mapping)
- No custom endpoints to develop
- OZO Implementation Guide is the API documentation

### 2. **FHIR Subscriptions for Real-Time**
- Standard FHIR subscription mechanism
- Webhook notifications to Chat Backend
- **No custom webhook API to develop** (was needed in original POC)

### 3. **Direct FHIR Compliance**
- Chat backend works directly with CommunicationRequest, Communication, Task
- No JSON transformation layer
- Audit trail inherent through FHIR resources

### 4. **Simpler Architecture**
- Existing matrix-bridge works as designed
- **No extra component** (Matrix Bridge API + database)
- Matrix Bridge remains pure bidirectional sync: Matrix ↔ FHIR

## 📊 Architecture Diagram

```
┌──────────────────────────────────────────┐
│   Chat Application Frontend              │
│   - User login via DigID (BSN)           │
│   - WebSocket for real-time updates      │
└──────────────────┬───────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────┐
│   Chat Application Backend               │
│   - DigID authentication                 │
│   - BSN → Patient FHIR reference mapping │
│   - FHIR Subscription webhook endpoint   │
└──┬───────────────────────────────────────┘
   │                               ▲
   │ FHIR R4 REST API              │ FHIR Subscription
   │ GET /CareTeam?                │ (webhook notifications)
   │  patient=Patient/123          │
   │ POST /CommunicationRequest    │
   │ POST /Communication           │
   │                               │
   ▼                               │
┌──────────────────────────────────────────┐
│          FHIR Server (HAPI FHIR)         │
│   - CareTeam resources                   │
│   - CommunicationRequest (threads)       │
│   - Communication (messages)             │
│   - Task (read receipts)                 │
│   - AuditEvent (audit trail)             │
│   - FHIR Subscriptions                   │
└───────────┬──────────────────────────────┘
            │                 ▲
            │                 │
            │                 │ FHIR Subscription
            ▼                 │ (webhook notifications)
      ┌──────────────────────────────┐
      │   Matrix Bridge (EXISTING)   │
      │ - Watches FHIR resources     │
      │ - Creates Matrix spaces      │
      │ - Creates Matrix rooms       │
      │ - Posts messages to Matrix   │
      │ - Updates FHIR from Matrix   │
      └───────────┬──────────────────┘
                  │ Matrix Protocol
                  ▼
      ┌───────────────────────┐
      │  Matrix Homeserver    │
      │  (Synapse)            │
      └───────────────────────┘

```

## 🔄 Operation Flows

### 1. Care Network Discovery (via FHIR)

**Chat Backend works with FHIR Patient reference instead of BSN**

```
1. User login via DigID → BSN
2. Chat Backend: Resolve BSN → Patient FHIR reference
   - Lookup: GET /Patient?identifier=urn:oid:2.16.840.1.113883.2.4.6.3|{bsn}
   - Get: Patient/123
3. Chat Backend: Get care networks
   GET /CareTeam?patient=Patient/123
   (Note: This finds CareTeams where patient is the subject)
4. Return CareTeam resources with participants
```

**Example Request**:
```http
GET /fhir/CareTeam?patient=Patient/123
Accept: application/fhir+json
```

**Note**: The OID `urn:oid:2.16.840.1.113883.2.4.6.3` is the official identifier system for BSN (Burgerservicenummer) in the Netherlands.

**Example Response**:
```json
{
  "resourceType": "Bundle",
  "entry": [
    {
      "resource": {
        "resourceType": "CareTeam",
        "id": "244",
        "status": "active",
        "subject": {
          "reference": "Patient/123",
          "display": "Jan Jansen"
        },
        "participant": [
          {
            "role": [{
              "coding": [{
                "system": "http://snomed.info/sct",
                "code": "158965000",
                "display": "Medical practitioner"
              }]
            }],
            "member": {
              "reference": "Practitioner/456",
              "display": "Dr. Smith"
            }
          },
          {
            "role": [{
              "coding": [{
                "system": "http://terminology.hl7.org/CodeSystem/v3-RoleCode",
                "code": "CHILD"
              }]
            }],
            "member": {
              "reference": "RelatedPerson/789",
              "display": "Marie Jansen"
            }
          }
        ]
      }
    }
  ]
}
```

### 2. Thread Discovery (CommunicationRequests)

```
GET /CommunicationRequest?subject=Patient/123&_include=CommunicationRequest:recipient
Accept: application/fhir+json
```

**Response**: Bundle with all CommunicationRequests for this patient

### 3. Start New Thread

```http
POST /fhir/CommunicationRequest
Content-Type: application/fhir+json

{
  "resourceType": "CommunicationRequest",
  "status": "active",
  "subject": {
    "reference": "Patient/123"
  },
  "recipient": [
    {
      "reference": "Practitioner/456"
    }
  ],
  "sender": {
    "reference": "RelatedPerson/789"
  },
  "payload": [
    {
      "contentString": "Schedule appointment for checkup"
    }
  ]
}
```

**Matrix Bridge detects new CommunicationRequest**:
1. Creates Matrix room with alias: `#communicationrequest-{id}:homeserver`
2. Invites all recipients to room
3. Posts initial message to Matrix room

### 4. Send Message

```http
POST /fhir/Communication
Content-Type: application/fhir+json

{
  "resourceType": "Communication",
  "status": "completed",
  "partOf": [
    {
      "reference": "CommunicationRequest/245"
    }
  ],
  "sender": {
    "reference": "RelatedPerson/789"
  },
  "recipient": [
    {
      "reference": "Practitioner/456"
    }
  ],
  "payload": [
    {
      "contentString": "Can I take this medication with food?"
    }
  ],
  "sent": "2025-01-15T11:00:00Z"
}
```

**Matrix Bridge detects new Communication**:
1. Finds Matrix room via CommunicationRequest reference
2. Posts message to Matrix room
3. Stores Matrix event ID in Communication.identifier

### 5. Get Messages

```http
GET /fhir/Communication?part-of=CommunicationRequest/245&_sort=-sent
Accept: application/fhir+json
```

**Response**: Bundle with all Communications for this thread

### 6. Mark as Read

```http
POST /fhir/Task
Content-Type: application/fhir+json

{
  "resourceType": "Task",
  "status": "completed",
  "intent": "order",
  "focus": {
    "reference": "Communication/567"
  },
  "owner": {
    "reference": "Practitioner/456"
  },
  "executionPeriod": {
    "end": "2025-01-15T11:05:00Z"
  }
}
```

**Matrix Bridge detects Task update**:
1. Sends Matrix read receipt for corresponding event

## 📡 Real-Time Events via FHIR Subscriptions

### Setup Subscription

```http
POST /fhir/Subscription
Content-Type: application/fhir+json

{
  "resourceType": "Subscription",
  "status": "active",
  "reason": "Monitor new messages in care network",
  "criteria": "Communication?subject=Patient/123",
  "channel": {
    "type": "rest-hook",
    "endpoint": "https://chat-backend.example.com/fhir/webhooks/sub-123",
    "header": [
      "Authorization: Bearer {token}"
    ]
  }
}
```

### Webhook Notification Format

With no `payload` field (omitted), FHIR server sends empty POST to subscription-specific endpoint:

```http
POST /fhir/webhooks/sub-123
Authorization: Bearer {token}

(empty body)
```

**Important**: The notification contains **no body**. The subscription ID is in the URL path. The Chat Backend must fetch updates using `_history` with `_since` parameter:

```http
GET /fhir/Communication/_history?_since=2025-01-13T10:30:00Z&subject=Patient/123
Accept: application/fhir+json
```

**Implementation Pattern**:
1. Subscription endpoint includes subscription ID: `/fhir/webhooks/{subscriptionId}`
2. Chat Backend stores last sync timestamp per subscription
3. Receives empty POST to `/fhir/webhooks/sub-123`
4. Extracts subscription ID from URL path
5. Fetches history: `GET /fhir/Communication/_history?_since={lastSync}&subject=Patient/123`
6. Processes all returned resources
7. Updates lastSync timestamp to current time

### Multiple Subscriptions per User

```
Subscription 1: Communication?subject=Patient/123  (new messages)
Subscription 2: Task?owner=Practitioner/456         (read receipts)
Subscription 3: CommunicationRequest?subject=Patient/123 (new threads)
```

## 🔐 Identity & Security

### BSN Handling

**Chat Backend responsibility**:
1. User login via DigID → BSN
2. **One-time** lookup: BSN → Patient FHIR reference
   - `GET /Patient?identifier=http://fhir.nl/fhir/NamingSystem/bsn|{bsn}`
   - Cache Patient/123 in user session
3. **All subsequent operations**: use Patient/123 reference

**Advantages**:
- BSN never in FHIR API calls (only in initial lookup)
- BSN not in logs (except one search query)
- Patient reference is not privacy-sensitive

### FHIR Security

- **SMART on FHIR** authentication possible
- OAuth 2.0 tokens with patient context
- Fine-grained access control via FHIR permissions

## 🚀 Matrix Bridge Role

### What Matrix Bridge Does (Unchanged)

The existing Matrix Bridge continues to operate exactly as designed, with **no modifications needed** for the FHIR-First approach:

**FHIR → Matrix Synchronization**:
- Subscribe to FHIR resources via FHIR Subscriptions (webhook notifications)
- Create Matrix spaces for CareTeams
- Create Matrix rooms for CommunicationRequests
- Post messages to Matrix for Communications
- Store Matrix event IDs back in FHIR resources

**Matrix → FHIR Synchronization**:
- Listen to Matrix events via Application Service
- Create FHIR Communications for new Matrix messages
- Create FHIR Tasks for read receipts
- Create FHIR AuditEvents for access logging

### What Matrix Bridge Does NOT Do

- ❌ No custom REST API
- ❌ No BSN mapping database
- ❌ No webhooks to Chat Backend (FHIR server sends these via FHIR Subscriptions)
- ❌ No care network discovery endpoints

### Notification Flow

**Two parallel notification paths**:
1. **Matrix Bridge** (existing): Polls FHIR server → Syncs to Matrix
2. **Chat Backend** (new): Receives webhooks from FHIR Subscriptions → Notifies frontend via WebSocket

This dual approach ensures:
- Matrix federation works (via Matrix Bridge)
- Chat Application gets real-time updates (via FHIR Subscriptions)
- No changes needed to existing Matrix Bridge

## 📋 Chat Backend Implementation

### Required FHIR Operations

```typescript
// 1. Initial BSN lookup (once per login)
async function resolvePatient(bsn: string): Promise<string> {
  const bundle = await fhirClient.search({
    resourceType: 'Patient',
    searchParams: {
      identifier: `http://fhir.nl/fhir/NamingSystem/bsn|${bsn}`
    }
  });
  return bundle.entry[0].resource.id; // "Patient/123"
}

// 2. Get care networks
async function getCareNetworks(patientRef: string): Promise<CareTeam[]> {
  const bundle = await fhirClient.search({
    resourceType: 'CareTeam',
    searchParams: {
      patient: patientRef
    }
  });
  return bundle.entry.map(e => e.resource);
}

// 3. Get threads
async function getThreads(patientRef: string): Promise<CommunicationRequest[]> {
  const bundle = await fhirClient.search({
    resourceType: 'CommunicationRequest',
    searchParams: {
      subject: patientRef,
      _sort: '-authored'
    }
  });
  return bundle.entry.map(e => e.resource);
}

// 4. Send message
async function sendMessage(
  commReqRef: string,
  senderRef: string,
  text: string
): Promise<Communication> {
  return await fhirClient.create({
    resourceType: 'Communication',
    status: 'completed',
    partOf: [{ reference: commReqRef }],
    sender: { reference: senderRef },
    payload: [{ contentString: text }],
    sent: new Date().toISOString()
  });
}

// 5. FHIR Subscription webhook handler
// Store last sync timestamp and criteria per subscription
const subscriptions = new Map<string, {
  lastSync: string;
  criteria: string; // e.g., "Communication?subject=Patient/123"
}>();

app.post('/fhir/webhooks/:subscriptionId', async (req, res) => {
  const subscriptionId = req.params.subscriptionId;

  // Acknowledge receipt immediately
  res.status(200).send();

  // Process notification asynchronously
  const subscription = subscriptions.get(subscriptionId);
  if (!subscription) {
    console.error(`Unknown subscription: ${subscriptionId}`);
    return;
  }

  // Get last sync time (or start from 1 hour ago if first time)
  const since = subscription.lastSync ||
                new Date(Date.now() - 3600000).toISOString();

  // Fetch history since last sync
  // Parse criteria to extract resource type and search params
  const historyBundle = await fhirClient.search({
    resourceType: 'Communication',
    searchParams: {
      _since: since,
      subject: 'Patient/123' // Extracted from subscription.criteria
    }
  });

  // Process all changed resources
  for (const historyEntry of historyBundle.entry || []) {
    const resource = historyEntry.resource as Communication;

    // New message → notify frontend via WebSocket
    const affectedUsers = await getUsersInThread(resource.partOf[0].reference);
    affectedUsers.forEach(userId => {
      wsConnections[userId].send({
        type: 'message.new',
        threadId: resource.partOf[0].reference,
        message: transformToSimpleFormat(resource)
      });
    });
  }

  // Update last sync timestamp
  subscription.lastSync = new Date().toISOString();
});
```

## 🔄 Migration from Custom API to FHIR-First

### Mapping: Custom API → FHIR API

| Custom Matrix Bridge API             | FHIR API Equivalent                |
|--------------------------------------|------------------------------------|
| `POST /care-networks/discover`       | `GET /CareTeam?patient={ref}`      |
| `POST /subscriptions`                | `POST /Subscription`               |
| `POST /threads`                      | `POST /CommunicationRequest`       |
| `POST /threads/{id}/messages/search` | `GET /Communication?part-of={ref}` |
| `POST /threads/{id}/messages`        | `POST /Communication`              |
| `POST /threads/{id}/read`            | `POST /Task` (status=completed)    |
| Webhook notifications                | FHIR Subscription rest-hook        |

### BSN Handling Difference

**Custom API**:
```javascript
// Every call contains BSN
POST /api/v1/care-networks/discover
{ "bsn": "123456789" }
```

**FHIR-First**:
```javascript
// Once at login: BSN → Patient reference
const patientRef = await resolvePatient("123456789");
// Cache in session: session.patientRef = "Patient/123"

// All subsequent calls use Patient reference
GET /fhir/CareTeam?patient=Patient/123
```

## ⚖️ Trade-offs

### Advantages of FHIR-First

✅ **No custom API development**
✅ **Standard FHIR compliance**
✅ **Matrix bridge stays simple** (no database, no custom endpoints)
✅ **Direct FHIR audit trail**
✅ **FHIR Subscriptions are standard**
✅ **Easier for others to adopt** (just FHIR API)

### Disadvantages of FHIR-First (vs Custom API)

❌ **Chat Backend must understand FHIR**
   - CommunicationRequest, Communication, Task, CareTeam
   - FHIR search parameters, bundles, references
   - More complex JSON structures
   - **Custom API had simple JSON structures**

❌ **More FHIR calls needed**
   - Care network discovery = CareTeam search + includes
   - Thread listing = CommunicationRequest search
   - Messages = Communication search with filters
   - **Custom API had dedicated endpoints per use case**

❌ **FHIR performance considerations**
   - More HTTP roundtrips
   - FHIR search can be slow
   - Caching strategy needed in Chat Backend
   - **Custom API could aggregate/optimize**

❌ **BSN lookup still needed**
   - First call per login: BSN → Patient reference
   - Chat Backend must cache Patient reference
   - **Custom API did this transparently in Matrix Bridge API**

## 🎯 Recommendation

### When to choose FHIR-First?

- ✅ **Chat application already has FHIR knowledge**
- ✅ **Want standard FHIR compliance**
- ✅ **Don't want extra database layer**
- ✅ **Have good FHIR caching strategy**

### When to choose Custom Matrix Bridge API?

- ✅ **Chat application does NOT want to learn FHIR**
- ✅ **Want simple JSON API**
- ✅ **BSN as identifier is requirement**
- ✅ **Want optimal performance** (fewer roundtrips)

## 📚 References

- **OZO Implementation Guide**: https://ozo-implementation-guide.headease.nl/interaction-messaging.html
- **FHIR Communication**: http://hl7.org/fhir/communication.html
- **FHIR CommunicationRequest**: http://hl7.org/fhir/communicationrequest.html
- **FHIR Subscriptions**: http://hl7.org/fhir/subscription.html
- **FHIR CareTeam**: http://hl7.org/fhir/careteam.html

---

**Status**: Alternative Architecture Proposal
**Last Update**: 2025-01-13
