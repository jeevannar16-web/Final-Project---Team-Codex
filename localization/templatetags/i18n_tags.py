"""Internationalization template tags (English-only)."""

from django import template
from django.conf import settings

register = template.Library()


@register.filter
def t(key):
    return str(key) if not isinstance(key, str) else key


@register.simple_tag(takes_context=True)
def trans(context, key, default=None, **params):
    return str(key) if not isinstance(key, str) else key


@register.simple_tag(takes_context=True)
def translate(context, key, default=None, **params):
    return str(key) if not isinstance(key, str) else key


@register.filter
def translate_str(text, lang_code='en'):
    return str(text) if not isinstance(text, str) else text


@register.filter
def ttrans(key, lang_code):
    return str(key) if not isinstance(key, str) else key


@register.filter
def currency(value, arg=None):
    try:
        return f'${float(value):,.2f}'
    except (TypeError, ValueError):
        return '$0.00'
