# POC IZNC - FHIR Implementation Guide

**Proof of Concept for Integrated Care Network Communication**

This is a FHIR Implementation Guide documenting the POC for connecting healthcare chat applications to the Matrix specification for instant network communication.

## 📋 About

This Implementation Guide provides comprehensive documentation for:
- Matrix Bridge API specifications
- Chat Backend Webhook API
- mCSD and Generic Function Addressing integration
- Alternative FHIR-First approach

## 🚀 Quick Start

### View Published IG

Visit the published Implementation Guide at: https://gidsopenstandaarden.github.io/poc-iznc

### Build Locally

1. **Prerequisites**:
   - Java JDK 11 or higher
   - Sushi (FHIR Shorthand) - Install: `npm install -g fsh-sushi`
   - IG Publisher

2. **Build**:
   ```bash
   # Run the IG Publisher
   ./_updatePublisher.sh

   # Or use Make
   make build
   ```

3. **View**:
   Open `output/index.html` in your browser

## 📁 Structure

```
gids-poc-iznc/
├── input/
│   ├── pagecontent/          # Markdown pages
│   │   ├── index.md          # Home page
│   │   ├── matrix-bridge-api.md
│   │   ├── chat-backend-webhook-api.md
│   │   ├── mcsd-integration.md
│   │   └── fhir-first-approach.md
│   ├── images/               # Generated PNG diagrams
│   ├── images-source/        # PlantUML source files
│   └── fsh/                  # FHIR Shorthand definitions
├── sushi-config.yaml         # IG configuration
├── CHANGELOG.md              # Version history
└── CLAUDE.md                 # Development conversation log
```

## 🔗 Related Repositories

- [Matrix Specification for Instant Network Communication](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie)
- [Hackathon Guide](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie/tree/main/hackathon_september_2025)

## 📝 License

This documentation is released under the [Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) license](https://creativecommons.org/licenses/by-sa/4.0/).

## 👥 Contributors

- **Author**: roland@headease.nl
- **Publisher**: Headease

## 📞 Support

For questions or issues:
- Open an issue on [GitHub](https://github.com/GIDSOpenStandaarden/poc-iznc/issues)
- See the [Matrix specification](https://github.com/GIDSOpenStandaarden/toepassing-instante-communicatie)

---

**Version**: 0.1.1
**Status**: Draft - Open for Review
**FHIR Version**: 4.0.1
