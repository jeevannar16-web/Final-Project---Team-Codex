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
        uid = str(user.id)
        cart_cache_key = 'cart_count_' + uid
        fav_cache_key = 'fav_ids_' + uid
        cart_count = cache.get(cart_cache_key)
        if cart_count is None:
            cart_count = CartItem.objects.filter(
                user=request.user
            ).aggregate(total=Sum('quantity'))['total'] or 0
            cache.set(cart_cache_key, cart_count, 60)
        favorited_ids = cache.get(fav_cache_key)
        if favorited_ids is None:
            favorited_ids = list(
                FavoriteItem.objects.filter(
                    user=request.user
                ).values_list('product_id', flat=True)
            )
            cache.set(fav_cache_key, favorited_ids, 60)

    return {
        'global_categories': categories,
        'cart_count': cart_count,
        'global_favorited_ids': favorited_ids,
    }
