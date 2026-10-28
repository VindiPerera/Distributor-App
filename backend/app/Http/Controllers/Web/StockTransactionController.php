<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Http\Request;

class StockTransactionController extends Controller
{
    public function index(Request $request)
    {
        $movements = StockMovement::with('product', 'user', 'reference')
            ->when($request->search, fn ($q) => $q->where(fn ($sq) => $sq
                ->whereHas('product', fn ($pq) => $pq->where('name', 'like', "%{$request->search}%"))
                ->orWhere('notes', 'like', "%{$request->search}%")))
            ->when($request->product_id, fn ($q) => $q->where('product_id', $request->product_id))
            ->when($request->type, fn ($q) => $q->where('type', $request->type))
            ->latest()
            ->paginate(25)
            ->withQueryString();

        $products = Product::orderBy('name')->get();

        return view('stock-transactions.index', compact('movements', 'products'));
    }
}
