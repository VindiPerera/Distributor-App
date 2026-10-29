<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Product;
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
        $sales = Sale::with('customer', 'user')
            ->when($request->search, fn ($q) => $q->where('invoice_number', 'like', "%{$request->search}%")
                ->orWhereHas('customer', fn ($cq) => $cq->where('name', 'like', "%{$request->search}%")))
            ->when($request->payment_type, fn($q) => $q->where('payment_type', $request->payment_type))
            ->when($request->status, fn($q) => $q->where('status', $request->status))
            ->latest('sale_date')
            ->paginate(20)
            ->withQueryString();

        $pendingCount = Sale::where('status', 'pending')->count();

        return view('sales.index', compact('sales', 'pendingCount'));
    }

    public function create()
    {
        $products = Product::where('is_active', true)->orderBy('name')->get();
        $customers = Customer::where('is_active', true)->orderBy('name')->get();

        return view('sales.create', compact('products', 'customers'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'customer_id' => ['required', 'exists:customers,id'],
            'payment_type' => ['required', 'in:cash,credit,cheque'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.discount_type' => ['nullable', 'in:percent,amount'],
            'items.*.discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'items.*.discount_amount' => ['nullable', 'numeric', 'min:0'],
        ]);

        $data['user_id'] = $request->user()->id;

        $sale = $this->saleService->createSale($data, $data['items']);

        return redirect()->route('sales.show', $sale)->with('status', 'Sale recorded.');
    }

    public function show(Sale $sale)
    {
        $sale->load('items.product', 'customer', 'user', 'payments', 'returns.product');

        return view('sales.show', compact('sale'));
    }

    public function updateStatus(Request $request, Sale $sale)
    {
        $data = $request->validate([
            'status' => ['required', 'in:completed,cancelled'],
        ]);

        try {
            if ($data['status'] === 'completed') {
                $this->saleService->completeSale($sale);
            } else {
                $this->saleService->cancelSale($sale, $request->user()->id);
            }
        } catch (\RuntimeException $e) {
            return back()->withErrors(['status' => $e->getMessage()]);
        }

        return redirect()->route('sales.show', $sale)->with('status', 'Order '.$data['status'].'.');
    }
}
