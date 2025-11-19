# Claude Code Conversation History

## Project: Proof of Concept - Integrale Zorg Netwerk Communicatie (IZNC)

---

### Copyright

**Author**: roland@headease.nl

This document is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

---

## Overview

This document tracks the development conversation and decisions made during the creation of the POC IZNC API specifications for integrating commercial healthcare chat applications with the Matrix specificatie instante netwerk communicatie.

## Conversation History

### Session 1: Initial Setup and Architecture Definition

**Date**: 2025-01-13

#### Tasks Completed

1. **Terraform Configuration Update**
   - Added `https://proxy.matrix.ozo.headease.nl/fhir` to `config.mcsd.adminexclude` list
   - Converted single value to list format in `/Users/roland/Documents/Projects/HeadEase/OZO/integrale-netwerk-communicatie/terraform/nuts-knooppunt.tf`

2. **API Specification Development**
   - Created **Matrix Bridge API** specification (`specs/matrix-bridge-api.md`)
   - Created **Chat Backend Webhook API** specification (`specs/chat-backend-webhook-api.md`)
   - Created **FHIR-First Approach** alternative architecture (`specs/fhir-first-approach.md`)

3. **Documentation Structure**
   - Created comprehensive `README.md` for the POC
   - Documented architecture, identity model, and security patterns
   - Added implementation phases and technical stack details

#### Key Design Decisions

**BSN Security Pattern**
- **Decision**: BSN must NEVER be in URL parameters
- **Rationale**: Security audit compliance - URL parameters appear in logs
- **Implementation**: All BSN values in POST request body only
- **Pattern**:
  ```
  ❌ Bad:  GET /api/v1/care-networks?bsn=123456789
  ✅ Good: POST /api/v1/care-networks/search
           Body: { "bsn": "123456789" }
  ```

**Identity Model - BSN Abstraction Layer**
- **Decision**: Matrix Bridge API stores BSN ↔ Matrix user ID mapping
- **Rationale**: Chat Application Backend should only work with BSN, never see Matrix complexity
- **Implementation**:
  - Chat Backend sends BSN in all API calls
  - Matrix Bridge resolves BSN → Matrix user ID internally
  - Encrypted database storage for mapping
  - Auto-provisioning: first BSN use creates Matrix account

**Architecture Simplification**
- **Decision**: Single "Matrix Bridge API" component (not separate "Matrix Bridge" and "Matrix Bridge API")
- **Rationale**: Clearer architecture - one new component that handles everything
- **Implementation**: Matrix Bridge API includes:
  - BSN-based user discovery
  - Care network/thread management
  - Message operations
  - Webhook event notifications
  - Matrix ↔ FHIR synchronization
  - Implements Matrix Spec INNC

**Two API Pattern**
- **Decision**: Two separate APIs instead of single bidirectional API
- **APIs**:
  1. **Matrix Bridge API**: REST endpoints that Chat Backend CALLS
  2. **Chat Backend Webhook API**: Endpoints that Matrix Bridge CALLS
- **Rationale**: Follows FHIR subscription pattern, clear separation of concerns

#### Specification Naming Clarification

**Matrix Specificatie vs NUTS Spec**
- **Issue**: Confusion between "NUTS spec" and the Matrix specification
- **Resolution**:
  - The specification in `../specificatie.md` is the **"Matrix specificatie instante netwerk communicatie"**
  - NUTS spec is something different
  - Updated all references throughout documentation
  - Changed title in `specificatie.md` from "Toepassing instante communicatie" to "Matrix specificatie instante netwerk communicatie"

#### FHIR-First Option Removal from README

**Decision**: Remove FHIR-First approach from main README
- **Rationale**: README should focus on the Custom Matrix Bridge API approach only
- **Implementation**:
  - Removed "Integration Layer (POC Varianten)" with two options
  - Removed comparison table
  - Simplified architecture diagram
  - FHIR-First approach still documented in `specs/fhir-first-approach.md` for reference

#### Architecture Evolution

**Initial Diagram** (with variants):
```
Chat Backend
    ↓
Integration Layer (POC Varianten)
  - Optie 1: Custom Matrix Bridge API
  - Optie 2: Direct FHIR API
    ↓
Matrix Bridge (EXISTING)
    ↓
Matrix Homeserver | FHIR Server
```

