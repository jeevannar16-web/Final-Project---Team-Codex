"""Custom multi-backend email system with HTTP API fallback."""

import logging
import requests
from django.conf import settings
from django.core.mail.backends.smtp import EmailBackend as SMTPBackend
from django.core.mail.message import sanitize_address

logger = logging.getLogger(__name__)


class ResilientEmailBackend(SMTPBackend):
    """Tries SMTP first, falls back to SendGrid Web API, then console."""

    def send_messages(self, email_messages):
        sent = 0
        for message in email_messages:
            try:
                super().send_messages([message])
                sent += 1
            except Exception as smtp_err:
                logger.warning('SMTP failed for %s: %s — trying API fallback',
                               message.subject, smtp_err)
                if self._try_api_fallback(message):
                    sent += 1
                else:
                    self._log_to_console(message)
        return sent

    def _try_api_fallback(self, message):
        sendgrid_key = getattr(settings, 'SENDGRID_API_KEY', '')
        if not sendgrid_key:
            return False
        try:
            to_addrs = [sanitize_address(a, 'utf-8') for a in message.to]
            payload = {
                'personalizations': [{'to': [{'email': a} for a in to_addrs]}],
                'from': {'email': message.from_email},
                'subject': message.subject,
                'content': [
                    {'type': 'text/plain', 'value': message.body},
                ],
            }
            if getattr(message, 'alternatives', None):
                for alt_content, alt_mimetype in message.alternatives:
                    if alt_mimetype == 'text/html':
                        payload['content'].append(
                            {'type': 'text/html', 'value': alt_content}
                        )
            resp = requests.post(
                'https://api.sendgrid.com/v3/mail/send',
                json=payload,
                headers={
                    'Authorization': f'Bearer {sendgrid_key}',
                    'Content-Type': 'application/json',
                },
                timeout=15,
            )
            if resp.ok:
                logger.info('Email sent via SendGrid API | to=%s subject=%s',
                            message.to, message.subject)
                return True
            logger.error('SendGrid API error %s: %s', resp.status_code, resp.text)
            return False
        except Exception as e:
            logger.error('SendGrid API fallback failed: %s', e)
            return False

    def _log_to_console(self, message):
        logger.info('[CONSOLE] Email to=%s subject=%s body=%s',
                    message.to, message.subject, message.body[:200])
