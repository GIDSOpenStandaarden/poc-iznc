# Proof of Concept - Integrated Care Network Communication (IZNC)

**Version**: 0.1.1 (2025-01-14)

## 📋 Overview

This is a proof-of-concept implementation for connecting a healthcare chat application to the Matrix specification for instant network communication via Matrix protocol.

**Goal**: Demonstrate how a commercial healthcare chat application can integrate with the federated care network via Matrix using a simple BSN-based API.

## 🏗️ Architecture (High-Level)

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
│   - Handles DigID authentication         │
│   - Manages user sessions                │
│   - Stores BSN in session                │
└──────────────────┬───────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────┐
│      Matrix Bridge API (NEW)             │
│   - BSN-based user discovery             │
│   - Care network/thread management       │
│   - Message operations                   │
│   - Webhook event notifications          │
│   - Implements Matrix Spec INNC          │
└──────────────────┬───────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────┐
│       Matrix Homeserver (Synapse)        │
└──────────────────────────────────────────┘
```


## Data Models

### Network Structure

<img src="iznc-network-datamodel.png" alt="Network Data Model" style="max-width: 100%;" />

### Message Structure

<img src="iznc-messages-datamodel.png" alt="Message Data Model" style="max-width: 100%;" />

## 🎯 Key Concepts

### Identity Model

The architecture uses a **BSN abstraction layer** to hide Matrix complexity from the chat application:

1. **Chat Application Backend works with BSN only**
   - User logs in with DigID → BSN obtained
   - All API calls contain BSN in request body
   - Matrix user IDs never visible to chat backend

2. **Matrix Bridge manages BSN ↔ Matrix user ID mapping**
   - Encrypted storage of BSN → Matrix user ID
   - Auto-provisioning: first BSN use = Matrix account creation
   - Matrix user ID format: `@iznc_{hash}:homeserver.example.com`

3. **Matrix Specification Compliance**
   - BSN only in Matrix invite events (per Matrix spec)
   - After that, only Matrix user IDs in Matrix protocol
   - External API continues to use BSN for simplicity

### Care Network Structure (per Matrix Spec)

- **Matrix Space = CareTeam** (care network around a client)
  - Contains all care providers and informal caregivers
  - Power levels determine rights (100=lead, 75=care provider, 50=informal caregiver, 25=client)

- **Matrix Room = Conversation Thread**
  - Child rooms within the space
  - Specific topic/question
  - Subset of space members

- **Custom State Events**
  - `custom.user_mappings`: FHIR identity per user (UZI, URA, roleCode)
  - `m.space.child` / `m.space.parent`: hierarchy

## 📄 API Specifications

This POC implements a **Custom Matrix Bridge API** with BSN mapping database.

**Documentation**:
- [Matrix Bridge API](matrix-bridge-api.html) - RESTful API that Chat Backend calls
- [Chat Backend Webhook API](chat-backend-webhook-api.html) - Webhook endpoints for event notifications

**Features**:
- Custom REST endpoints with simple JSON (no FHIR knowledge required for Chat Backend)
- Database for BSN ↔ Matrix user ID mapping
- Auto-provisioning of Matrix accounts on first use
- Webhook notifications to Chat Backend
- BSN in all requests (POST body, never URL)

**Architecture**:
```
Chat Backend → Matrix Bridge API → Matrix Homeserver
                   ↓
              Database (BSN mapping)
```

## 🔐 Security & Privacy

### BSN Handling

**Critical Security Rules**:
- ❌ **NEVER BSN in URL parameters** (web server logs, proxy logs, browser history)
- ✅ **Always BSN in POST request body**
- ✅ **HTTPS required** (also internal network)
- ✅ **No BSN logging** in application logs
- ✅ **Encrypted storage** of BSN ↔ Matrix user ID mapping

**Design Pattern**:
```
❌ Bad:  GET /api/v1/care-networks?bsn=123456789
✅ Good: POST /api/v1/care-networks/discover
         Body: { "bsn": "123456789" }
```

### Matrix Bridge Database

- **Encrypted at rest**
- **Only BSN ↔ Matrix user ID mappings**
- **BSN never in Matrix homeserver itself**
- **Access control** on mapping database

## 🚀 Implementation

For detailed API specifications and implementation details, see:
- [Matrix Bridge API](matrix-bridge-api.html) - Matrix Bridge API endpoints
- [Chat Backend Webhook API](chat-backend-webhook-api.html) - Webhook event notifications

## 📚 Reference Documentation

### Matrix Specification for Instant Network Communication

See the [Matrix specification for instant network communication](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie) for the complete specification, including:

- **Identity & Authentication**: UZI/URA 3PIDs, homeserver assignment
- **Communication Model**: Spaces (CareTeams), Rooms (threads), Power levels
- **Onboarding**: Healthcare provider vs RelatedPerson vs Client flows
- **Service Discovery**: mCSD, LRZA, Generic Function Addressing
- **FHIR Mapping**: Organization, Practitioner, PractitionerRole, Patient, RelatedPerson

### mCSD and Generic Function Addressing

See [mCSD and Generic Function Addressing](mcsd-integration.html) for understanding the role of mCSD in POC IZNC:

- **Identity Scope**: BSN (patients) vs UZI/URA (practitioners/organizations)
- **POC Context**: Why mCSD is not required for core BSN-based discovery
- **Potential Use Cases**: Practitioner enrichment and invitation features
- **mCSD Resources**: Organization, Practitioner, PractitionerRole with Matrix IDs
- **Future Integration**: Optional enhancement for cross-organization practitioner discovery

### Hackathon Experience

See the [Hackathon Guide](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie/tree/main/hackathon_september_2025) for:

- Live OZO test environment endpoints
- Cross-homeserver federation demo
- Success criteria for interoperability

## 📞 Support & Contact

For questions about this POC or the Matrix specification:
- **Matrix specification for instant network communication**: [GitHub Repository](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie)
- **Matrix Protocol**: https://spec.matrix.org/

## 📝 License

This documentation follows the license of the Matrix specification for instant network communication:
[Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/)

---

**Version**: 0.1.1
**Status**: Draft Specification - Open for Review
**Last Update**: 2025-01-14
