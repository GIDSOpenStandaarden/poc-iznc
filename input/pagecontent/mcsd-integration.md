# mCSD and Generic Function Addressing in POC IZNC Context

> **⚠️ STATUS: DRAFT - FOR REVIEW**
>
> This specification is currently in draft status and is open for review and feedback. Implementation details may change based on community input and practical experience.

---
### Copyright

**Author**: roland@headease.nl

This document is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

---

## Overview

This document describes the role of **mCSD (Mobile Care Services Discovery)** and **Generieke Functie Adressering (Generic Function Addressing)** in the context of the POC IZNC implementation.

### Important Identity Distinction

**mCSD is ONLY for healthcare provider infrastructure**:
- ✅ **Practitioners**: Identified by **UZI numbers** - provisioned via mCSD
- ✅ **Organizations**: Identified by **URA numbers** - provisioned via mCSD
- ❌ **Patients**: Identified by **BSN** - **NOT related to mCSD in any way**

The POC IZNC uses BSN-based discovery for patients/users, which is completely separate from mCSD. Understanding mCSD is important for the broader Matrix specification context, particularly for **healthcare provider discovery** and **cross-organization federation**.

## What is mCSD?

**mCSD (Mobile Care Services Directory)** is an IHE (Integrating the Healthcare Enterprise) profile that provides a structured way to discover healthcare services, practitioners, organizations, and locations. It uses FHIR resources to create a searchable directory of care services and providers.

### Key FHIR Resources in mCSD

**Core mCSD Resources** (healthcare provider infrastructure):
1. **Organization** - Healthcare provider organizations (identified by **URA number**)
2. **Practitioner** - Individual healthcare professionals (identified by **UZI number**)
3. **PractitionerRole** - Links practitioners to organizations with specific roles
4. **HealthcareService** - Services offered by organizations
5. **Location** - Physical locations where services are provided
6. **Endpoint** - Technical endpoints for system-to-system communication

**Additional Resources** (may be published in mCSD, but NOT identified by UZI/URA):
- **Patient** - Clients with optional Matrix access (identified by **BSN**, not via mCSD)
- **RelatedPerson** - Informal caregivers and family members (identified by **email**, not via mCSD)

> **Important**: BSN (patient identifier) is completely separate from mCSD. mCSD is specifically for discovering **healthcare provider infrastructure** (practitioners and organizations) using UZI and URA numbers.

## Generieke Functie Adressering (Generic Function Addressing)

**Generieke Functie Adressering** is a Dutch healthcare initiative that implements mCSD-based directory services for routing and addressing between healthcare organizations.

### LRZA (Landelijke Register Zorgadressering)

The **LRZA (National Registry for Healthcare Addressing)** serves as the central index where:
- Each healthcare organization registers their FHIR endpoint URL
- Each organization selects one service provider to host their mCSD endpoint
- The mCSD endpoint functions as an address book for the organization
- Organizations publish practitioner information including Matrix contact details

### Architecture

```
┌─────────────────────────────────────────────┐
│   LRZA (Central Registry)                   │
│   - URA → mCSD endpoint mapping             │
│   - One entry per healthcare organization   │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐   ┌──────────────┐
│ Organization │   │ Organization │
│ A mCSD       │   │ B mCSD       │
│ Endpoint     │   │ Endpoint     │
├──────────────┤   ├──────────────┤
│ - Practitioners│ │ - Practitioners│
│ - Roles       │   │ - Roles       │
│ - Services    │   │ - Services    │
│ - Matrix IDs  │   │ - Matrix IDs  │
└──────────────┘   └──────────────┘
```

### Current State (2025)

> **Note**: LRZA is not yet capable of processing Matrix-related information. Currently, **NUTS discovery** is used to determine the mCSD endpoint based on URA number.

## mCSD in the Matrix Specification

The [Matrix specification for instant network communication](../../specificatie.md) relies heavily on mCSD for:

### 1. Healthcare Provider Discovery

From the Matrix specification (Section 7):

> **Matrix User Discovery via mCSD**
> - Healthcare providers with Matrix contact information are published in mCSD records
> - Matrix addresses are stored in the telecom array of Practitioner, Patient, and RelatedPerson resources
> - Applications use mCSD to look up providers by function or location
> - During identification and onboarding, UZI number, URA number, and role code(s) are linked to Matrix user accounts as 3PIDs

### 2. Homeserver Localization

**For Healthcare Providers (Practitioners)**:
- Homeserver assignment is NOT pinned to origin organization
- Healthcare organizations choose which service provider hosts their homeserver
- The homeserver address is published via Generic Function Addressing through the mCSD endpoint
- This provides flexibility when organizations switch vendors

**For RelatedPersons and Clients**:
- Bound to the platform of origin (the care platform that onboards them)

