<x-app-layout>
    <x-slot name="header">
        <div class="flex justify-between items-center">
            <h2 class="font-display text-xl font-semibold text-ink leading-tight">Stock Adjustments</h2>
            <a href="{{ route('stock-adjustments.create') }}" class="px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover">+ Stock Adjustment</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-6xl mx-auto sm:px-6 lg:px-8 space-y-4">

            @if (session('status'))
                <div class="bg-good-soft text-good text-sm px-4 py-2 rounded">{{ session('status') }}</div>
            @endif

            <form method="GET" class="flex gap-2 flex-wrap">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by product or reason..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <select name="product_id" class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent" onchange="this.form.submit()">
                    <option value="">All products</option>
                    @foreach ($products as $product)
                        <option value="{{ $product->id }}" {{ (string) request('product_id') === (string) $product->id ? 'selected' : '' }}>{{ $product->name }}</option>
                    @endforeach
                </select>
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search') || request('product_id'))
                    <a href="{{ route('stock-adjustments.index') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Date</th>
                            <th class="px-4 py-3">Product</th>
                            <th class="px-4 py-3">Direction</th>
                            <th class="px-4 py-3 text-right">Quantity</th>
                            <th class="px-4 py-3 text-right">Stock After</th>
                            <th class="px-4 py-3">Reason</th>
                            <th class="px-4 py-3">By</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($movements as $movement)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 text-ink-soft">{{ $movement->created_at->format('Y-m-d H:i') }}</td>
                                <td class="px-4 py-3 font-medium text-ink">{{ $movement->product->name }}</td>
                                <td class="px-4 py-3">
                                    @if ($movement->quantity >= 0)
                                        <span class="px-2 py-0.5 rounded text-xs bg-good-soft text-good">Stock In</span>
                                    @else
                                        <span class="px-2 py-0.5 rounded text-xs bg-critical-soft text-critical">Stock Out</span>
                                    @endif
                                </td>
                                <td class="px-4 py-3 text-right font-medium {{ $movement->quantity >= 0 ? 'text-good' : 'text-critical' }}">
                                    {{ $movement->quantity >= 0 ? '+' : '' }}{{ $movement->quantity }}
                                </td>
                                <td class="px-4 py-3 text-right text-ink-soft">{{ $movement->quantity_after }}</td>
                                <td class="px-4 py-3 text-ink-soft">{{ $movement->notes ?? '—' }}</td>
                                <td class="px-4 py-3 text-ink-soft">{{ $movement->user->name }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="7" class="px-4 py-8 text-center text-ink-soft">No stock adjustments yet.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $movements->links() }}
        </div>
    </div>
</x-app-layout>
