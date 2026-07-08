#!/bin/bash
# =============================================================================
# start_render.sh — Render.com start command
# This script runs on EVERY deploy/restart on Render.
# It: migrates DB → loads fixture (if empty) → restores images → creates
#     superuser/Site/SocialApp → starts gunicorn
# =============================================================================
set -e

echo "=== START_RENDER.SH STARTED ==="
date
pwd
ls -la fixtures/ 2>&1 || echo "No fixtures dir"

python manage.py migrate --noinput

# --- Load seed data if DB is empty ---
python -c "
import django, os, sys, traceback
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from store.models import Product
count = Product.objects.count()
print(f'Products in DB before load: {count}')
if count < 10:
    from django.core.management import call_command
    from django.db import IntegrityError, connection
    # Clear conflicting data before loading fixture
    from store.models import NewsletterSubscriber
    NewsletterSubscriber.objects.all().delete()
    print('Cleared NewsletterSubscriber table')
    try:
        from django.conf import settings
        fixture_path = os.path.join(settings.BASE_DIR, 'fixtures/seed_data.json')
        call_command('loaddata', fixture_path, verbosity=0)
    except IntegrityError as e:
        print(f'IntegrityError: {e}')
        # Try without transaction wrapping
        connection.set_autocommit(True)
        try:
            call_command('loaddata', fixture_path, verbosity=0)
        except Exception as e2:
            print(f'Second attempt also failed: {e2}')
    except Exception as e:
        print(f'ERROR loading fixture: {e}')
        traceback.print_exc()
    count = Product.objects.count()
    print(f'Products in DB after load: {count}')
else:
    print('Skipping fixture load — products already exist')
" 2>&1

# --- Restore images from fixture ---
python manage.py fix_product_images 2>&1 || echo "Image restoration skipped (non-fatal)"

# --- Deduplicate users (keep superuser/staff, delete rest) ---
python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.contrib.auth.models import User
from django.db.models import Count
from store.models import Product, CartItem, Order, FavoriteItem, Review, ActivityLog, UserOnline, Conversation, Message, BlockedUser, MessageReport
from users.models import Profile, CredentialHistory
from verification.models import EmailVerification

dupes = User.objects.values('email').annotate(count=Count('id')).filter(count__gt=1, email__gt='')
for entry in dupes:
    email = entry['email']
    users = User.objects.filter(email__iexact=email).order_by('-is_superuser', '-is_staff', 'date_joined')
    primary = users.first()
    for dup in users[1:]:
        print(f'  Merging user id={dup.id} ({dup.username}) into id={primary.id} ({primary.username})')
        # Reassign or remove related objects to avoid FK violations
        # Profile (OneToOne)
        if hasattr(dup, 'profile'):
            if hasattr(primary, 'profile'):
                dup.profile.delete()
            else:
                dup.profile.user = primary
                dup.profile.save()
        # CredentialHistory
        CredentialHistory.objects.filter(user=dup).update(user=primary)
        # CartItem
        CartItem.objects.filter(user=dup).update(user=primary)
        # Order
        Order.objects.filter(user=dup).update(user=primary)
        # FavoriteItem - skip duplicates
        for fav in FavoriteItem.objects.filter(user=dup):
            if not FavoriteItem.objects.filter(user=primary, product=fav.product).exists():
                fav.user = primary
                fav.save()
            else:
                fav.delete()
        # Review - skip duplicates
        for r in Review.objects.filter(user=dup):
            if not Review.objects.filter(user=primary, product=r.product).exists():
                r.user = primary
                r.save()
            else:
                r.delete()
        # ActivityLog (SET_NULL) - just leave null
        # UserOnline (OneToOne)
        if hasattr(dup, 'online_status'):
            dup.online_status.delete()
        # Product.seller (nullable) - reassign
        Product.objects.filter(seller=dup).update(seller=primary)
        # Conversation
        Conversation.objects.filter(customer=dup).update(customer=primary)
        Conversation.objects.filter(seller=dup).update(seller=primary)
        # Message
        Message.objects.filter(sender=dup).update(sender=primary)
        # BlockedUser
        BlockedUser.objects.filter(blocker=dup).update(blocker=primary)
        BlockedUser.objects.filter(blocked=dup).update(blocked=primary)
        # MessageReport
        MessageReport.objects.filter(reported_by=dup).update(reported_by=primary)
        # EmailVerification
        EmailVerification.objects.filter(user=dup).update(user=primary)
        dup.delete()
        print(f'  Deleted user id={dup.id} ({dup.username})')
# Ensure every remaining user has a Profile
for u in User.objects.filter(profile__isnull=True):
    Profile.objects.create(user=u)
    print(f'  Created missing profile for user id={u.id} ({u.username})')
print('User deduplication complete')
" 2>&1

# Auto-setup script (ensures superuser, Site, and SocialApp exist)
python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from allauth.socialaccount.models import SocialApp

# --- List admin accounts ---
staff = User.objects.filter(is_staff=True)
if staff.exists():
    print('Staff/superuser accounts in DB:')
    for u in staff:
        print(f'  - {u.username} (email: {u.email}, superuser: {u.is_superuser}, staff: {u.is_staff})')
else:
    print('No staff accounts found')

# --- Ensure superuser exists (password from env, random fallback) ---
admin_email = os.environ.get('ADMIN_EMAIL') or os.environ.get('DEFAULT_FROM_EMAIL', 'admin@example.com')
# Create 'admin' user (or use ADMIN_USERNAME env var)
admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
user, created = User.objects.get_or_create(
    username=admin_username,
    defaults={'email': admin_email, 'is_superuser': True, 'is_staff': True}
)
admin_pass = os.environ.get('ADMIN_PASSWORD')
if not admin_pass:
    import secrets
    admin_pass = secrets.token_urlsafe(16)
    print(f'ADMIN_PASSWORD not set — generated random password: {admin_pass}')
user.set_password(admin_pass)
user.is_superuser = True
user.is_staff = True
user.email = admin_email
user.save()
status = 'created' if created else 'updated'
print(f'superuser {admin_username} {status}')

# --- Site domain ---
domain = os.environ.get('BASE_URL', 'https://ojt-ecommerce-website.onrender.com').replace('https://','').replace('http://','').split('/')[0]
Site.objects.update_or_create(id=1, defaults={'domain': domain, 'name': domain})
print(f'Site domain: {domain}')

# --- Google OAuth ---
client_id = os.environ.get('GOOGLE_CLIENT_ID')
client_secret = os.environ.get('GOOGLE_CLIENT_SECRET')
if client_id and client_secret:
    app, _ = SocialApp.objects.get_or_create(
        provider='google',
        defaults={'name': 'Google', 'client_id': client_id, 'secret': client_secret}
    )
    if not _:
        app.client_id = client_id
        app.secret = client_secret
        app.save()
    site = Site.objects.get(id=1)
    app.sites.add(site)
    print('Google OAuth configured')
else:
    SocialApp.objects.get_or_create(
        provider='google',
        defaults={'name': 'Google', 'client_id': 'placeholder', 'secret': 'placeholder'}
    )
    print('Google OAuth placeholder created (set GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET env vars)')
" 2>&1

# Reduce workers for free tier (Render caps at 1 CPU)
exec gunicorn fitness_hub.wsgi:application \
  --workers=2 --threads=2 --worker-class=gthread \
  --timeout 120 --keep-alive 60