### 3. Identity Integration

The Matrix specification describes how practitioner identity flows through mCSD:

1. User authenticates via organization's Identity Provider (IdP)
2. UZI number, URA number, and role code are obtained
3. Based on URA number, the mCSD address is looked up:
   - Currently via NUTS discovery
   - Future: via LRZA
4. Two scenarios:
   - **mCSD managed by different vendor**: Search for practitioner in external mCSD, use existing Matrix ID if found
   - **mCSD managed by current vendor**: Check local mCSD database, auto-provision Matrix account if needed

### 4. Matrix ID Storage in FHIR

Matrix contact information is stored in the `telecom` array of FHIR resources using specific extensions:

**Example: Practitioner Resource with Matrix ID**

```json
{
  "resourceType": "Practitioner",
  "id": "6a6b85e9-f7d8-4b62-8dc5-94f00b1d6594",
  "identifier": [{
    "system": "http://fhir.nl/fhir/NamingSystem/uzi-nr-pers",
    "value": "123456789"
  }],
  "name": [{
    "family": "Janssen",
    "given": ["Dr. H."]
  }],
  "telecom": [
    {
      "system": "email",
      "value": "dr.janssen@hospital-a.nl",
      "use": "work"
    },
    {
      "system": "other",
      "value": "@dr.janssen:matrix.hospital-a.nl",
      "use": "work",
      "extension": [{
        "url": "http://hl7.org/fhir/StructureDefinition/contactpoint-purpose",
        "valueString": "matrix-messaging"
      }]
    }
  ]
}
```

**ContactPoint Extensions for Matrix**:
- **`matrix-messaging`**: For individual Matrix user IDs (`@user:homeserver.nl`)
- **`matrix-homeserver`**: For homeserver addresses (`homeserver.nl`) at organization level

### 5. Organization with Homeserver Information

```json
{
  "resourceType": "Organization",
  "id": "07d91b7d-eb06-47ef-b077-28e0d274c161",
  "name": "Hospital A",
  "identifier": [{
    "system": "http://fhir.nl/fhir/NamingSystem/ura",
    "value": "00000001"
  }],
  "contact": [{
    "purpose": {
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/contactentity-type",
        "code": "ADMIN"
      }]
    },
    "telecom": [{
      "system": "other",
      "value": "matrix.hospital-a.nl",
      "use": "work",
      "extension": [{
        "url": "http://hl7.org/fhir/StructureDefinition/contactpoint-purpose",
        "valueString": "matrix-homeserver"
      }]
    }]
  }]
}
```

## mCSD Role in POC IZNC

### What POC IZNC Uses

The POC IZNC implementation takes a **different approach** that abstracts away mCSD complexity:

1. **BSN-Based Discovery** (for patients/users):
   - Chat Backend provides BSN + URA list
   - **BSN is NOT queried via mCSD** - it's a patient identifier, not a provider identifier
   - Matrix Bridge API handles user resolution internally
   - No direct mCSD queries from Chat Backend

2. **URA-Based Filtering** (for organizations):
   - Care networks discovered by URA (organization identifier)
   - **URA is provisioned by mCSD** but POC doesn't directly query mCSD
   - Matrix Bridge filters Matrix spaces by URA metadata
   - Simpler API for commercial chat applications

3. **BSN Mapping Database**:
   - Matrix Bridge maintains encrypted BSN ↔ Matrix user ID mapping
   - Auto-provisioning on first BSN use
   - **BSN mapping is completely separate from mCSD** - no FHIR knowledge required in Chat Backend

**Key Point**: POC IZNC uses BSN (patient identifier) for discovery, which has **nothing to do with mCSD**. mCSD is only relevant when discovering **practitioners** (UZI) or **organizations** (URA).

### Architecture Comparison

**Matrix Specification Approach** (with mCSD):
```
Chat App → mCSD Lookup → Matrix Homeserver
           ↓
        FHIR Resources
        (Practitioner, Organization)
```

**POC IZNC Approach** (BSN-based):
```
Chat Backend → Matrix Bridge API → Matrix Homeserver
                     ↓
              BSN Mapping DB (encrypted)
```

### When mCSD Becomes Relevant

Although POC IZNC doesn't require mCSD for basic operation (BSN-based discovery works for existing care network members), mCSD **might be used** for **practitioner-related operations**:

#### Potential Use Cases in POC IZNC

1. **Enriching Practitioner Details**:
   - Care network shows practitioners with limited information
   - Query mCSD by UZI number to get full practitioner details
   - Display: full name, role, organization, contact information
   - Enhances user experience without requiring FHIR knowledge in Chat Backend

2. **Inviting New Practitioners to Care Team**:
   - User wants to add a practitioner who isn't yet in the care network
   - Search mCSD by UZI number or name to find the practitioner
   - Retrieve their Matrix ID from mCSD
   - Invite them to the care network using discovered Matrix ID
   - This enables growing care teams dynamically

