<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerLedgerEntry;
use App\Models\Payment;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReportController extends Controller
{
    public function receivables(Request $request)
    {
        // Defaults to today when no date is picked, so "collected" always
        // means "collected on the selected day" even before the admin
        // touches the filter.
        $collectedDate = $request->filled('collected_date')
            ? Carbon::parse($request->collected_date)->startOfDay()
            : now()->startOfDay();

        // Sum of payments made on the selected day, per customer.
        $collectedToday = Payment::whereBetween('paid_at', [$collectedDate, $collectedDate->copy()->endOfDay()])
            ->selectRaw('customer_id, SUM(amount) as total')
            ->groupBy('customer_id')
            ->pluck('total', 'customer_id');

        $totalCollected = $collectedToday->sum();

        // Still-owing customers, plus anyone who paid on the selected day
        // even if that payment cleared their balance to zero — otherwise a
        // customer who fully settled up today would vanish from "today's
        // collections" instead of showing what they paid.
        $customers = Customer::where(function ($q) use ($collectedToday) {
                $q->where('current_balance', '>', 0);
                if ($collectedToday->isNotEmpty()) {
                    $q->orWhereIn('id', $collectedToday->keys());
                }
            })
            ->when($request->search, fn ($q) => $q->where('name', 'like', "%{$request->search}%"))
            ->orderByDesc('current_balance')
            ->get();

        $buckets = ['0_30' => 0.0, '31_60' => 0.0, '61_90' => 0.0, 'over_90' => 0.0];

        CustomerLedgerEntry::where('type', 'sale')
            ->with('customer')
            ->get()
            ->each(function (CustomerLedgerEntry $entry) use (&$buckets) {
                if (! $entry->customer || $entry->customer->current_balance <= 0) {
                    return;
                }
                $days = $entry->created_at->diffInDays(now());
                $bucket = match (true) {
                    $days <= 30 => '0_30',
                    $days <= 60 => '31_60',
                    $days <= 90 => '61_90',
                    default => 'over_90',
                };
                $buckets[$bucket] += (float) $entry->amount;
            });

        return view('reports.receivables', compact('customers', 'buckets', 'collectedToday', 'totalCollected', 'collectedDate'));
    }

    public function lowStock(Request $request)
    {
        $products = Product::whereColumn('stock_quantity', '<=', 'low_stock_alert')
            ->where('is_active', true)
            ->when($request->search, fn ($q) => $q->where(fn ($sq) => $sq
                ->where('name', 'like', "%{$request->search}%")
                ->orWhere('sku', 'like', "%{$request->search}%")))
            ->orderBy('stock_quantity')
            ->get();

        return view('reports.low-stock', compact('products'));
    }
}
