#!/usr/bin/env python3
"""Prepara la spec OpenAPI per dart_openapi_generator.

Il generatore deriva i nomi dei metodi dai path; i path con punti
(es. /feed/calendar/{token}.ics) produrrebbero identifier Dart non validi.
Aggiunge un operationId solo alle operazioni i cui path contiene un punto;
la spec sorgente (app/api/openapi.json) resta intatta.

Uso: prep_spec.py <input> <output>
"""
import json
import sys

# "VERBO /path" -> operationId (valido identifier Dart)
OPERATION_IDS = {
    "GET /api/v1/openapi.json": "getOpenApiJson",
    "GET /openapi.json": "getRootOpenApiJson",
    "GET /feed/calendar/{token}.ics": "getCalendarFeed",
    "GET /feed/inventory-deadlines/{token}.ics": "getInventoryDeadlinesFeed",
    "GET /feed/cycle/{token}.ics": "getCycleFeed",
}


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"Uso: {sys.argv[0]} <input> <output>")

    with open(sys.argv[1], encoding="utf-8") as f:
        spec = json.load(f)

    added = 0
    for path, methods in spec["paths"].items():
        if "." not in path:
            continue
        for verb, op in methods.items():
            if verb not in ("get", "post", "put", "patch", "delete"):
                continue
            key = f"{verb.upper()} {path}"
            if not op.get("operationId"):
                op["operationId"] = OPERATION_IDS.get(key)
                if op["operationId"] is None:
                    sys.exit(
                        f"Errore: path con punti non previsto: {key}. "
                        "Aggiungi l'operationId in prep_spec.py."
                    )
                added += 1

    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(spec, f, separators=(",", ":"))

    print(f"OK: {added} operationId aggiunte -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
