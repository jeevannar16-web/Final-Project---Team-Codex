"""Email verification middleware."""

from django.conf import settings
from django.shortcuts import redirect


class EmailVerificationMiddleware:
    ALLOWED_PREFIXES = [
        '/accounts/',
        '/verify/',
        '/users/login/',
        '/users/register/',
        '/users/logout/',
        '/users/password-reset/',
        '/admin/',
        '/static/',
        '/media/',
        '/__reload__/',
    ]

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if not getattr(settings, 'EMAIL_VERIFICATION_REQUIRED', True):
            return self.get_response(request)

        path = request.path_info

        if any(path.startswith(p) for p in self.ALLOWED_PREFIXES):
            return self.get_response(request)

        if request.user.is_authenticated:
            from django.core.cache import cache
            uid = str(request.user.id)
            key = 'email_ver_' + uid
            verified = cache.get(key)
            if verified is None:
                profile = getattr(request.user, 'profile', None)
                verified = not profile or profile.is_email_verified
                cache.set(key, verified, 60)
            if not verified:
                return redirect('verification_setup')

        return self.get_response(request)
