<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\InvalidReturnException;
use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Services\SaleService;
use Illuminate\Http\Request;

class SaleController extends Controller
{
    public function __construct(private SaleService $saleService)
    {
    }

    public function index(Request $request)
    {
        // Same fix as the products/customers endpoints: the mobile sales
        // history screen has no pagination UI, so paginate(20) was silently
        // hiding every sale past the most recent 20 from it.
        return response()->json([
            'data' => Sale::with('customer', 'user')->latest('sale_date')->get(),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'customer_id' => ['required', 'exists:customers,id'],
            'payment_type' => ['required', 'in:cash,credit,cheque'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'paid_amount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.discount_type' => ['nullable', 'in:percent,amount'],
            'items.*.discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'items.*.discount_amount' => ['nullable', 'numeric', 'min:0'],
            'returns' => ['nullable', 'array'],
            'returns.*.sale_item_id' => ['required_with:returns', 'exists:sale_items,id'],
            'returns.*.quantity' => ['required_with:returns', 'integer', 'min:1'],
        ]);

        $data['user_id'] = $request->user()->id;
        // Orders placed through the mobile app always land as pending —
        // the back office confirms or cancels them from the admin panel.
        $data['status'] = 'pending';

        try {
            $sale = $this->saleService->createSale($data, $data['items']);
        } catch (InvalidReturnException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($sale, 201);
    }

    public function show(Sale $sale)
    {
        return $sale->load('items.product', 'customer', 'user', 'payments', 'returns.product');
    }
}
