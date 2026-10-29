<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CustomerCategoryController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\SaleController;
use App\Http\Controllers\Api\ShopSettingController;
use Illuminate\Support\Facades\Route;

// All API route names are prefixed with 'api.' so they never collide with
// the admin portal's web route names (e.g. web 'sales.show' vs this file's
// sale show route) — Laravel's route() name lookup is global, not
// scoped by URI prefix.
Route::name('api.')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);

        Route::apiResource('customers', CustomerController::class);
        Route::get('customers/{customer}/ledger', [CustomerController::class, 'ledger']);
        Route::get('customers/{customer}/aging', [CustomerController::class, 'aging']);
        Route::get('customers/{customer}/returnable-items', [CustomerController::class, 'returnableItems']);

        Route::get('customer-categories', [CustomerCategoryController::class, 'index']);

        Route::get('categories', [CategoryController::class, 'index']);

        Route::apiResource('products', ProductController::class);

        Route::apiResource('sales', SaleController::class)->only(['index', 'store', 'show']);

        Route::apiResource('payments', PaymentController::class)->only(['index', 'store']);

        Route::get('shop-settings', [ShopSettingController::class, 'show']);
    });
});
