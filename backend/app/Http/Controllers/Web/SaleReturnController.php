<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\SaleReturn;
use Illuminate\Http\Request;

class SaleReturnController extends Controller
{
    public function index(Request $request)
    {
        $returns = SaleReturn::with(['product', 'sale.customer', 'originalSaleItem.sale'])
            ->when($request->product_id, fn ($q) => $q->where('product_id', $request->product_id))
            ->when($request->search, function ($q) use ($request) {
                $q->where(function ($sq) use ($request) {
                    $sq->whereHas('sale', fn ($saleQ) => $saleQ->where('invoice_number', 'like', "%{$request->search}%"))
                        ->orWhereHas('sale.customer', fn ($custQ) => $custQ->where('name', 'like', "%{$request->search}%"));
                });
            })
            ->latest()
            ->paginate(25)
            ->withQueryString();

        $products = Product::orderBy('name')->get();

        return view('sale-returns.index', compact('returns', 'products'));
    }
}
