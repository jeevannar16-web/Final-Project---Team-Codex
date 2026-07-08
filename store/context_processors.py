"""Template context processors."""

from .models import Product, Category, FavoriteItem, CartItem
from django.db.models import Sum
from django.core.cache import cache



def global_context(request):
    categories = cache.get('global_categories')
    if categories is None:
        categories = list(Category.objects.all())
        cache.set('global_categories', categories, 3600)
    cart_count = 0
    favorited_ids = []

    user = getattr(request, 'user', None)
    if user and user.is_authenticated:
        cart_count = CartItem.objects.filter(
            user=request.user
        ).aggregate(total=Sum('quantity'))['total'] or 0
        favorited_ids = list(
            FavoriteItem.objects.filter(
                user=request.user
            ).values_list('product_id', flat=True)
        )

    return {
        'global_categories': categories,
        'cart_count': cart_count,
        'global_favorited_ids': favorited_ids,
    }
