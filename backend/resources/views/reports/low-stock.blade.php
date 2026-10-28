<x-app-layout>
    <x-slot name="header">
        <h2 class="font-display text-xl font-semibold text-ink leading-tight">Low Stock Report</h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-5xl mx-auto sm:px-6 lg:px-8 space-y-4">
            <form method="GET" class="flex gap-2">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by product or SKU..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search'))
                    <a href="{{ route('reports.low-stock') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">SKU</th>
                            <th class="px-4 py-3">Product</th>
                            <th class="px-4 py-3 text-right">Stock</th>
                            <th class="px-4 py-3 text-right">Low Stock Alert</th>
                            <th class="px-4 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($products as $product)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 text-ink-soft">{{ $product->sku }}</td>
                                <td class="px-4 py-3 font-medium text-ink">{{ $product->name }}</td>
                                <td class="px-4 py-3 text-right text-critical font-semibold">{{ $product->stock_quantity }} {{ $product->unit }}</td>
                                <td class="px-4 py-3 text-right text-ink-soft">{{ $product->low_stock_alert }}</td>
                                <td class="px-4 py-3 text-right">
                                    <a href="{{ route('products.edit', $product) }}" class="text-accent hover:underline">Restock</a>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="5" class="px-4 py-8 text-center text-ink-soft">All stock levels are healthy.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