**Final Simplified Diagram**:
```
Chat Backend
    ↓
Matrix Bridge API (NEW)
  - BSN-based user discovery
  - Care network/thread management
  - Message operations
  - Webhook event notifications
  - Implements Matrix Spec INNC
  - Syncs Matrix ↔ FHIR
    ↓
Matrix Homeserver | FHIR Server
```

### Session 2: Copyright and Licensing

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Copyright Headers Added**
   - Added copyright headers to all specification files in `specs/` directory
   - Author: roland@headease.nl
   - License: Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
   - Files updated:
     - `specs/matrix-bridge-api.md`
     - `specs/chat-backend-webhook-api.md`
     - `specs/fhir-first-approach.md`

2. **Project Documentation**
   - Created this `CLAUDE.md` file to track conversation history and decisions

## Technical Details

### API Endpoints (Matrix Bridge API)

**Discovery**:
- `POST /api/v1/care-networks/search` - Find care networks for BSN

**Subscriptions**:
- `POST /api/v1/subscriptions` - Subscribe to events
- `DELETE /api/v1/subscriptions/{id}` - Unsubscribe

**Threads**:
- `POST /api/v1/care-networks/{id}/threads/search` - Get threads in care network
- `POST /api/v1/threads` - Create new thread
- `POST /api/v1/threads/{id}/messages/search` - Get messages in thread
- `POST /api/v1/threads/{id}/messages` - Send message
- `POST /api/v1/threads/{id}/read` - Mark thread as read

### Webhook Events (Chat Backend Webhook API)

- `message.new` - New message in thread
- `message.read` - Message marked as read
- `thread.new` - New thread created
- `participant.joined` - User joined thread
- `participant.left` - User left thread

### Message Flow Example

```
1. Frontend → Chat Backend (WebSocket)
   { "action": "sendMessage", "threadId": "...", "text": "..." }

2. Chat Backend → Matrix Bridge API (HTTP POST)
   POST /api/v1/threads/{threadId}/messages
   { "senderBsn": "123456789", "text": "..." }

3. Matrix Bridge API
   - Resolve BSN → Matrix user ID (or auto-provision)
   - Send Matrix event to homeserver
   - Sync Matrix event to FHIR server
   - Creates FHIR Communication resource

4. Matrix Bridge API → Chat Backend (Webhook)
   POST /webhooks/matrix-events
   { "eventType": "message.new", "data": {...} }

5. Chat Backend → Frontend (WebSocket)
   Push notification to other participants
```

## Outstanding Specification Items

### BSN-based Discovery

**Status**: To be added to Matrix specification

The POC introduces a **BSN-based discovery mechanism** not currently in the Matrix spec:

**Current Matrix Spec**:
- Discovery via UZI/URA for healthcare professionals
- mCSD for practitioner lookup
- BSN only in Matrix invite events

**POC Addition**:
- `POST /api/v1/care-networks/search` with BSN in request body
- Matrix Bridge resolves BSN → Matrix user ID internally
- Discovers all Matrix spaces where user is member

**Future Actions**:
- Document this discovery mechanism in Matrix spec
- Security review of BSN in API calls
- Alignment with community on BSN-based endpoints

### Other Considerations

- **Auto-provisioning**: Automatically create Matrix accounts on first BSN use
- **Webhook pattern**: Event notifications for push-based updates (not in current spec)
- **BSN mapping storage**: Encrypted storage requirements need documentation

## References

### Documentation Files
- `README.md` - Main POC overview and architecture
- `specs/matrix-bridge-api.md` - REST API specification (Chat Backend → Matrix Bridge)
- `specs/chat-backend-webhook-api.md` - Webhook API specification (Matrix Bridge → Chat Backend)
- `specs/fhir-first-approach.md` - Alternative FHIR-first architecture (reference only)

### External References
- Matrix specificatie instante netwerk communicatie: `../specificatie.md`
- Hackathon Guide: `../hackathon_september_2025/HACKATHON_GUIDE.md`
- OZO Implementation Guide: https://ozo-implementation-guide.headease.nl/interaction-messaging.html
- Matrix Protocol: https://spec.matrix.org/
- FHIR R4: https://hl7.org/fhir/R4/

## File Structure

