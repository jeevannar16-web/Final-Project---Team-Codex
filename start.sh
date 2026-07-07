#!/bin/bash
# start.sh — one-command setup & start
# Usage: ./start.sh          (port 8000)
#        ./start.sh 8080     (custom port)

PORT=${1:-8000}

# Auto-create venv if missing
if [ ! -d venv ]; then
  echo "Creating virtual environment..."
  python3 -m venv venv
fi

source venv/bin/activate 2>/dev/null || . venv/bin/activate

# Auto-install if missing
if [ ! -f venv/installed ]; then
  echo "Installing dependencies..."
  pip install -r requirements.txt --quiet
  touch venv/installed
fi

# Kill stale process on the same port
if command -v lsof &>/dev/null; then
  PID=$(lsof -ti:$PORT)
  [ -n "$PID" ] && kill -9 $PID 2>/dev/null
fi

echo ""
echo "  Applying migrations..."
python manage.py migrate 2>&1 | tail -3

# Build static files manifest if missing
if [ ! -f staticfiles/staticfiles.json ]; then
  echo "  Building static files..."
  python manage.py collectstatic --no-input --quiet 2>&1 | tail -1
fi

# Load seed data if database is empty (no products)
PRODUCT_COUNT=$(python manage.py shell -c "from store.models import Product; print(Product.objects.count())" 2>&1)
if [ "$PRODUCT_COUNT" = "0" ] || [ -z "$PRODUCT_COUNT" ]; then
  echo "  Loading seed data (446 products, 77 users, 149 orders)..."
  python manage.py loaddata fixtures/seed_data.json 2>&1
fi

echo ""
echo "  Starting server..."
echo ""

python manage.py runserver 127.0.0.1:$PORT &
sleep 2

echo ""
echo "  ✅ Server is ready!"
echo ""
echo "  Open http://127.0.0.1:$PORT or http://localhost:$PORT in your browser"
echo ""
echo "  To stop: ./stop.sh"
echo ""

wait
