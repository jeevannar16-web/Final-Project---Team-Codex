"""Monkey-patch Django Context.__copy__ for Python 3.14 compatibility.

Python 3.14 changed super().__copy__() behavior, causing:
  AttributeError: 'super' object has no attribute 'dicts'
in django/template/context.py line 39.
"""

from django.template.context import BaseContext


def _patched_context_copy(self):
    duplicate = object.__new__(self.__class__)
    duplicate.__dict__.update(self.__dict__)
    duplicate.dicts = self.dicts[:]
    return duplicate


BaseContext.__copy__ = _patched_context_copy