```
poc-iznc/
├── README.md                           # Main POC documentation
├── CLAUDE.md                          # This file - conversation history
└── specs/
    ├── matrix-bridge-api.md           # REST API spec (Chat Backend calls)
    ├── chat-backend-webhook-api.md    # Webhook spec (Matrix Bridge calls)
    └── fhir-first-approach.md         # Alternative architecture (reference)
```

## Next Steps

### Implementation Phases

**Phase 1: Core Messaging**
- [ ] Matrix Bridge implementation with BSN mapping
- [ ] Care network discovery
- [ ] Thread listing and retrieval
- [ ] Send messages (text only)
- [ ] Retrieve messages

**Phase 2: Event Notifications**
- [ ] Subscription management
- [ ] Webhook infrastructure
- [ ] Event polling as fallback
- [ ] message.new, message.read, thread.new events

**Phase 3: Rich Features**
- [ ] Attachments (upload/download)
- [ ] Read receipts
- [ ] Message reactions
- [ ] User search

**Phase 4: Advanced**
- [ ] Thread/reply support
- [ ] Message formatting (markdown)
- [ ] Typing indicators
- [ ] User presence status

### Session 3: Cleanup FHIR References from README

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **README.md Cleanup**
   - Removed confusing FHIR synchronization references from README.md
   - Clarified that Custom Matrix Bridge API approach does NOT include direct FHIR integration
   - Maintained clear separation between Custom API approach (README.md) and FHIR-First approach (specs/fhir-first-approach.md)

#### Changes Made

**Removed/Updated FHIR References**:
- Line 5: Removed "en FHIR synchronisatie" from overview
- Line 7: Removed "automatisch wordt gesynchroniseerd met FHIR resources"
- Line 34: Removed "- Syncs Matrix ↔ FHIR" from Matrix Bridge API features
- Lines 39-40: Removed FHIR Server from architecture diagram
- Lines 214-215: Removed FHIR sync steps from message flow
- Section "📊 Compliance & Audit": Removed FHIR Resources subsection, kept only Matrix audit trail
- Integration tests: Removed "FHIR synchronization", added "BSN mapping accuracy"
- Reference docs: Removed OZO Implementation Guide section (FHIR-specific)
- Removed FHIR R4 from Support & Contact section
- Removed FHIR Server from Bestaande Componenten

**Rationale**:
- README.md describes the **Custom Matrix Bridge API** approach
- This approach uses a BSN-based API with NO direct FHIR integration in the API layer
- FHIR synchronization is handled by the existing matrix-bridge (separate component), not by Matrix Bridge API
- FHIR-First approach is documented separately in `specs/fhir-first-approach.md`
- Keeping these separate prevents confusion about which architecture is being described

**Updated Architecture Diagram** (now in README.md):
```
Chat Backend
    ↓
Matrix Bridge API (NEW)
  - BSN-based user discovery
  - Care network/thread management
  - Message operations
  - Webhook event notifications
  - Implements Matrix Spec INNC
    ↓
Matrix Homeserver (Synapse)
```

**Key Principle**:
- Matrix Bridge API is a **pure BSN-to-Matrix abstraction layer**
- No FHIR knowledge required for Chat Backend developers
- Simpler API, simpler architecture description

### Session 4: Major Documentation Restructuring

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **README.md Simplification**
   - Removed excessive implementation details that belonged in API spec
   - Removed entire sections: Testing, Compliance & Audit, Message Flow Voorbeeld, Technische Stack, Openstaande Specificatie Items
   - Simplified "Implementatie Fases" to simple "Implementatie" section with links to specs
   - README.md is now a high-level overview document only

2. **matrix-bridge-api.md Updates**
   - Removed all FHIR references from overview and architecture
   - Updated architecture diagram to remove FHIR Server
   - Removed FHIR-based BSN resolution from Implementation Notes
   - Replaced with encrypted database approach for BSN mapping
   - Added new "Specification Extensions" section documenting BSN-based Discovery
   - Removed OZO Implementation Guide from references
   - Updated references to use relative path to specificatie.md

#### Rationale for Restructuring

**Problem**:
- README.md contained too much duplication with specs/matrix-bridge-api.md
- FHIR references were confusing since Custom API approach doesn't use FHIR
- Detailed implementation info (testing, tech stack, message flows) cluttered the README
- BSN-based Discovery was documented in wrong place (README instead of API spec)

