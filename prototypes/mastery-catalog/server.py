"""Read-only draft viewer. No game state, save, purchase, or content writes."""
import argparse
import hashlib
import importlib.util
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
DRAFTS = REPO / "docs/content-drafts/research-expansion"
spec = importlib.util.spec_from_file_location("progression_validator", REPO / "tools/validate_progression_drafts.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
sys.path.insert(0, str(REPO / "tools"))
import validate_build_scenarios as build_validator


def catalog():
    paths = [DRAFTS / name for name in ("mastery-nodes-v3.json", "hybrid-classes-v3.json", "build-scenarios-v1.json")]
    raw = [path.read_bytes() for path in paths]
    documents = [json.loads(blob.decode("utf-8-sig")) for blob in raw]
    errors, summary = validator.validate(*documents[:2])
    build_sources = build_validator.read_sources()
    # Validate against the same exact in-memory node/class documents sent to the UI.
    build_sources.update(master=documents[0], hybrid=documents[1])
    build_errors, build_summary = build_validator.validate(documents[2], build_sources)
    errors.extend(build_errors)
    if errors:
        raise ValueError("Draft validation failed: " + "; ".join(errors))
    return dict(status="design_draft_not_runtime", masteries=documents[0], hybrids=documents[1],
                builds=documents[2], build_validation=build_summary,
                validation=summary, sources=[dict(path=path.relative_to(REPO).as_posix(),
                sha256=hashlib.sha256(blob).hexdigest()) for path, blob in zip(paths, raw)])


def route(target):
    path = urlsplit(target).path
    if path == "/api/catalog":
        try:
            return 200, "application/json; charset=utf-8", json.dumps(catalog(), ensure_ascii=False).encode()
        except (ValueError, OSError, TypeError, KeyError) as error:
            return 422, "application/json; charset=utf-8", json.dumps({"error": str(error)}, ensure_ascii=False).encode()
    allowed = {"/": ("index.html", "text/html"), "/app.js": ("app.js", "text/javascript"),
               "/style.css": ("style.css", "text/css")}
    if path not in allowed:
        return 404, "text/plain; charset=utf-8", b"Not found"
    filename, mime = allowed[path]
    return 200, mime + "; charset=utf-8", (ROOT / filename).read_bytes()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status, mime, payload = route(self.path)
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; object-src 'none'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", action="store_true", help="Start localhost-only viewer; Ctrl-C closes this server.")
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    result = catalog()
    print(json.dumps(dict(status=result["status"], validation=result["validation"], sources=result["sources"]), ensure_ascii=False, indent=2))
    if args.serve:
        with HTTPServer(("127.0.0.1", args.port), Handler) as server:
            print(f"Read-only DRAFT viewer: http://127.0.0.1:{args.port} (Ctrl-C to stop)", flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass
