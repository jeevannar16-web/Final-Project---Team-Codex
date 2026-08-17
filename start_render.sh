#!/bin/bash
# =============================================================================
# start_render.sh — Render.com start command
# This script runs on EVERY deploy/restart on Render.
# It: migrates DB → loads fixture (first boot only) → restores images → creates
#     superuser/Site/SocialApp → starts daphne
#
# IMPORTANT (perf): heavy one-time steps (fixture load, sequence reset,
# image fix, product reassignment, dedup) run ONLY on first boot where the DB
# has < 10 products. On later deploys/restarts we skip them so Neon compute
# usage stays near zero.
# =============================================================================
set -e

echo "=== START_RENDER.SH STARTED ==="
date
pwd
ls -la fixtures/ 2>&1 || echo "No fixtures dir"

python manage.py migrate --noinput

# --- First-boot check: seed data if DB is empty ---
python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from store.models import Product
count = Product.objects.count()
print(f'Products in DB: {count}')
print('FIRST_BOOT' if count < 10 else 'SEEDED')
" 2>&1 | tee /tmp/boot_check.txt

if grep -q FIRST_BOOT /tmp/boot_check.txt; then
    echo '=== FIRST BOOT — loading fixture & one-time maintenance ==='

    # --- Load seed data ---
    python -c "
import django, os, sys, traceback
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.core.management import call_command
from django.db import IntegrityError, connection
from store.models import NewsletterSubscriber, Product
NewsletterSubscriber.objects.all().delete()
print('Cleared NewsletterSubscriber table')
try:
    from django.conf import settings
    fixture_path = os.path.join(settings.BASE_DIR, 'fixtures/seed_data.json')
    call_command('loaddata', fixture_path, verbosity=0)
except IntegrityError as e:
    print(f'IntegrityError: {e}')
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
" 2>&1 || echo "Fixture load failed (non-fatal)"

    # --- Reset autoincrement sequences ---
    python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.db import connection
