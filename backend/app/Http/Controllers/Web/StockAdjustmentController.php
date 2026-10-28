<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Http\Request;

class StockAdjustmentController extends Controller
{
    public function index(Request $request)
    {
        $movements = StockMovement::with('product', 'user')
            ->where('type', 'adjustment')
            ->when($request->search, fn ($q) => $q->where(fn ($sq) => $sq
                ->whereHas('product', fn ($pq) => $pq->where('name', 'like', "%{$request->search}%"))
                ->orWhere('notes', 'like', "%{$request->search}%")))
            ->when($request->product_id, fn ($q) => $q->where('product_id', $request->product_id))
            ->latest()
            ->paginate(20)
            ->withQueryString();

        $products = Product::where('is_active', true)->orderBy('name')->get();

        return view('stock-adjustments.index', compact('movements', 'products'));
    }

    public function create(Request $request)
    {
        $products = Product::where('is_active', true)->orderBy('name')->get();
        $selectedProduct = $request->product_id ? Product::find($request->product_id) : null;

        return view('stock-adjustments.create', compact('products', 'selectedProduct'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'product_id' => ['required', 'exists:products,id'],
            'direction' => ['required', 'in:in,out'],
            'quantity' => ['required', 'integer', 'min:1'],
            'notes' => ['nullable', 'string'],
        ]);

        $product = Product::findOrFail($data['product_id']);
        $signedQuantity = $data['direction'] === 'in' ? $data['quantity'] : -$data['quantity'];
        $newQty = $product->stock_quantity + $signedQuantity;

        if ($newQty < 0) {
            return back()->withInput()->withErrors(['quantity' => 'Stock out quantity exceeds current stock.']);
        }

        $product->stockMovements()->create([
            'type' => 'adjustment',
            'quantity' => $signedQuantity,
            'quantity_after' => $newQty,
            'notes' => $data['notes'] ?? null,
            'user_id' => $request->user()->id,
        ]);

        $product->update(['stock_quantity' => $newQty]);

        return redirect()->route('stock-adjustments.index')->with('status', 'Stock '.($data['direction'] === 'in' ? 'in' : 'out').' recorded for '.$product->name.'.');
    }
}
