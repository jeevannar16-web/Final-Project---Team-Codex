"""Localization context processors (English-only)."""

from django.conf import settings


def localization_context(request):
    return {
        'LANGUAGE_CODE': 'en',
        'available_languages': [],
        't': str,
        'currency_code': 'USD',
        'currency_symbol': '$',
    }
