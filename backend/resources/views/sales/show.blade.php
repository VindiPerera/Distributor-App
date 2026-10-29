<x-app-layout>
    <x-slot name="header">
        <div class="flex justify-between items-center print:hidden">
            <div class="flex items-center gap-3">
                <h2 class="font-display text-xl font-semibold text-ink leading-tight">Invoice {{ $sale->invoice_number }}</h2>
                <span class="px-2.5 py-1 rounded text-xs font-medium {{ $sale->statusBadgeClasses() }}">
                    {{ $sale->statusLabel() }}
                </span>
            </div>
            <div class="flex items-center gap-2">
                @if ($sale->isPending())
                    <form method="POST" action="{{ route('sales.update-status', $sale) }}" onsubmit="return confirm('Mark this order as completed?');">
                        @csrf
                        @method('PATCH')
                        <input type="hidden" name="status" value="completed">
                        <button type="submit" class="px-4 py-2 bg-good text-white text-sm rounded-md hover:opacity-90">Mark Completed</button>
                    </form>
                @endif
                @if (!$sale->isCancelled())
                    <form method="POST" action="{{ route('sales.update-status', $sale) }}" onsubmit="return confirm('Cancel this order? Stock will be restored and any balance reversed.');">
                        @csrf
                        @method('PATCH')
                        <input type="hidden" name="status" value="cancelled">
                        <button type="submit" class="px-4 py-2 bg-critical-soft text-critical text-sm rounded-md hover:opacity-90">Cancel Order</button>
                    </form>
                @endif
                <button onclick="window.print()" class="px-4 py-2 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Print Invoice</button>
            </div>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">

            @if ($errors->any())
                <div class="mb-4 bg-critical-soft text-critical text-sm px-4 py-2 rounded print:hidden">
                    {{ $errors->first() }}
                </div>
            @endif

            <div class="bg-surface border border-line shadow-sm rounded-lg p-8">

                @if ($sale->isCancelled())
                    <div class="mb-6 border border-critical bg-critical-soft text-critical text-sm font-semibold text-center py-2 rounded">
                        This order has been CANCELLED — stock and balance have been reversed.
                    </div>
                @endif

                <div class="flex justify-between items-start mb-6">
                    <div class="flex items-start gap-3">
                        <img src="{{ asset('logo/logo.png') }}" alt="{{ $shopName ?? config('app.name') }}" class="h-12 w-auto object-contain shrink-0">
                        <div>
                            <h1 class="text-lg font-bold text-ink">{{ $shopName ?? config('app.name') }}</h1>
                            <p class="text-sm text-ink-soft">Invoice #{{ $sale->invoice_number }}</p>
                            <p class="text-sm text-ink-soft">{{ $sale->sale_date->format('Y-m-d H:i') }}</p>
                        </div>
                    </div>
                    <div class="text-right">
                        <span class="px-3 py-1 rounded text-sm font-medium {{ $sale->paymentTypeBadgeClasses() }}">
                            {{ $sale->paymentTypeLabel() }} Sale
                        </span>
                        <p class="text-xs font-medium mt-1 {{ $sale->statusBadgeClasses() }} inline-block px-2 py-0.5 rounded">
                            {{ $sale->statusLabel() }}
                        </p>
                        @if ($sale->payment_reference)
                            <p class="text-sm font-medium text-ink mt-2">Ref: {{ $sale->payment_reference }}</p>
                        @endif
                        <p class="text-sm text-ink-soft mt-1">Sold by: {{ $sale->user->name }}</p>
                    </div>
                </div>

                <div class="mb-6">
                    <div class="text-sm text-ink-soft">Bill To</div>
                    <div class="font-medium text-ink">{{ $sale->customer->name ?? 'Walk-in Customer' }}</div>
                    @if ($sale->customer?->phone)
                        <div class="text-sm text-ink-soft">{{ $sale->customer->phone }}</div>
                    @endif
                </div>

                <table class="w-full text-sm mb-6">
                    <thead>
                        <tr class="text-left text-ink-soft border-b border-line">
                            <th class="py-2">Product</th>
                            <th class="text-right">Discounted Price</th>
                            <th class="text-right">Qty</th>
                            <th class="text-right">Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($sale->items as $item)
                            <tr class="border-b border-line last:border-0">
                                <td class="py-2">
                                    {{ $item->product->name }}
                                    <div class="text-xs text-ink-soft">
                                        Rs. {{ number_format($item->unit_price, 2) }} each
                                        @if ($item->discount_type === 'amount' && $item->discount_amount > 0)
                                            &middot; Rs. {{ number_format($item->discount_amount, 2) }} off
                                        @elseif ($item->discount_percent > 0)
                                            &middot; {{ rtrim(rtrim(number_format($item->discount_percent, 2), '0'), '.') }}% off
                                        @endif
                                    </div>
                                </td>
                                <td class="text-right">Rs. {{ number_format($item->discounted_price, 2) }}</td>
                                <td class="text-right">{{ $item->quantity }}</td>
                                <td class="text-right">Rs. {{ number_format($item->line_total, 2) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>

                @if ($sale->returns->isNotEmpty())
                    <div class="mb-6">
                        <div class="text-sm text-ink-soft mb-2">Returns applied to this bill</div>
                        <table class="w-full text-sm">
                            <tbody>
                                @foreach ($sale->returns as $return)
                                    <tr class="border-b border-line last:border-0">
                                        <td class="py-1.5">{{ $return->product->name }} &times; {{ $return->quantity }}</td>
                                        <td class="py-1.5 text-right text-critical">- Rs. {{ number_format($return->amount, 2) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @endif

                <div class="flex justify-end">
                    <div class="w-64 space-y-1 text-sm">
                        <div class="flex justify-between">
                            <span class="text-ink-soft">Subtotal</span>
                            <span>Rs. {{ number_format($sale->subtotal, 2) }}</span>
                        </div>
                        @if ($sale->return_amount > 0)
                            <div class="flex justify-between text-critical">
                                <span>Returns</span>
                                <span>- Rs. {{ number_format($sale->return_amount, 2) }}</span>
                            </div>
                        @endif
                        <div class="flex justify-between text-lg font-bold border-t border-line pt-1">
                            <span>Total</span>
                            <span>Rs. {{ number_format($sale->total_amount, 2) }}</span>
                        </div>
                    </div>
                </div>

                @if ($sale->notes)
                    <div class="mt-6 text-sm text-ink-soft">
                        <div class="font-medium text-ink">Notes</div>
                        {{ $sale->notes }}
                    </div>
                @endif

            </div>
        </div>
    </div>
</x-app-layout>
