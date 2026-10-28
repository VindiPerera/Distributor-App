<x-app-layout>
    <x-slot name="header">
        <h2 class="font-display text-xl font-semibold text-ink leading-tight">Stock Transactions</h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-6xl mx-auto sm:px-6 lg:px-8 space-y-4">

            @php
                $typeLabels = [
                    'purchase_in' => 'Purchase In',
                    'sale_out' => 'Sale Out',
                    'adjustment' => 'Adjustment',
                    'return_in' => 'Return In',
                ];
                $typeBadgeClasses = [
                    'purchase_in' => 'bg-good-soft text-good',
                    'sale_out' => 'bg-warn-soft text-warn',
                    'adjustment' => 'bg-accent-soft text-accent',
                    'return_in' => 'bg-good-soft text-good',
                ];
            @endphp

            <form method="GET" class="flex gap-2 flex-wrap">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by product or reason..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <select name="product_id" class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent" onchange="this.form.submit()">
                    <option value="">All products</option>
                    @foreach ($products as $product)
                        <option value="{{ $product->id }}" {{ (string) request('product_id') === (string) $product->id ? 'selected' : '' }}>{{ $product->name }}</option>
                    @endforeach
                </select>
                <select name="type" class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent" onchange="this.form.submit()">
                    <option value="">All types</option>
                    @foreach ($typeLabels as $value => $label)
                        <option value="{{ $value }}" {{ request('type') === $value ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search') || request('product_id') || request('type'))
                    <a href="{{ route('stock-transactions.index') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Date</th>
                            <th class="px-4 py-3">Product</th>
                            <th class="px-4 py-3">Type</th>
                            <th class="px-4 py-3 text-right">Quantity</th>
                            <th class="px-4 py-3 text-right">Stock After</th>
                            <th class="px-4 py-3">Reference / Reason</th>
                            <th class="px-4 py-3">By</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($movements as $movement)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 text-ink-soft">{{ $movement->created_at->format('Y-m-d H:i') }}</td>
                                <td class="px-4 py-3 font-medium text-ink">{{ $movement->product->name }}</td>
                                <td class="px-4 py-3">
                                    <span class="px-2 py-0.5 rounded text-xs {{ $typeBadgeClasses[$movement->type] ?? 'bg-line-soft text-ink-soft' }}">
                                        {{ $typeLabels[$movement->type] ?? ucfirst($movement->type) }}
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-right font-medium {{ $movement->quantity >= 0 ? 'text-good' : 'text-critical' }}">
                                    {{ $movement->quantity >= 0 ? '+' : '' }}{{ $movement->quantity }}
                                </td>
                                <td class="px-4 py-3 text-right text-ink-soft">{{ $movement->quantity_after }}</td>
                                <td class="px-4 py-3 text-ink-soft">
                                    @if (in_array($movement->type, ['sale_out', 'return_in']) && $movement->reference)
                                        <a href="{{ route('sales.show', $movement->reference_id) }}" class="text-accent hover:underline">{{ $movement->reference->invoice_number }}</a>
                                    @else
                                        {{ $movement->notes ?? '—' }}
                                    @endif
                                </td>
                                <td class="px-4 py-3 text-ink-soft">{{ $movement->user->name }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="7" class="px-4 py-8 text-center text-ink-soft">No stock transactions found.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $movements->links() }}
        </div>
    </div>
</x-app-layout>