**Solution**:
- **README.md** = High-level overview and architecture description only
- **specs/matrix-bridge-api.md** = Complete API specification with implementation details
- **specs/fhir-first-approach.md** = Alternative FHIR-based architecture (reference only)

**New Structure**:
```
README.md (simplified):
├── Overzicht
├── Architectuur (High-Level)
├── Belangrijkste Concepten
│   ├── Identiteitsmodel
│   └── Care Network Structuur
├── API Specificaties (links to specs)
├── Beveiliging & Privacy
├── Implementatie (links to specs)
└── Referentie Documentatie

specs/matrix-bridge-api.md (complete):
├── Overview
├── Architecture
├── Security and Identity Model
├── API Endpoints (all endpoints)
├── Webhook Notifications
├── Error Responses
├── Implementation Notes
├── Specification Extensions (NEW)
│   ├── BSN-based Discovery
│   └── Other Extensions
└── References
```

#### Key Changes Summary

**README.md**:
- Removed: Testing, Compliance & Audit, Message Flow, Technische Stack, BSN-based Discovery, Openstaande Specificatie Items
- Simplified: Implementatie Fases → Implementatie (just links)
- Kept: High-level architecture, identity model, security principles

**specs/matrix-bridge-api.md**:
- Removed: All FHIR references (overview, architecture, backend actions, implementation notes)
- Added: "Specification Extensions" section with BSN-based Discovery documentation
- Updated: BSN resolution uses encrypted database instead of FHIR lookup
- Updated: References section to use relative paths

**Impact**:
- Clear separation of concerns between overview (README) and detailed spec (API doc)
- No more confusion about FHIR in Custom API approach
- Documentation accurately reflects the architecture choice
- BSN-based Discovery properly documented as spec extension

### Session 5: URA-based Care Network Discovery

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Care Network Discovery API Update**
   - Renamed endpoint: `/api/v1/care-networks/search` → `/api/v1/care-networks/discover`
   - Changed input model: BSN-only → URA identifiers + BSN
   - Updated request to include `uras` array and `userBsn` field
   - Updated response to include `ura` and `organizationName` per care network
   - Updated backend action to query by URA and verify user membership

2. **Specification Extensions Update**
   - Changed from "BSN-based Discovery" to "URA-based Care Network Discovery"
   - Documented that Chat Application Backend knows user's organizations (URAs)
   - Clarified typical one-to-one mapping (one care network per URA) but multiple is possible
   - Updated rationale to emphasize organizational context

#### Design Decision: URA as Discovery Key

**Previous Approach**:
```json
POST /api/v1/care-networks/search
{
  "bsn": "123456789"
}
```
- Matrix Bridge would find ALL spaces where user is member
- No organizational filtering
- Chat Backend doesn't control scope

**New Approach**:
```json
POST /api/v1/care-networks/discover
{
  "uras": ["90000001", "90000002"],
  "userBsn": "123456789"
}
```
- Chat Backend provides URA context (organizations user is involved with)
- Matrix Bridge filters care networks by URA
- Typically one care network per URA, but list allows for multiple
- BSN used for authorization only, not as discovery key
- Better privacy: BSN not the primary search parameter

**Rationale**:
1. **Organizational Context**: Users work within specific care organizations
2. **Chat Backend Knowledge**: Chat Backend already knows which organizations (URAs) the user is involved with
3. **Scoped Discovery**: Only discover care networks relevant to user's organizations
4. **Privacy**: BSN used for auth verification, not as primary search key
5. **Flexibility**: Array response allows for edge cases (multiple care networks per URA)

**Response Structure**:
```json
{
  "careNetworks": [
    {
      "careNetworkId": "!space123:matrix.domain.com",
      "ura": "90000001",
      "organizationName": "Ziekenhuis Voorbeeld",
      "name": "Zorgnetwerk Jan Jansen - Ziekenhuis Voorbeeld",
      ...
    },
    {
      "careNetworkId": "!space456:matrix.domain.com",
      "ura": "90000002",
      "organizationName": "Huisartsenpraktijk De Hof",
      ...
    }
  ]
}
```

