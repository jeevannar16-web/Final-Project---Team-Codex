"""Language middleware (English-only)."""

from django.conf import settings


def get_current_language():
    return 'en'


class LanguageMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.LANGUAGE_CODE = 'en'
        request.session['django_language'] = 'en'
        response = self.get_response(request)
        response.set_cookie('django_language', 'en', max_age=31536000)
        return response
