"""Middleware to log all 500 errors and display exception in debug mode."""

import logging
import traceback

from django.http import HttpResponseServerError

logger = logging.getLogger(__name__)


class ErrorLoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        tb = traceback.format_exc()
        logger.error('500 error on %s %s: %s\n%s', request.method, request.path, exception, tb)
        exc_name = type(exception).__name__
        return HttpResponseServerError(
            f'<!DOCTYPE html><html><head><title>Server Error — FITNESS HUB</title>'
            f'<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">'
            f'<style>body{{background:#0d0d0d;color:#f0ece4;font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;text-align:center;padding:2rem}}'
            f'h1{{font-size:5rem;font-weight:800;color:#d4af37;margin:0 0 0.5rem;line-height:1}}'
            f'span{{color:#888}}'
            f'.err{{background:#1a1a1a;color:#ff6b6b;padding:1rem;border-radius:8px;font-family:monospace;font-size:0.85rem;margin:0 0 1.5rem;word-break:break-all;text-align:left}}'
            f'a{{display:inline-flex;align-items:center;gap:8px;background:#d4af37;color:#0d0d0d;padding:12px 28px;border-radius:50px;font-weight:700;text-decoration:none;margin-top:1rem}}'
            f'</style></head><body><div><h1>500</h1>'
            f'<span>{exc_name}: {exception}</span>'
            f'<pre class="err">{tb}</pre>'
            f'<a href="/">← Back to Home</a></div></body></html>'
        )
