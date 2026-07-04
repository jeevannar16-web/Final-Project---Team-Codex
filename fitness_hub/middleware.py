"""Middleware to log all 500 errors with full traceback."""

import logging
import traceback

logger = logging.getLogger(__name__)


class ErrorLoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        logger.error(
            '500 error on %s %s: %s\n%s',
            request.method, request.path, exception, traceback.format_exc()
        )
