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
        // The mobile orders screen has no pagination UI, so return everything.
        // Distributors only see the orders they took; admins see all.
        $query = Sale::with('customer', 'user')->latest('sale_date');

        if (!$request->user()->isAdmin()) {
            $query->where('user_id', $request->user()->id);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        // Search by customer name or order id / invoice number.
        if ($term = trim((string) $request->query('search', ''))) {
            $query->where(function ($q) use ($term) {
                $q->where('invoice_number', 'like', "%{$term}%")
                    ->orWhereHas('customer', fn ($c) => $c->where('name', 'like', "%{$term}%"));

                if (ctype_digit($term)) {
                    $q->orWhere('id', (int) $term);
                }
            });
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'customer_id' => ['required', 'exists:customers,id'],
            'payment_type' => ['nullable', 'in:cash,credit,cheque'],
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

        // Orders are taken without settling payment; the back office handles it.
        $data['payment_type'] = $data['payment_type'] ?? 'credit';
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

    public function show(Request $request, Sale $sale)
    {
        $this->authorizeOrder($request, $sale);

        return $sale->load('items.product', 'customer', 'user', 'payments', 'returns.product');
    }

    /**
     * Edit a pending order's items and notes.
     */
    public function update(Request $request, Sale $sale)
    {
        $this->authorizeOrder($request, $sale);

        $data = $request->validate([
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.discount_type' => ['nullable', 'in:percent,amount'],
            'items.*.discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'items.*.discount_amount' => ['nullable', 'numeric', 'min:0'],
        ]);

        try {
            $sale = $this->saleService->updateOrder($sale, $data, $data['items'], $request->user()->id);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($sale);
    }

    /**
     * Cancel an order: restocks its items and reverses any balance it
     * posted. Marking an order completed stays with the back office.
     */
    public function cancel(Request $request, Sale $sale)
    {
        $this->authorizeOrder($request, $sale);

        try {
            $sale = $this->saleService->cancelSale($sale, $request->user()->id);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($sale);
    }

    private function authorizeOrder(Request $request, Sale $sale): void
    {
        $user = $request->user();

        abort_unless($user->isAdmin() || $sale->user_id === $user->id, 403, 'This is not your order.');
    }
}
