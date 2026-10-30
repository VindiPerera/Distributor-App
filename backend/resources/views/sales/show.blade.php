<x-app-layout>
    <x-slot name="header">
        <div class="flex flex-wrap justify-between items-center gap-3 print:hidden">
            <div class="flex items-center gap-3">
                <a href="{{ route('sales.index') }}" class="p-2 -ml-2 rounded-lg text-ink-soft hover:bg-line-soft transition-colors" title="Back to orders">
                    <x-nav-icon name="arrow-left" class="w-5 h-5" />
                </a>
                <h2 class="font-display text-xl font-bold text-ink leading-tight">Invoice {{ $sale->invoice_number }}</h2>
                <span class="px-2.5 py-1 rounded-full text-xs font-semibold {{ $sale->statusBadgeClasses() }}">
                    {{ $sale->statusLabel() }}
                </span>
            </div>
            <div class="flex items-center gap-2">
                @if ($sale->isPending())
                    <form method="POST" action="{{ route('sales.update-status', $sale) }}" onsubmit="return confirm('Mark this order as completed?');">
                        @csrf
                        @method('PATCH')
                        <input type="hidden" name="status" value="completed">
                        <button type="submit" class="px-4 py-2 bg-good text-white text-sm font-semibold rounded-xl shadow-md shadow-good/25 hover:opacity-90 transition">Mark Completed</button>
                    </form>
                @endif
                @if (!$sale->isCancelled())
                    <form method="POST" action="{{ route('sales.update-status', $sale) }}" onsubmit="return confirm('Cancel this order? Stock will be restored and any balance reversed.');">
                        @csrf
                        @method('PATCH')
                        <input type="hidden" name="status" value="cancelled">
                        <button type="submit" class="px-4 py-2 bg-critical-soft text-critical text-sm font-semibold rounded-xl hover:opacity-90 transition">Cancel Order</button>
                    </form>
                @endif
                <button onclick="window.print()" class="inline-flex items-center gap-2 px-4 py-2 brand-gradient text-white text-sm font-semibold rounded-xl shadow-md shadow-accent/25 hover:opacity-95 transition">
                    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M6 9V3h12v6M6 18H4a1 1 0 01-1-1v-6a1 1 0 011-1h16a1 1 0 011 1v6a1 1 0 01-1 1h-2" stroke-linecap="round" stroke-linejoin="round"/><rect x="6" y="14" width="12" height="7" rx="1"/></svg>
                    Print Invoice
                </button>
            </div>
        </div>
    </x-slot>

    @php
        $balanceDue = round((float) $sale->total_amount - (float) $sale->paid_amount, 2);
    @endphp

    <div class="py-6 print:py-0" style="-webkit-print-color-adjust: exact; print-color-adjust: exact;">
        <div class="max-w-4xl mx-auto sm:px-6 lg:px-8 print:px-0 print:max-w-none">

            @if ($errors->any())
                <div class="mb-4 bg-critical-soft text-critical text-sm px-4 py-2.5 rounded-xl print:hidden">
                    {{ $errors->first() }}
                </div>
            @endif

            <div class="bg-surface rounded-3xl overflow-hidden shadow-[0_8px_40px_rgba(5,96,65,0.10)] print:shadow-none print:rounded-none">

                {{-- Letterhead --}}
                <div class="brand-gradient h-2"></div>
                <div class="px-8 pt-7 pb-6 flex flex-wrap items-start justify-between gap-6 border-b border-line">
                    <div class="flex items-center gap-4 min-w-0">
                        <div class="text-2xl font-extrabold tracking-tight text-ink">{{ $shopName ?? config('app.name') }}</div>
                    </div>
                    <div class="text-right">
                        <div class="text-3xl font-extrabold tracking-tight text-accent">INVOICE</div>
                        <div class="mt-1 text-sm font-semibold text-ink">#{{ $sale->invoice_number }}</div>
                        <div class="text-sm text-ink-soft">{{ $sale->sale_date->format('d M Y') }} &middot; {{ $sale->sale_date->format('H:i') }}</div>
                        <span class="inline-block mt-2 px-3 py-1 rounded-full text-xs font-semibold {{ $sale->statusBadgeClasses() }}">
                            {{ $sale->statusLabel() }}
                        </span>
                    </div>
                </div>

                @if ($shop?->address || $shop?->phone || $shop?->company_phone || $shop?->tax_id)
                    <div class="px-8 py-3 bg-accent-soft text-xs text-accent-dark font-medium text-center leading-relaxed">
                        {{ collect([
                            $shop?->address,
                            collect([$shop?->phone, $shop?->company_phone])->filter()->implode(' / ') ?: null,
                            $shop?->tax_id ? 'Reg/VAT No: ' . $shop->tax_id : null,
                        ])->filter()->implode('  ·  ') }}
                    </div>
                @endif

                <div class="px-8 py-7">

                    @if ($sale->isCancelled())
                        <div class="mb-6 border border-critical/30 bg-critical-soft text-critical text-sm font-semibold text-center py-2.5 rounded-xl">
                            This order has been CANCELLED — stock and balance have been reversed.
                        </div>
                    @endif

                    {{-- Bill-to / payment meta --}}
                    <div class="grid sm:grid-cols-2 gap-4">
                        <div class="rounded-2xl bg-line-soft p-5">
                            <div class="text-[11px] font-bold tracking-widest text-accent uppercase">Bill To</div>
                            <div class="mt-2 text-base font-bold text-ink">{{ $sale->customer->name ?? 'Walk-in Customer' }}</div>
                            @if ($sale->customer?->phone)
                                <div class="mt-0.5 text-sm text-ink-soft">{{ $sale->customer->phone }}</div>
                            @endif
                            @if ($sale->customer?->address)
                                <div class="text-sm text-ink-soft">{{ $sale->customer->address }}</div>
                            @endif
                        </div>
                        <div class="rounded-2xl bg-line-soft p-5 text-sm">
                            <div class="text-[11px] font-bold tracking-widest text-accent uppercase">Payment</div>
                            <div class="mt-2 flex items-center justify-between">
                                <span class="text-ink-soft">Method</span>
                                <span class="px-2.5 py-0.5 rounded-full text-xs font-semibold {{ $sale->paymentTypeBadgeClasses() }}">{{ $sale->paymentTypeLabel() }}</span>
                            </div>
                            @if ($sale->payment_reference)
                                <div class="mt-1.5 flex items-center justify-between gap-3">
                                    <span class="text-ink-soft">Reference</span>
                                    <span class="font-semibold text-ink text-right">{{ $sale->payment_reference }}</span>
                                </div>
                            @endif
                            <div class="mt-1.5 flex items-center justify-between">
                                <span class="text-ink-soft">Sold by</span>
                                <span class="font-semibold text-ink">{{ $sale->user->name }}</span>
                            </div>
                        </div>
                    </div>

                    {{-- Line items --}}
                    <div class="mt-7 rounded-2xl border border-line overflow-hidden">
                        <table class="w-full text-sm">
                            <thead>
                                <tr class="brand-gradient text-white text-left text-xs uppercase tracking-wider">
                                    <th class="py-3 px-4 w-10 font-semibold">#</th>
                                    <th class="py-3 px-4 font-semibold">Item</th>
                                    <th class="py-3 px-4 text-right font-semibold">Unit Price</th>
                                    <th class="py-3 px-4 text-right font-semibold">Discount</th>
                                    <th class="py-3 px-4 text-right font-semibold">Qty</th>
                                    <th class="py-3 px-4 text-right font-semibold">Amount</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($sale->items as $item)
                                    <tr class="border-b border-line last:border-0 {{ $loop->even ? 'bg-line-soft/60' : '' }}">
                                        <td class="py-3 px-4 text-ink-soft">{{ $loop->iteration }}</td>
                                        <td class="py-3 px-4">
                                            <div class="font-semibold text-ink">{{ $item->product->name }}</div>
                                            @if ($item->product->sku)
                                                <div class="text-xs text-ink-soft">SKU: {{ $item->product->sku }}</div>
                                            @endif
                                        </td>
                                        <td class="py-3 px-4 text-right text-ink-soft whitespace-nowrap">Rs. {{ number_format($item->unit_price, 2) }}</td>
                                        <td class="py-3 px-4 text-right text-ink-soft whitespace-nowrap">
                                            @if ($item->discount_type === 'amount' && $item->discount_amount > 0)
                                                Rs. {{ number_format($item->discount_amount, 2) }}
                                            @elseif ($item->discount_percent > 0)
                                                {{ rtrim(rtrim(number_format($item->discount_percent, 2), '0'), '.') }}%
                                            @else
                                                &mdash;
                                            @endif
                                        </td>
                                        <td class="py-3 px-4 text-right font-medium">{{ $item->quantity }}</td>
                                        <td class="py-3 px-4 text-right font-bold text-ink whitespace-nowrap">Rs. {{ number_format($item->line_total, 2) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>

                    @if ($sale->returns->isNotEmpty())
                        <div class="mt-5 rounded-2xl border border-critical/20 bg-critical-soft/50 p-4">
                            <div class="text-[11px] font-bold tracking-widest text-critical uppercase mb-2">Returns applied to this bill</div>
                            <table class="w-full text-sm">
                                <tbody>
                                    @foreach ($sale->returns as $return)
                                        <tr class="border-b border-critical/10 last:border-0">
                                            <td class="py-1.5">{{ $return->product->name }} &times; {{ $return->quantity }}</td>
                                            <td class="py-1.5 text-right text-critical font-medium">- Rs. {{ number_format($return->amount, 2) }}</td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    @endif

                    {{-- Notes + totals --}}
                    <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-between gap-6">
                        <div class="text-sm sm:max-w-xs">
                            @if ($sale->notes)
                                <div class="text-[11px] font-bold tracking-widest text-accent uppercase">Notes</div>
                                <div class="mt-1.5 text-ink-soft">{{ $sale->notes }}</div>
                            @endif
                        </div>

                        <div class="w-full sm:w-80 space-y-2 text-sm">
                            <div class="flex justify-between px-1">
                                <span class="text-ink-soft">Subtotal</span>
                                <span class="font-medium">Rs. {{ number_format($sale->subtotal, 2) }}</span>
                            </div>
                            @if ($sale->return_amount > 0)
                                <div class="flex justify-between px-1 text-critical">
                                    <span>Returns</span>
                                    <span class="font-medium">- Rs. {{ number_format($sale->return_amount, 2) }}</span>
                                </div>
                            @endif
                            <div class="flex justify-between items-center rounded-2xl brand-gradient text-white px-4 py-3.5 shadow-lg shadow-accent/25 print:shadow-none">
                                <span class="font-semibold">Total</span>
                                <span class="text-xl font-extrabold">Rs. {{ number_format($sale->total_amount, 2) }}</span>
                            </div>
                            @if ($sale->isCredit() || $balanceDue > 0)
                                <div class="flex justify-between px-1 text-ink-soft pt-1">
                                    <span>Amount Paid</span>
                                    <span class="font-medium">Rs. {{ number_format($sale->paid_amount, 2) }}</span>
                                </div>
                                <div class="flex justify-between rounded-xl bg-warn-soft text-warn px-4 py-2.5 font-bold">
                                    <span>Balance Due</span>
                                    <span>Rs. {{ number_format($balanceDue, 2) }}</span>
                                </div>
                            @endif
                        </div>
                    </div>
                </div>

                {{-- Footer --}}
                <div class="px-8 py-4 border-t border-line text-center text-xs text-ink-soft">
                    Thank you for your business &middot; {{ $shopName ?? config('app.name') }}
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
