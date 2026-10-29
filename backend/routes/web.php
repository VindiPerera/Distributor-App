<?php

use App\Http\Controllers\ProfileController;
use App\Http\Controllers\Web\CategoryController;
use App\Http\Controllers\Web\CustomerCategoryController;
use App\Http\Controllers\Web\CustomerController;
use App\Http\Controllers\Web\DashboardController;
use App\Http\Controllers\Web\ProductController;
use App\Http\Controllers\Web\ReportController;
use App\Http\Controllers\Web\ReportDashboardController;
use App\Http\Controllers\Web\SaleController;
use App\Http\Controllers\Web\SaleReturnController;
use App\Http\Controllers\Web\ShopSettingController;
use App\Http\Controllers\Web\StockAdjustmentController;
use App\Http\Controllers\Web\StockTransactionController;
use App\Http\Controllers\Web\SupplierController;
use App\Http\Controllers\Web\UserController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('dashboard');
});

Route::middleware('auth')->group(function () {
    Route::get('/dashboard', DashboardController::class)->name('dashboard');

    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    Route::resource('sales', SaleController::class)->only(['index', 'create', 'store', 'show']);
    Route::patch('sales/{sale}/status', [SaleController::class, 'updateStatus'])->name('sales.update-status');
    Route::get('returns', [SaleReturnController::class, 'index'])->name('sale-returns.index');

    Route::resource('customers', CustomerController::class);
    Route::post('customers/{customer}/payments', [CustomerController::class, 'storePayment'])->name('customers.payments.store');
    Route::resource('customer-categories', CustomerCategoryController::class)->except(['show']);

    Route::resource('products', ProductController::class)->except(['show']);
    Route::post('products/{product}/restore', [ProductController::class, 'restore'])->name('products.restore');

    Route::resource('stock-adjustments', StockAdjustmentController::class)->only(['index', 'create', 'store']);
    Route::get('stock-transactions', [StockTransactionController::class, 'index'])->name('stock-transactions.index');

    Route::resource('categories', CategoryController::class)->except(['show']);
    Route::resource('suppliers', SupplierController::class)->except(['show']);

    Route::prefix('reports')->name('reports.')->group(function () {
        Route::get('/receivables', [ReportController::class, 'receivables'])->name('receivables');
        Route::get('/low-stock', [ReportController::class, 'lowStock'])->name('low-stock');

        Route::middleware('admin')->group(function () {
            Route::get('/dashboard', [ReportDashboardController::class, 'index'])->name('dashboard');
            Route::get('/dashboard/export-pdf', [ReportDashboardController::class, 'exportPdf'])->name('dashboard.export-pdf');
            Route::get('/dashboard/export-excel', [ReportDashboardController::class, 'exportExcel'])->name('dashboard.export-excel');
        });
    });

    Route::middleware('admin')->group(function () {
        Route::resource('users', UserController::class)->only(['index', 'create', 'store', 'destroy']);

        Route::get('shop-settings', [ShopSettingController::class, 'edit'])->name('shop-settings.edit');
        Route::put('shop-settings', [ShopSettingController::class, 'update'])->name('shop-settings.update');
    });
});

require __DIR__.'/auth.php';
