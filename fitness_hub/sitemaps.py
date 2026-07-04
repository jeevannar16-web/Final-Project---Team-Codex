from django.contrib import sitemaps
from django.urls import reverse

from store.models import Product, Category


class StaticViewSitemap(sitemaps.Sitemap):
    priority = 0.5
    changefreq = 'weekly'

    def items(self):
        return ['home', 'login', 'register', 'store:product_list']

    def location(self, item):
        return reverse(item)


class ProductSitemap(sitemaps.Sitemap):
    changefreq = 'daily'
    priority = 0.8

    def items(self):
        return Product.objects.all().only('id', 'updated_at')

    def lastmod(self, obj):
        return obj.updated_at

    def location(self, obj):
        return reverse('store:product_detail', args=[obj.id])


class CategorySitemap(sitemaps.Sitemap):
    changefreq = 'weekly'
    priority = 0.6

    def items(self):
        return Category.objects.all().only('id')

    def location(self, obj):
        return reverse('store:product_list') + f'?category={obj.id}'
