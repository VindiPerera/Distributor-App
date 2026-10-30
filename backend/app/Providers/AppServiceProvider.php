<?php

namespace App\Providers;

use App\Models\ShopSetting;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        View::composer(['layouts.app', 'sales.show'], function ($view) {
            $view->with('shopName', ShopSetting::current()->name ?: config('app.name'));
        });

        View::composer('sales.show', function ($view) {
            $view->with('shop', ShopSetting::current());
        });
    }
}
