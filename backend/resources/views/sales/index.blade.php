<x-app-layout>
    <x-slot name="header">
        <div class="flex justify-between items-center">
            <h2 class="font-display text-xl font-semibold text-ink leading-tight">Sales</h2>
            <a href="{{ route('sales.create') }}" class="px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover">+ New Sale</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-4">

            @if (session('status'))
                <div class="bg-good-soft text-good text-sm px-4 py-2 rounded">{{ session('status') }}</div>
            @endif

            <form method="GET" class="flex gap-2 flex-wrap">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by invoice # or customer..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <select name="payment_type" class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent" onchange="this.form.submit()">
                    <option value="">All types</option>
                    <option value="cash" {{ request('payment_type') === 'cash' ? 'selected' : '' }}>Cash</option>
                    <option value="credit" {{ request('payment_type') === 'credit' ? 'selected' : '' }}>Credit</option>
                </select>
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search') || request('payment_type'))
                    <a href="{{ route('sales.index') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Invoice</th>
                            <th class="px-4 py-3">Date</th>
                            <th class="px-4 py-3">Customer</th>
                            <th class="px-4 py-3">Type</th>
                            <th class="px-4 py-3">Sold By</th>
                            <th class="px-4 py-3 text-right">Returns</th>
                            <th class="px-4 py-3 text-right">Total</th>
                            <th class="px-4 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($sales as $sale)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3"><a href="{{ route('sales.show', $sale) }}" class="text-accent hover:underline">{{ $sale->invoice_number }}</a></td>
                                <td class="px-4 py-3 text-ink-soft">{{ $sale->sale_date->format('Y-m-d H:i') }}</td>
                                <td class="px-4 py-3">{{ $sale->customer->name ?? 'Walk-in' }}</td>
                                <td class="px-4 py-3">
                                    <span class="px-2 py-0.5 rounded text-xs {{ $sale->paymentTypeBadgeClasses() }}">
                                        {{ $sale->paymentTypeLabel() }}
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-ink-soft">{{ $sale->user->name }}</td>
                                <td class="px-4 py-3 text-right {{ $sale->return_amount > 0 ? 'text-critical font-medium' : 'text-ink-soft' }}">
                                    {{ $sale->return_amount > 0 ? '- Rs. ' . number_format($sale->return_amount, 2) : '—' }}
                                </td>
                                <td class="px-4 py-3 text-right font-medium">Rs. {{ number_format($sale->total_amount, 2) }}</td>
                                <td class="px-4 py-3 text-right whitespace-nowrap">
                                    <a href="{{ route('sales.show', $sale) }}" target="_blank" class="text-accent hover:underline text-xs">Preview Bill</a>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="8" class="px-4 py-8 text-center text-ink-soft">No sales found.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $sales->links() }}
        </div>
    </div>
</x-app-layout>
