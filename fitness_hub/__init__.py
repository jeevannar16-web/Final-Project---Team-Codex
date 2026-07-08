"""Monkey-patch Django template context __copy__ for Python 3.12+ compatibility.

Python 3.12+ changed super().__copy__() behavior so that BaseContext.__copy__
is called with self being a super() proxy object, not the original instance.
This causes: AttributeError: 'super' object has no attribute 'dicts'
"""

from copy import copy as _copy
from django.template.context import BaseContext, Context, RenderContext


def _base_copy(self):
    if isinstance(self, super):
        orig = self.__self__
        dup = object.__new__(orig.__class__)
        dup.__dict__.update(orig.__dict__)
        dup.dicts = orig.dicts[:]
    else:
        dup = object.__new__(self.__class__)
        dup.__dict__.update(self.__dict__)
        dup.dicts = self.dicts[:]
    return dup


def _context_copy(self):
    dup = _base_copy(self)
    dup.render_context = _copy(self.render_context)
    return dup


def _render_context_copy(self):
    return _base_copy(self)


BaseContext.__copy__ = _base_copy
Context.__copy__ = _context_copy
RenderContext.__copy__ = _render_context_copy