**Key Point**: mCSD is not required for core POC functionality (viewing existing care networks, reading/creating messages), but **might** be useful for practitioner management features.

#### Additional Scenarios for Production Use

Beyond the POC scope, mCSD becomes essential specifically for **practitioner discovery** (not patient/BSN discovery) in these scenarios:

#### 1. **Federated Care Networks** (Practitioner Discovery)

When a care network includes **practitioners** from **other organizations**:

- **Problem**: How does Organization A discover the Matrix ID of a **practitioner** from Organization B?
- **mCSD Solution** (uses **UZI number**, NOT BSN):
  1. Look up Organization B's mCSD endpoint via LRZA (or NUTS discovery) using **URA number**
  2. Query mCSD for practitioner by **UZI number** (practitioner identifier)
  3. Retrieve Matrix ID from practitioner's telecom array
  4. Invite practitioner to care network using Matrix ID

**Example Flow** (Practitioner Discovery):
```
Organization A needs to invite Dr. Smith (practitioner) from Organization B

1. Organization A has: UZI number of Dr. Smith (123456789) ← Practitioner identifier
2. Query LRZA: URA of Organization B → mCSD endpoint ← Organization identifier
3. Query mCSD: GET /Practitioner?identifier=http://fhir.nl/fhir/NamingSystem/uzi-nr-pers|123456789
4. Extract Matrix ID from result: @dr.smith:matrix.hospital-b.nl
5. Matrix Bridge invites: @dr.smith:matrix.hospital-b.nl to care network
```

> **Note**: This is for **practitioner** discovery only. Patients (BSN) are NOT discovered via mCSD.

#### 2. **Healthcare Provider Onboarding** (Practitioner Identity)

When a **practitioner** logs in for the first time:

- **Problem**: Does the practitioner already have a Matrix account?
- **mCSD Solution** (uses **UZI and URA**, NOT BSN):
  1. Practitioner authenticates via IdP (**UZI number**, **URA number**, role code obtained)
  2. Determine if mCSD is managed by current vendor (based on **URA**)
  3. If external: Query external mCSD for existing Matrix ID using **UZI number**
  4. If local: Check local mCSD, auto-provision if needed
  5. Store Matrix ID in mCSD for future discovery

> **Note**: This is for **practitioners** only. Patients don't authenticate via UZI/URA - they use BSN which is NOT managed by mCSD.

#### 3. **Organization Migration**

When a healthcare organization switches vendors:

- **Problem**: How do other organizations find practitioners at their new homeserver?
- **mCSD Solution**:
  1. Organization updates mCSD with new homeserver endpoints
  2. Practitioner resources updated with new Matrix IDs
  3. Other organizations query mCSD, discover new Matrix IDs
  4. Old vendor triggers re-invites with new identity
  5. Old accounts deactivated

### What POC IZNC Would Need for mCSD Integration

If the POC were to integrate with mCSD for practitioner management features, these components would be needed:

#### 1. **mCSD Query Module** (in Matrix Bridge API)

```python
class MCSDClient:
    def lookup_practitioner_matrix_id(self, uzi_number: str) -> Optional[str]:
        """
        Look up practitioner's Matrix ID via mCSD

        1. Determine organization's mCSD endpoint (via LRZA/NUTS)
        2. Query mCSD for Practitioner by UZI number
        3. Extract Matrix ID from telecom array
        4. Return Matrix ID or None
        """
        pass

    def lookup_organization_homeserver(self, ura_number: str) -> Optional[str]:
        """
        Look up organization's Matrix homeserver via mCSD

        1. Determine organization's mCSD endpoint (via LRZA/NUTS)
        2. Query mCSD for Organization by URA number
        3. Extract homeserver from telecom array
        4. Return homeserver domain
        """
        pass
```

#### 2. **Practitioner Identity Sync**

Synchronize Matrix IDs back to mCSD:

```python
class MCSDSync:
    def register_matrix_id(self, uzi_number: str, matrix_id: str):
        """
        Register Matrix ID in local mCSD

        1. Find or create Practitioner resource
        2. Add matrix-messaging telecom entry
        3. Update mCSD database
        """
        pass
```

#### 3. **Practitioner Enrichment API**

Add endpoints for getting practitioner details and searching practitioners:

```
POST /api/v1/practitioners/lookup

Purpose: Get full details about a practitioner from mCSD

Request:
{
  "uziNumber": "123456789"
}

Response:
{
  "uziNumber": "123456789",
  "matrixUserId": "@dr.smith:matrix.hospital-b.nl",
  "name": "Dr. H. Janssen",
  "organization": {
    "ura": "00000002",
    "name": "Hospital B"
  },
  "role": {
    "code": "158965000",
    "display": "Medical practitioner"
  },
  "homeserver": "matrix.hospital-b.nl",
  "email": "dr.janssen@hospital-b.nl"
}
```

