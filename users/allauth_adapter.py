"""Custom allauth adapters."""

import logging
import traceback

from allauth.account.adapter import DefaultAccountAdapter
from allauth.socialaccount.adapter import DefaultSocialAccountAdapter
from allauth.socialaccount.models import SocialAccount, SocialLogin
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
            "Social login failed | provider=%s error=%s exception=%r\n%s",
            provider.id if provider else '?', error, exception,
            traceback.format_exc()
        )
        # Silent redirect — user can retry
        raise ImmediateHttpResponse(redirect('login'))

    def _log_social_login(self, user, request):
        from store.activity_logger import log_action
        log_action(user, 'social_login', f"Logged in via Google ({user.email})", request=request)

    def pre_social_login(self, request, sociallogin):
        try:
            if sociallogin.is_existing:
                self._log_social_login(sociallogin.user, request)
                return

            email = sociallogin.account.extra_data.get('email', '').lower()
            if not email:
                return

            User = get_user_model()
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                return

            sa, created = SocialAccount.objects.get_or_create(
                provider=sociallogin.account.provider,
                uid=sociallogin.account.uid,
                defaults={'user': user, 'extra_data': sociallogin.account.extra_data}
            )
            if not created and sa.user_id != user.id:
                sa.user = user
                sa.save()
            sociallogin.user = user
            sociallogin.account = sa
            sociallogin.state['process'] = 'login'
            self._log_social_login(user, request)
        except Exception as e:
            logger.error('pre_social_login error: %s\n%s', e, traceback.format_exc())

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