**Implementation Notes**:
- Matrix spaces must store URA in metadata for filtering
- Backend verifies user membership in discovered spaces
- Typical use case: one care network per organization (URA)
- Edge case support: multiple care networks per organization

### Session 6: Remove Client References for Public Release

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Removed VGZ References**
   - Replaced all "VGZ" references with generic "iznc" or removed them
   - Changed Matrix user ID format from `@vgz_{hash}:vgz.matrix.nl` to `@iznc_{hash}:homeserver.example.com`
   - Updated supplier-specific examples to use generic `supplier-a.example.com`, `supplier-b.example.com`
   - Removed specific client references from README.md overview

2. **Standardized Domain Names**
   - Replaced all `matrix.domain.com` with `homeserver.example.com`
   - Replaced all `chat-backend.internal` with `chat-backend.example.com`
   - Ensured all domain examples use `example.com` per RFC 2606

3. **Files Updated**
   - `specs/matrix-bridge-api.md`: All VGZ references, domain names
   - `specs/chat-backend-webhook-api.md`: All VGZ references, domain names
   - `specs/fhir-first-approach.md`: Checked (no VGZ references found)
   - `README.md`: VGZ chat platform reference, user ID format
   - `CLAUDE.md`: Checked (no VGZ references found)

#### Rationale

**Preparing for Public GitHub Release**:
- Documentation should use generic examples, not client-specific references
- `example.com` is the standard domain for documentation (RFC 2606)
- `iznc` (Integrale Zorg Netwerk Communicatie) is project-specific, not client-specific
- Maintains professional, vendor-neutral appearance

**Replacements Applied**:
```bash
# VGZ references
vgz.matrix.nl → homeserver.example.com
@vgz_ → @iznc_
VGZ's chat platform → commerciële zorgchat applicatie

# Domain standardization
matrix.domain.com → homeserver.example.com
chat-backend.internal → chat-backend.example.com

# Supplier examples
vgz.nl → supplier-a.example.com
azora.nl → supplier-b.example.com
```

**Impact**:
- Documentation now ready for public GitHub release
- No client-specific information exposed
- Professional, vendor-neutral presentation
- All examples use RFC 2606 compliant domains

### Session 7: Add DRAFT Status to API Specifications

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Added DRAFT Status to API Specifications**
   - Added prominent DRAFT banner to `specs/matrix-bridge-api.md`
   - Added prominent DRAFT banner to `specs/chat-backend-webhook-api.md`
   - Status indicates specification is open for review and feedback
   - Notes that implementation details may change based on community input

#### Status Banner Format

Added at the top of each specification (after title, before copyright):

```markdown
> **⚠️ STATUS: DRAFT - FOR REVIEW**
>
> This specification is currently in draft status and is open for review and feedback. Implementation details may change based on community input and practical experience.
```

#### Rationale

**Transparent Communication**:
- Makes it clear these are draft specifications, not finalized standards
- Invites community feedback and collaboration
- Sets appropriate expectations for implementers
- Indicates specifications may evolve based on practical experience

**Professional Standards**:
- Common practice in open-source specification development
- Aligns with RFC and W3C draft conventions
- Provides clear status indicator for readers

### Session 8: Translate README.md to English

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Translated README.md from Dutch to English**
   - Translated all section headings and content
   - Maintained consistent terminology with API specifications
   - Kept technical terms and acronyms unchanged (BSN, UZI, URA, etc.)
   - Updated title to reflect full name: "Integrated Care Network Communication (IZNC)"

#### Key Translations

**Section Headings**:
- Overzicht → Overview
- Belangrijkste Concepten → Key Concepts
- Identiteitsmodel → Identity Model
- Beveiliging & Privacy → Security & Privacy
- Implementatie → Implementation
- Referentie Documentatie → Reference Documentation

**Terminology Consistency**:
- "Zorgnetwerk" → "Care network"
- "Zorgverlener" → "Care provider" / "Healthcare provider"
- "Mantelzorger" → "Informal caregiver"
- "Cliënt" → "Client"
- "Kritieke Beveiligingsregels" → "Critical Security Rules"

#### Rationale

**Language Consistency**:
- All API specifications are in English
- README.md should match the language of technical specifications
- Facilitates international collaboration and review
- Standard practice for open-source projects on GitHub