cursor = connection.cursor()
if connection.vendor == 'sqlite':
    cursor.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND sql LIKE '%AUTOINCREMENT%'\")
    for row in cursor.fetchall():
        table = row[0]
        cursor.execute(f\"DELETE FROM sqlite_sequence WHERE name='{table}'\")
        cursor.execute(f\"INSERT OR IGNORE INTO sqlite_sequence (name, seq) SELECT '{table}', COALESCE(MAX(id), 0) FROM {table}\")
    print('Reset SQLite autoincrement sequences')
elif connection.vendor == 'postgresql':
    cursor.execute(\"SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND (column_default LIKE 'nextval%%' OR is_identity = 'YES')\")
    for tbl, col in cursor.fetchall():
        cursor.execute(f\"SELECT setval(pg_get_serial_sequence('{tbl}', '{col}'), COALESCE(MAX({col}), 0) + 1, false) FROM {tbl}\")
    print('Reset PostgreSQL sequences')
" 2>&1

    # --- Restore images (first boot only) ---
    python manage.py fix_product_images 2>&1 || echo "Image restoration skipped (non-fatal)"

    # --- Reassign all products to admin and ensure admin is seller ---
    python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.contrib.auth.models import User
from store.models import Product
from users.models import Profile
admin = User.objects.filter(is_superuser=True).order_by('id').first()
if admin:
    updated = Product.objects.exclude(seller=admin).update(seller=admin)
    print(f'Reassigned {updated} products to admin (id={admin.id}, {admin.email})')
    profile, _ = Profile.objects.get_or_create(user=admin)
    if not profile.is_seller:
        profile.is_seller = True
        profile.seller_requested = True
        profile.save()
        print('Admin profile set as seller')
else:
    print('No superuser found for product reassignment')
" 2>&1

    # --- Deduplicate users (first boot only) ---
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
        if hasattr(dup, 'profile'):
            if hasattr(primary, 'profile'):
                dup.profile.delete()
            else:
                dup.profile.user = primary
                dup.profile.save()
        CredentialHistory.objects.filter(user=dup).update(user=primary)
        CartItem.objects.filter(user=dup).update(user=primary)
        Order.objects.filter(user=dup).update(user=primary)
        for fav in FavoriteItem.objects.filter(user=dup):
            if not FavoriteItem.objects.filter(user=primary, product=fav.product).exists():
                fav.user = primary
                fav.save()
            else:
                fav.delete()
        for r in Review.objects.filter(user=dup):
            if not Review.objects.filter(user=primary, product=r.product).exists():
                r.user = primary
                r.save()
            else:
                r.delete()
        if hasattr(dup, 'online_status'):
            dup.online_status.delete()
        Product.objects.filter(seller=dup).update(seller=primary)
        Conversation.objects.filter(customer=dup).update(customer=primary)
        Conversation.objects.filter(seller=dup).update(seller=primary)
        Message.objects.filter(sender=dup).update(sender=primary)
        BlockedUser.objects.filter(blocker=dup).update(blocker=primary)
        BlockedUser.objects.filter(blocked=dup).update(blocked=primary)
        MessageReport.objects.filter(reported_by=dup).update(reported_by=primary)
        EmailVerification.objects.filter(user=dup).update(user=primary)
        dup.delete()
        print(f'  Deleted user id={dup.id} ({dup.username})')
for u in User.objects.filter(profile__isnull=True):
    Profile.objects.create(user=u)
    print(f'  Created missing profile for user id={u.id} ({u.username})')
print('User deduplication complete')
" 2>&1
else
    echo '=== DB already seeded — skipping one-time maintenance ==='
fi

# --- Prune old activity logs (keep last 90 days; runs every boot) ---
python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from datetime import timedelta
from django.utils import timezone
from store.models import ActivityLog
cutoff = timezone.now() - timedelta(days=90)
deleted, _ = ActivityLog.objects.filter(created_at__lt=cutoff).delete()
print(f'Pruned activity logs older than 90 days (count={deleted})')
" 2>&1 || echo "Activity pruner skipped"

# --- Auto-setup (cheap, every boot): ensure superuser, Site, SocialApp exist ---
python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_hub.settings')
django.setup()
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from allauth.socialaccount.models import SocialApp

admin_email = os.environ.get('ADMIN_EMAIL') or os.environ.get('DEFAULT_FROM_EMAIL', 'admin@example.com')
admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
user, created = User.objects.get_or_create(
    username=admin_username,
    defaults={'email': admin_email, 'is_superuser': True, 'is_staff': True, 'password': '!'}
)
if created:
    admin_pass = os.environ.get('ADMIN_PASSWORD')
    if not admin_pass:
        import secrets
        admin_pass = secrets.token_urlsafe(16)
        print(f'ADMIN_PASSWORD not set — generated random password')
    user.set_password(admin_pass)
    user.is_superuser = True
    user.is_staff = True
    user.email = admin_email
    user.save()
    print(f'superuser {admin_username} created')
else:
    # Only refresh password if explicitly overridden during a fresh deploy
    admin_pass = os.environ.get('ADMIN_PASSWORD')
    if admin_pass and os.environ.get('FORCE_ADMIN_PASSWORD', '') == 'true':
        user.set_password(admin_pass)
        user.save()
        print(f'superuser {admin_username} password updated (forced)')
    else:
        print(f'superuser {admin_username} already exists — kept existing password')

domain = os.environ.get('BASE_URL', 'https://ojt-ecommerce-website.onrender.com').replace('https://','').replace('http://','').split('/')[0]
Site.objects.update_or_create(id=1, defaults={'domain': domain, 'name': domain})
print(f'Site domain: {domain}')

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

# ASGI server for WebSocket support
exec daphne -b 0.0.0.0 -p ${PORT:-8000} fitness_hub.asgi:application