```
POST /api/v1/practitioners/search

Purpose: Search for practitioners to invite to care network

Request:
{
  "name": "Janssen",
  "uraNumber": "00000002",  // Optional: filter by organization
  "roleCode": "158965000"   // Optional: filter by role
}

Response:
{
  "practitioners": [
    {
      "uziNumber": "123456789",
      "matrixUserId": "@dr.janssen:matrix.hospital-b.nl",
      "name": "Dr. H. Janssen",
      "organization": "Hospital B",
      "role": "Medical practitioner"
    },
    {
      "uziNumber": "987654321",
      "matrixUserId": "@dr.janssen2:matrix.hospital-b.nl",
      "name": "Dr. M. Janssen",
      "organization": "Hospital B",
      "role": "Specialist"
    }
  ]
}
```

## Implementation Considerations

### For POC IZNC

**Current Implementation** (v0.1.x):
- ✅ No mCSD dependency for core functionality
- ✅ Simpler Chat Backend integration
- ✅ BSN-based discovery sufficient for viewing existing care networks
- ✅ Can read/create messages without mCSD
- ⚠️ Practitioner details may be limited (only what Matrix provides)
- ⚠️ Cannot easily invite new practitioners from other organizations

**Optional Enhancement** (could be added to v0.1.x or v0.2.x):
- **Practitioner Enrichment**:
  - Query mCSD for full practitioner details (name, role, organization)
  - Display richer practitioner information in care network views
  - Improves user experience without changing core architecture

- **Practitioner Invitation**:
  - Search mCSD to find practitioners by name/role/organization
  - Retrieve Matrix IDs for invitation
  - Enable users to grow care teams dynamically
  - Essential for cross-organization collaboration

**Future Enhancement** (v0.2.x+):
- Full mCSD integration for federated discovery
- Support automatic practitioner lookup across organizations
- Align with Matrix specification identity flows
- Enable organization migration scenarios

### For Production Implementations

Production implementations should consider:

1. **mCSD Integration** for multi-organization care networks
2. **LRZA Integration** once Matrix information is supported
3. **Practitioner Sync** to keep mCSD updated with Matrix IDs
4. **Homeserver Discovery** via mCSD for organization routing

## References

- **Matrix Specification for Instant Network Communication**: `../../specificatie.md`
- **Generic Function Addressing (Routing)**: See NL Generic Functions Implementation Guide
- **IHE mCSD**: https://profiles.ihe.net/ITI/mCSD/
- **FHIR R4 Directory Resources**: https://hl7.org/fhir/R4/
- **LRZA**: https://www.vzvz.nl/diensten/lrza (Dutch National Registry)

## Summary

### Identity Scope Clarification

**What mCSD Handles** (Healthcare Provider Infrastructure):
- ✅ **Practitioners** identified by **UZI numbers**
- ✅ **Organizations** identified by **URA numbers**
- ✅ Matrix IDs for practitioners stored in FHIR telecom elements

**What mCSD Does NOT Handle** (Patient/User Identity):
- ❌ **Patients** identified by **BSN** - completely separate from mCSD
- ❌ **BSN-based discovery** - not an mCSD concern
- ❌ Patient Matrix IDs - managed by chat platforms, not mCSD

### mCSD in Context

- **Matrix Specification**: Relies on mCSD for **practitioner** discovery (UZI/URA) and homeserver localization
- **POC IZNC**: Uses simplified **BSN-based discovery** (for patients), abstracts mCSD away from Chat Backend
- **Production Use**: mCSD integration recommended for cross-organization **practitioner** discovery in federated care networks

### Key Takeaways

1. **BSN ≠ mCSD**: Patient identifiers (BSN) have nothing to do with mCSD. mCSD is for practitioners (UZI) and organizations (URA)
2. **Not Required for Core POC**: POC IZNC demonstrates Matrix integration without mCSD dependency (uses BSN-based discovery for patients)
3. **Might Be Useful for POC**: mCSD could enhance practitioner management:
   - Enriching practitioner details (full name, role, organization)
   - Inviting new practitioners who aren't yet in care teams
4. **Important for Federation**: mCSD becomes essential when discovering **practitioners** across multiple organizations
5. **Optional Integration Path**: mCSD integration can be added incrementally for **practitioner discovery** features
6. **Specification Alignment**: Understanding mCSD is important for aligning with the broader Matrix specification ecosystem, specifically for healthcare provider infrastructure

---

**Version**: 0.1.0
**Status**: Draft Specification - Open for Review
**Last Update**: 2025-01-19
