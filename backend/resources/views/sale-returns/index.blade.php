<x-app-layout>
    <x-slot name="header">
        <h2 class="font-display text-xl font-semibold text-ink leading-tight">Returns</h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-6xl mx-auto sm:px-6 lg:px-8 space-y-4">

            <p class="text-sm text-ink-soft">Products returned from an earlier purchase and credited against a later bill.</p>

            <form method="GET" class="flex gap-2 flex-wrap">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by invoice # or customer..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <select name="product_id" class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent" onchange="this.form.submit()">
                    <option value="">All products</option>
                    @foreach ($products as $product)
                        <option value="{{ $product->id }}" {{ (string) request('product_id') === (string) $product->id ? 'selected' : '' }}>{{ $product->name }}</option>
                    @endforeach
                </select>
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search') || request('product_id'))
                    <a href="{{ route('sale-returns.index') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Date</th>
                            <th class="px-4 py-3">Product</th>
                            <th class="px-4 py-3">Customer</th>
                            <th class="px-4 py-3 text-right">Qty</th>
                            <th class="px-4 py-3 text-right">Unit Price</th>
                            <th class="px-4 py-3 text-right">Amount</th>
                            <th class="px-4 py-3">Returned From</th>
                            <th class="px-4 py-3">Credited To</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($returns as $return)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 text-ink-soft">{{ $return->created_at->format('Y-m-d H:i') }}</td>
                                <td class="px-4 py-3 font-medium text-ink">{{ $return->product->name }}</td>
                                <td class="px-4 py-3 text-ink-soft">{{ $return->sale->customer->name ?? 'Walk-in' }}</td>
                                <td class="px-4 py-3 text-right">{{ $return->quantity }}</td>
                                <td class="px-4 py-3 text-right text-ink-soft">Rs. {{ number_format($return->unit_price, 2) }}</td>
                                <td class="px-4 py-3 text-right font-medium text-critical">- Rs. {{ number_format($return->amount, 2) }}</td>
                                <td class="px-4 py-3">
                                    <a href="{{ route('sales.show', $return->originalSaleItem->sale) }}" class="text-accent hover:underline">
                                        {{ $return->originalSaleItem->sale->invoice_number }}
                                    </a>
                                </td>
                                <td class="px-4 py-3">
                                    <a href="{{ route('sales.show', $return->sale) }}" class="text-accent hover:underline">
                                        {{ $return->sale->invoice_number }}
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="8" class="px-4 py-8 text-center text-ink-soft">No returns found.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $returns->links() }}
        </div>
    </div>
</x-app-layout>
