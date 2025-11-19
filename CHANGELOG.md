# Changelog

All notable changes to the POC IZNC (Integrated Care Network Communication) project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- None yet

## [0.1.2] - 2025-11-19

### Summary
Infrastructure improvements and documentation link updates.

### Added
- **GitHub Actions** (`.github/workflows/build_deploy.yml`)
  - Automated build workflow using Docker
  - GitHub Pages deployment on main branch
  - Build artifact upload for each push

### Changed
- Renamed `master` branch to `main`
- Updated all relative links to `specificatie.md` to use GitHub URL
  - Now pointing to: https://github.com/nuts-foundation/toepassing-instante-communicatie/blob/main/specificatie.md
  - Updated in `matrix-bridge-api.md`, `mcsd-integration.md`, and `CLAUDE.md`
- Added PlantUML diagrams to documentation pages
  - Data model diagrams in `index.md`
  - Interaction diagrams in `matrix-bridge-api.md` and `chat-backend-webhook-api.md`
- Removed generated PNG files from git (now generated during build)

## [0.1.1] - 2025-01-14

### Summary
Improved FHIR-First approach documentation with better architecture diagrams and subscription patterns.

### Changed
- **FHIR-First Approach** (`specs/fhir-first-approach.md`)
  - Improved architecture diagram clarity with bidirectional arrows showing data flow
  - Updated Matrix Bridge to use FHIR Subscriptions (webhook notifications) instead of polling
  - Enhanced API mapping table formatting for better readability
  - Better visualization of webhook notification flows between components

## [0.1.0] - 2025-01-13

### Summary
Initial release of POC IZNC API specifications with comprehensive documentation, URA-based discovery, and production-ready security guidelines.

### Added
- **API Specifications** (DRAFT status, open for review)
  - Matrix Bridge API specification (`specs/matrix-bridge-api.md`)
    - URA-based Care Network Discovery endpoint (`POST /api/v1/care-networks/discover`)
    - Subscription Management endpoints
    - Thread Management endpoints
    - Message Operations endpoints
    - Webhook notification format
    - Error handling specifications
    - Specification Extensions section documenting deviations from Matrix spec
  - Chat Backend Webhook API specification (`specs/chat-backend-webhook-api.md`)
    - Event notification endpoints
    - Webhook payload formats
    - Retry mechanism specifications
  - FHIR-First Approach documentation (`specs/fhir-first-approach.md`)
    - Alternative architecture using FHIR API directly
    - Comparison with Custom Matrix Bridge API approach

- **Documentation**
  - README.md with high-level overview (English)
  - CLAUDE.md tracking development decisions and conversation history
  - CHANGELOG.md following Keep a Changelog format
  - Architecture diagrams and flow descriptions
  - Identity model documentation (BSN abstraction layer)
  - Comprehensive security guidelines for BSN handling
  - Implementation notes and examples
  - Copyright and licensing information (CC BY-SA 4.0)
  - Reference links to Matrix specification and related resources

### Changed
- Care network discovery endpoint renamed from `/search` to `/discover`
- Discovery mechanism changed from BSN-only to URA-based approach
  - Chat Backend provides list of URA numbers
  - Typically returns one care network per URA (multiple possible)
  - BSN used for authorization, not as primary discovery key
- All client-specific references (VGZ) replaced with generic examples
- All domain examples standardized to `example.com` (RFC 2606)
- Matrix user ID format: `@iznc_{hash}:homeserver.example.com`
- README.md translated from Dutch to English
- README.md simplified by moving implementation details to API specifications

### Security
- **BSN Handling Requirements**
  - BSN must never appear in URL parameters (always in POST body)
  - Encrypted storage for BSN ↔ Matrix user ID mappings (PostgreSQL)
  - HTTPS required for all API communication (including internal)
  - No BSN values in application logs
  - BSN only exposed in Matrix invite events per specification

### Design Decisions
- Custom Matrix Bridge API approach selected over FHIR-first
- BSN as user identifier in external API (never exposed in Matrix)
- Auto-provisioning of Matrix accounts on first BSN use
- Webhook pattern for real-time event notifications
- PostgreSQL with encryption for BSN mapping storage
- Supplier-specific Matrix homeservers for federation

---

## Project Status

**Current Phase**: Draft Specification - Open for Review

**Next Steps**:
1. Community review and feedback on API specifications
2. Prototype implementation of Matrix Bridge API
3. Integration testing with test Matrix homeserver
4. Security audit of BSN handling and encryption
5. Documentation of URA metadata storage in Matrix spaces

---

## Contributing

This is a proof-of-concept specification. Feedback and contributions are welcome:
- Review API specifications in `specs/` directory
- Provide feedback via GitHub issues
- Suggest improvements to security model
- Share implementation experiences

---

**Maintained by**: roland@headease.nl
**License**: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
