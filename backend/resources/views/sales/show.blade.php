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

    @php
        $balanceDue = round((float) $sale->total_amount - (float) $sale->paid_amount, 2);
    @endphp

    <div class="py-8 print:py-0">
        <div class="max-w-5xl mx-auto sm:px-6 lg:px-8 print:px-0 print:max-w-none">

            @if ($errors->any())
                <div class="mb-4 bg-critical-soft text-critical text-sm px-4 py-2 rounded print:hidden">
                    {{ $errors->first() }}
                </div>
            @endif

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden p-8 print:border-0 print:shadow-none print:p-0">

                @if ($sale->isCancelled())
                    <div class="mb-6 border border-critical bg-critical-soft text-critical text-sm font-semibold text-center py-2 rounded">
                        This order has been CANCELLED — stock and balance have been reversed.
                    </div>
                @endif

                {{-- Letterhead --}}
                <div class="-mx-8 -mt-8 print:mx-0 print:mt-0">
                    <div class="h-1.5" style="background:#1a3c86"></div>
                    <div class="py-3 flex justify-center bg-white">
                        <img src="{{ asset('logo/invoice-header-content.png') }}" alt="{{ $shopName ?? config('app.name') }}" class="h-16 w-auto object-contain">
                    </div>
                    <div class="h-1.5" style="background:#1a3c86"></div>
                </div>

                <div class="flex flex-col items-center text-center gap-1.5 pt-3 pb-3 border-b-2 border-ink">
                    @if ($shop?->address || $shop?->phone || $shop?->company_phone || $shop?->tax_id)
                        <div class="text-xs text-ink-soft leading-tight">
                            {{ collect([
                                $shop?->address,
                                collect([$shop?->phone, $shop?->company_phone])->filter()->implode(' / ') ?: null,
                                $shop?->tax_id ? 'Reg/VAT No: ' . $shop->tax_id : null,
                            ])->filter()->implode(' · ') }}
                        </div>
                    @endif
                    <div class="flex items-center gap-2">
                        <span class="text-xs font-semibold tracking-widest text-ink-soft uppercase">Invoice #{{ $sale->invoice_number }}</span>
                        <span class="text-xs text-ink-soft">&middot; {{ $sale->sale_date->format('Y-m-d') }} {{ $sale->sale_date->format('H:i') }}</span>
                        <span class="px-2 py-0.5 rounded text-xs font-medium {{ $sale->statusBadgeClasses() }}">
                            {{ $sale->statusLabel() }}
                        </span>
                    </div>
                </div>

                {{-- Bill-to / payment meta --}}
                <div class="flex justify-between items-start gap-6 py-6">
                    <div>
                        <div class="text-xs font-semibold tracking-widest text-ink-soft uppercase">Bill To</div>
                        <div class="font-semibold text-ink mt-1">{{ $sale->customer->name ?? 'Walk-in Customer' }}</div>
                        @if ($sale->customer?->phone)
                            <div class="text-sm text-ink-soft">{{ $sale->customer->phone }}</div>
                        @endif
                        @if ($sale->customer?->address)
                            <div class="text-sm text-ink-soft max-w-xs">{{ $sale->customer->address }}</div>
                        @endif
                    </div>
                    <div class="text-right text-sm">
                        <div>
                            <span class="text-ink-soft">Payment: </span>
                            <span class="px-2 py-0.5 rounded text-xs font-medium {{ $sale->paymentTypeBadgeClasses() }}">{{ $sale->paymentTypeLabel() }}</span>
                        </div>
                        @if ($sale->payment_reference)
                            <div class="mt-1"><span class="text-ink-soft">Ref: </span><span class="font-medium text-ink">{{ $sale->payment_reference }}</span></div>
                        @endif
                        <div class="mt-1 text-ink-soft">Sold by {{ $sale->user->name }}</div>
                    </div>
                </div>

                {{-- Line items --}}
                <table class="w-full text-sm">
                    <thead>
                        <tr class="text-left text-ink-soft border-y border-line bg-line-soft print:bg-transparent">
                            <th class="py-2 px-2 w-8">#</th>
                            <th class="py-2 px-2">Item</th>
                            <th class="py-2 px-2 text-right">Unit Price</th>
                            <th class="py-2 px-2 text-right">Discount</th>
                            <th class="py-2 px-2 text-right">Qty</th>
                            <th class="py-2 px-2 text-right">Amount</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($sale->items as $item)
                            <tr class="border-b border-line">
                                <td class="py-2.5 px-2 text-ink-soft">{{ $loop->iteration }}</td>
                                <td class="py-2.5 px-2">
                                    <div class="font-medium text-ink">{{ $item->product->name }}</div>
                                    @if ($item->product->sku)
                                        <div class="text-xs text-ink-soft">SKU: {{ $item->product->sku }}</div>
                                    @endif
                                </td>
                                <td class="py-2.5 px-2 text-right text-ink-soft">Rs. {{ number_format($item->unit_price, 2) }}</td>
                                <td class="py-2.5 px-2 text-right text-ink-soft">
                                    @if ($item->discount_type === 'amount' && $item->discount_amount > 0)
                                        Rs. {{ number_format($item->discount_amount, 2) }}
                                    @elseif ($item->discount_percent > 0)
                                        {{ rtrim(rtrim(number_format($item->discount_percent, 2), '0'), '.') }}%
                                    @else
                                        &mdash;
                                    @endif
                                </td>
                                <td class="py-2.5 px-2 text-right">{{ $item->quantity }}</td>
                                <td class="py-2.5 px-2 text-right font-medium text-ink">Rs. {{ number_format($item->line_total, 2) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>

                @if ($sale->returns->isNotEmpty())
                    <div class="mt-5">
                        <div class="text-xs font-semibold tracking-widest text-ink-soft uppercase mb-2">Returns applied to this bill</div>
                        <table class="w-full text-sm">
                            <tbody>
                                @foreach ($sale->returns as $return)
                                    <tr class="border-b border-line last:border-0">
                                        <td class="py-1.5 px-2">{{ $return->product->name }} &times; {{ $return->quantity }}</td>
                                        <td class="py-1.5 px-2 text-right text-critical">- Rs. {{ number_format($return->amount, 2) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @endif

                {{-- Totals --}}
                <div class="flex justify-end mt-5">
                    <div class="w-72 space-y-1.5 text-sm">
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
                        <div class="flex justify-between text-lg font-bold border-t border-ink pt-1.5">
                            <span>Total</span>
                            <span>Rs. {{ number_format($sale->total_amount, 2) }}</span>
                        </div>
                        @if ($sale->isCredit() || $balanceDue > 0)
                            <div class="flex justify-between text-ink-soft pt-1">
                                <span>Amount Paid</span>
                                <span>Rs. {{ number_format($sale->paid_amount, 2) }}</span>
                            </div>
                            <div class="flex justify-between font-semibold text-warn">
                                <span>Balance Due</span>
                                <span>Rs. {{ number_format($balanceDue, 2) }}</span>
                            </div>
                        @endif
                    </div>
                </div>

                @if ($sale->notes)
                    <div class="mt-6 text-sm">
                        <div class="font-medium text-ink">Notes</div>
                        <div class="text-ink-soft">{{ $sale->notes }}</div>
                    </div>
                @endif

            </div>
        </div>
    </div>
</x-app-layout>
