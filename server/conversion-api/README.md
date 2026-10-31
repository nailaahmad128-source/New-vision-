# ScanFlow Conversion Server

Office-to-PDF through Gotenberg and LibreOffice.

Supported: DOC, DOCX, XLS, XLSX, PPT, PPTX, ODT, ODS, ODP, RTF, TXT, CSV.

## Server setup
1. Install Docker Engine and Docker Compose on a Linux VPS.
2. Copy .env.example to .env and set a long random CONVERSION_API_TOKEN.
3. Run: docker compose up -d --build
4. Check: http://127.0.0.1:8080/health
5. Keep Gotenberg port 3000 private. Add HTTPS reverse proxy before public use.

## API
POST /v1/office-to-pdf
Bearer authorization required; multipart field: file.

IMPORTANT: This is a staging gateway, not yet ready for public mobile traffic.
Do not embed the server token in the APK. User-level authentication, quotas,
HTTPS, abuse protection and load testing must be completed before app integration.

Official docs: https://gotenberg.dev/docs/convert-with-libreoffice/convert-to-pdf
