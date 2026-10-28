<x-app-layout>
    <x-slot name="header">
        <h2 class="font-display text-xl font-semibold text-ink leading-tight">Receivables / Aging Report</h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-6xl mx-auto sm:px-6 lg:px-8 space-y-6">

            <form method="GET" class="flex gap-2 flex-wrap items-center">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search customer by name..."
                       class="border-line rounded-md shadow-sm text-sm w-64 focus:border-accent focus:ring-accent">
                <label class="flex items-center gap-2 text-sm text-ink-soft">
                    Collections for
                    <input type="date" name="collected_date" value="{{ $collectedDate->format('Y-m-d') }}"
                           class="border-line rounded-md shadow-sm text-sm focus:border-accent focus:ring-accent">
                </label>
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Apply</button>
                @if (request('search') || request('collected_date'))
                    <a href="{{ route('reports.receivables') }}" class="text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="flex flex-col gap-4">
                <div class="bg-surface border border-line shadow-sm rounded-lg p-5 flex items-center justify-between">
                    <span class="text-sm text-ink-soft">0-30 days</span>
                    <span class="text-xl font-bold text-ink">Rs. {{ number_format($buckets['0_30'], 2) }}</span>
                </div>
                <div class="bg-surface border border-line shadow-sm rounded-lg p-5 flex items-center justify-between">
                    <span class="text-sm text-ink-soft">31-60 days</span>
                    <span class="text-xl font-bold text-ink">Rs. {{ number_format($buckets['31_60'], 2) }}</span>
                </div>
                <div class="bg-surface border border-line shadow-sm rounded-lg p-5 flex items-center justify-between">
                    <span class="text-sm text-ink-soft">61-90 days</span>
                    <span class="text-xl font-bold text-ink">Rs. {{ number_format($buckets['61_90'], 2) }}</span>
                </div>
                <div class="bg-surface border border-line shadow-sm rounded-lg p-5 flex items-center justify-between">
                    <span class="text-sm text-ink-soft">90+ days</span>
                    <span class="text-xl font-bold text-critical">Rs. {{ number_format($buckets['over_90'], 2) }}</span>
                </div>
                <div class="bg-good-soft border border-line shadow-sm rounded-lg p-5 flex items-center justify-between">
                    <span class="text-sm text-good">Collected {{ $collectedDate->isToday() ? 'Today' : $collectedDate->format('Y-m-d') }}</span>
                    <span class="text-xl font-bold text-good">Rs. {{ number_format($totalCollected, 2) }}</span>
                </div>
            </div>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Customer</th>
                            <th class="px-4 py-3 text-right">Balance</th>
                            <th class="px-4 py-3 text-right">Credit Limit</th>
                            <th class="px-4 py-3 text-right">Collected ({{ $collectedDate->format('M j') }})</th>
                            <th class="px-4 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($customers as $customer)
                            @php
                                $overLimit = $customer->current_balance > $customer->credit_limit;
                                $collected = (float) ($collectedToday[$customer->id] ?? 0);
                            @endphp
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 font-medium text-ink">{{ $customer->name }}</td>
                                <td class="px-4 py-3 text-right {{ $overLimit ? 'text-critical font-semibold' : '' }}">
                                    Rs. {{ number_format($customer->current_balance, 2) }}
                                </td>
                                <td class="px-4 py-3 text-right text-ink-soft">Rs. {{ number_format($customer->credit_limit, 2) }}</td>
                                <td class="px-4 py-3 text-right {{ $collected > 0 ? 'text-good font-semibold' : 'text-ink-soft' }}">
                                    {{ $collected > 0 ? 'Rs. ' . number_format($collected, 2) : '—' }}
                                </td>
                                <td class="px-4 py-3 text-right">
                                    <a href="{{ route('customers.show', $customer) }}" class="text-accent hover:underline">View / Payment History</a>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="5" class="px-4 py-8 text-center text-ink-soft">No outstanding balances found.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</x-app-layout>