**Professional Presentation**:
- English is the lingua franca for technical documentation
- Easier for international reviewers and implementers
- Aligns with Matrix protocol documentation language
- Maintains accessibility for Dutch speakers (technical terms retained)

**Technical Terms Preserved**:
- BSN (Burgerservicenummer) - Dutch citizen service number
- DigID - Dutch digital identity system
- UZI - Healthcare provider identification
- URA - Healthcare organization identification
- These terms are specific to Dutch healthcare context

### Session 9: Create CHANGELOG.md

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Created CHANGELOG.md**
   - Follows [Keep a Changelog](https://keepachangelog.com/) format
   - Uses [Semantic Versioning](https://semver.org/)
   - Documents all changes from development sessions
   - Includes initial v0.1.0 release and unreleased changes

2. **Added to Git**
   - Staged CHANGELOG.md for commit
   - Ready for version control

#### Changelog Structure

**Format**: Keep a Changelog 1.0.0
- `[Unreleased]` - Changes since last version
- `[0.1.0] - 2025-01-13` - Initial release

**Categories Used**:
- `Added` - New features and specifications
- `Changed` - Changes to existing functionality
- `Security` - Security-related changes and guidelines
- `Documentation` - Documentation updates

**Key Entries**:

**Unreleased**:
- URA-based care network discovery
- English language documentation
- Client reference removal (VGZ → generic)
- Domain standardization (example.com)
- README.md simplification

**Version 0.1.0**:
- Initial API specifications (Matrix Bridge API, Webhook API)
- FHIR-First alternative approach
- Architecture documentation
- Identity model (BSN abstraction)
- Security guidelines

#### Additional Sections

**Project Status**:
- Current phase: Draft Specification - Open for Review
- Next steps outlined for implementation

**Contributing**:
- Guidelines for community feedback
- How to contribute to specifications

#### Rationale

**Professional Standards**:
- CHANGELOG.md is standard for open-source projects
- Helps users track changes and understand project evolution
- Provides clear history for reviewers and implementers
- Follows widely-adopted format (Keep a Changelog)

**Version Management**:
- Semantic versioning provides clear version indicators
- Unreleased section tracks ongoing work
- Tagged versions mark milestones

**Transparency**:
- Complete history of design decisions
- Security changes clearly highlighted
- Easy to see what changed and why

### Session 10: Add Version Number and Update CHANGELOG

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Added Version to README.md**
   - Version: 0.1.0 (2025-01-13)
   - Added at top of document and in footer
   - Updated status to "Draft Specification - Open for Review"

2. **Updated CHANGELOG.md**
   - Consolidated all changes into version 0.1.0
   - Moved "Unreleased" changes to 0.1.0 release
   - Added comprehensive summary of initial release
   - Organized changes by category (Added, Changed, Security, Design Decisions)
   - Cleaned up [Unreleased] section for future changes

#### Version Strategy

**Semantic Versioning**: 0.1.0
- **0** (Major): Pre-1.0 indicates draft/unstable API
- **1** (Minor): First minor version with complete initial specifications
- **0** (Patch): No patches yet

**Version Placement**:
- Top of README.md: `**Version**: 0.1.0 (2025-01-13)`
- Bottom of README.md: Version, Status, Last Update
- CHANGELOG.md: `## [0.1.0] - 2025-01-13`

#### CHANGELOG.md Structure (Final)

```markdown
## [Unreleased]
### Changed
- None yet

## [0.1.0] - 2025-01-13
### Summary
Initial release of POC IZNC API specifications...

### Added
- API Specifications (DRAFT)
- Documentation

### Changed
- URA-based discovery
- Domain standardization
- Language translation

### Security
- BSN handling requirements

### Design Decisions
- Architecture choices
```

#### Rationale

**Version Visibility**:
- Users immediately see version when opening README.md
- Clear indication this is draft/pre-release (0.x.x)
- Date-based tracking for POC development

**CHANGELOG Consolidation**:
- All development work captured in 0.1.0
- Clean starting point for future changes
- Comprehensive release notes for reviewers

**Professional Standards**:
- Follows semantic versioning conventions
- CHANGELOG follows Keep a Changelog format
- Clear version progression path (0.1.0 → 0.2.0 → ... → 1.0.0)

### Session 11: Translate FHIR-First Approach to English

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Translated fhir-first-approach.md from Dutch to English**
   - Complete translation of all sections and content
   - Maintained consistent terminology with other specifications
   - Updated example messages to English
   - Kept technical terms (BSN, UZI, URA, FHIR resources) unchanged

#### Key Sections Translated

- Overzicht → Overview
- Architectuur Vergelijking → Architecture Comparison
- Voordelen FHIR-First → Advantages of FHIR-First
- Operatie Flows → Operation Flows
- Identiteit & Beveiliging → Identity & Security
- Chat Backend Implementatie → Chat Backend Implementation
- Migratie → Migration
- Aanbeveling → Recommendation

#### Minor Updates

- Updated webhook URL to `chat-backend.example.com` (from chat-backend.internal)
- Translated example message content:
  - "Afspraak maken voor controle" → "Schedule appointment for checkup"
  - "Kan ik deze medicatie met eten innemen?" → "Can I take this medication with food?"
  - "Ja, u kunt het innemen met of zonder voedsel" → "Yes, you can take it with or without food"

#### Rationale

**Complete English Documentation**:
- All three specification documents now in English
- Consistent language across the entire POC IZNC project
- Ready for international review and collaboration
- Professional presentation for GitHub publication

**Alternative Architecture Documentation**:
- FHIR-First approach clearly documented as alternative
- Helps reviewers understand trade-offs between approaches
- Provides complete comparison for informed decision-making

### Session 12: Correct FHIR Subscription Webhook Pattern

**Date**: 2025-01-13 (continued)

#### Tasks Completed

1. **Corrected FHIR Subscription Notification Format**
   - Changed webhook notification to use minimal payload with resource reference only
   - Updated notification format to use `Parameters` resource with `focus` parameter
   - Added explanation that notifications trigger GET requests to fetch actual resources
   - Updated webhook handler code to fetch resources after notification

2. **Updated Webhook Handler Implementation**
   - Modified code to acknowledge webhook immediately (200 response)
   - Added asynchronous processing of notifications
   - Implemented resource fetch based on reference from notification
   - Extracted resource reference from Parameters.parameter

#### Key Correction

**Previous (Incorrect) Approach**:
```json
// Notification with full resource content
{
  "resourceType": "Bundle",
  "entry": [{
    "resource": {
      "resourceType": "Communication",
      "id": "567",
      "payload": [...]  // Full resource content
    }
  }]
}
```

**Corrected Approach**:
```json
// Subscription without payload field (omitted for empty notification)
// Endpoint includes subscription ID in path
{
  "resourceType": "Subscription",
  "channel": {
    "type": "rest-hook",
    "endpoint": "https://chat-backend.example.com/fhir/webhooks/sub-123"
    // No "payload" field = no resource content in notification
  }
}
```

```http
// FHIR server sends empty POST to subscription-specific endpoint
POST /fhir/webhooks/sub-123
Authorization: Bearer {token}

(empty body)
```

**Implementation Pattern**:
1. Subscription omits `payload` field for empty notifications
2. Subscription endpoint includes subscription ID in URL path
3. FHIR server sends empty POST to subscription-specific endpoint
4. Chat Backend extracts subscription ID from URL path
5. Chat Backend acknowledges immediately (200 OK)
6. Chat Backend fetches updates: `GET /fhir/Communication/_history?_since={lastSync}&subject=Patient/123`
7. Chat Backend processes all returned resources
8. Chat Backend updates lastSync timestamp

#### Rationale

**FHIR R4 Subscription Best Practice**:
- Omit `payload` field for empty notifications (most common pattern)
- Notifications should contain no body (empty POST)
- Client must fetch updates using `_history` with `_since` parameter
- Subscription ID embedded in endpoint URL for routing
- Prevents large payloads in webhook notifications
- Allows server to control access via GET request authentication
- Standard FHIR Subscription `rest-hook` pattern with empty payload

**Security Benefits**:
- Resource content not sent in webhook payload
- Access control enforced on GET request
- Audit trail for resource access
- Prevents unauthorized access via intercepted webhooks

**Performance Considerations**:
- Smaller webhook payloads
- Faster notification delivery
- Server can batch/optimize GET requests
- Client acknowledges receipt immediately

---

**Status**: Proof of Concept - In Development
**Version**: 0.1.0
**Last Update**: 2025-01-13
