"""Custom allauth adapters."""

import logging

from allauth.account.adapter import DefaultAccountAdapter
from allauth.socialaccount.adapter import DefaultSocialAccountAdapter
from allauth.exceptions import ImmediateHttpResponse
from django.shortcuts import redirect
from django.contrib import messages
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)



class CustomAccountAdapter(DefaultAccountAdapter):
    def get_login_redirect_url(self, request):
        return '/'

    def get_signup_redirect_url(self, request):
        from django.urls import reverse
        return reverse('verification_setup')



class CustomSocialAccountAdapter(DefaultSocialAccountAdapter):
    def on_authentication_error(self, request, provider, error=None, exception=None, extra_context=None):
        logger.error(
            "Social login failed | provider=%s error=%s exception=%r",
            provider.id if provider else '?', error, exception
        )
        messages.error(request, 'Google login failed. Please try again or use email/password.')
        raise ImmediateHttpResponse(redirect('login'))

    def _log_social_login(self, user, request):
        from store.activity_logger import log_action
        log_action(user, 'social_login', f"Logged in via Google ({user.email})", request=request)

    def pre_social_login(self, request, sociallogin):
        if sociallogin.is_existing:
            self._log_social_login(sociallogin.user, request)
            return

        email = sociallogin.account.extra_data.get('email', '').lower()
        if email:
            User = get_user_model()
            try:
                user = User.objects.get(email=email)
                sociallogin.connect(request, user)
                self._log_social_login(user, request)
            except User.DoesNotExist:
                pass

    def save_user(self, request, sociallogin, form=None):
        user = super().save_user(request, sociallogin, form=form)
        profile = getattr(user, 'profile', None)
        if profile:
            profile.is_email_verified = True
            profile.save()
        self._log_social_login(user, request)
        return user

    def get_signup_redirect_url(self, request, sociallogin):
        return '/'
