import os
from pathlib import Path
from typing import Annotated

import httpx
from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import Response

app = FastAPI(title="ScanFlow Conversion Gateway", version="0.1.0")
TOKEN = os.environ.get("CONVERSION_API_TOKEN", "")
GOTENBERG_URL = os.environ.get("GOTENBERG_URL", "http://gotenberg:3000").rstrip("/")
MAX_BYTES = int(os.environ.get("MAX_UPLOAD_MB", "30")) * 1024 * 1024
TIMEOUT = float(os.environ.get("CONVERSION_TIMEOUT_SECONDS", "180"))
ALLOWED = {"doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "rtf", "txt", "csv"}

@app.get("/health")
async def health():
    return {"status": "ok", "service": "scanflow-conversion-gateway"}

@app.post("/v1/office-to-pdf")
async def office_to_pdf(
    file: Annotated[UploadFile, File(...)],
    authorization: Annotated[str | None, Header()] = None,
):
    if not TOKEN:
        raise HTTPException(status_code=503, detail="Service is not configured")
    if authorization != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    filename = Path(file.filename or "document").name
    suffix = Path(filename).suffix.lower().lstrip(".")
    if suffix not in ALLOWED:
        raise HTTPException(status_code=415, detail="Unsupported document format")

    content = await file.read(MAX_BYTES + 1)
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(content) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds upload limit")

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            result = await client.post(
                f"{GOTENBERG_URL}/forms/libreoffice/convert",
                files={"files": (filename, content, file.content_type or "application/octet-stream")},
                data={"skipEmptyPages": "true", "exportBookmarks": "true"},
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Conversion timed out")
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="Conversion engine unavailable")

    if result.status_code != 200:
        raise HTTPException(status_code=422, detail="Document could not be converted")

    return Response(
        content=result.content,
        media_type="application/pdf",
        headers={
            "Content-Disposition": 'attachment; filename="scanflow-converted.pdf"',
            "Cache-Control": "no-store",
        },
    )
