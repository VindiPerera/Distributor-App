<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        <title>{{ isset($title) ? $title . ' · ' : '' }}{{ $shopName ?? config('app.name') }}</title>

        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="font-sans antialiased bg-paper text-ink">
        <div class="min-h-screen flex" x-data="{ mobileNavOpen: false }">

            <!-- Sidebar -->
            <aside
                class="fixed inset-y-0 left-0 z-40 w-64 brand-gradient shadow-xl shadow-accent-dark/20 flex flex-col transition-transform -translate-x-full lg:translate-x-0 print:hidden"
                :class="{ 'translate-x-0': mobileNavOpen }"
            >
                <div class="h-20 flex items-center gap-3 px-5 border-b border-white/15 shrink-0">
                    <img src="{{ asset('logo/logo.png') }}" alt="{{ $shopName ?? config('app.name') }}" class="h-10 w-10 rounded-xl bg-white object-contain shrink-0 p-1 shadow-md">
                    <span class="font-display text-[1.05rem] font-bold leading-tight text-white truncate">{{ $shopName ?? config('app.name') }}</span>
                </div>

                <nav class="flex-1 overflow-y-auto py-4 px-3 space-y-0.5">
                    @php
                        $pendingOrderCount = \App\Models\Sale::where('status', 'pending')->count();
                        $navItems = [
                            ['route' => 'dashboard', 'active' => 'dashboard', 'label' => 'Dashboard', 'icon' => 'grid'],
                            ['route' => 'sales.index', 'active' => 'sales.*', 'label' => 'Orders', 'icon' => 'receipt', 'badge' => $pendingOrderCount],
                            ['route' => 'sale-returns.index', 'active' => 'sale-returns.*', 'label' => 'Returns', 'icon' => 'receipt'],
                            ['route' => 'customers.index', 'active' => 'customers.*', 'label' => 'Customers', 'icon' => 'users'],
                            ['route' => 'customer-categories.index', 'active' => 'customer-categories.*', 'label' => 'Customer Categories', 'icon' => 'tag'],
                            ['route' => 'products.index', 'active' => 'products.*', 'label' => 'Products', 'icon' => 'box'],
                            ['route' => 'stock-adjustments.index', 'active' => 'stock-adjustments.*', 'label' => 'Stock Adjustments', 'icon' => 'chart'],
                            ['route' => 'stock-transactions.index', 'active' => 'stock-transactions.*', 'label' => 'Stock Transactions', 'icon' => 'receipt'],
                            ['route' => 'categories.index', 'active' => 'categories.*', 'label' => 'Categories', 'icon' => 'tag'],
                            ['route' => 'suppliers.index', 'active' => 'suppliers.*', 'label' => 'Suppliers', 'icon' => 'truck'],
                            ['route' => 'reports.receivables', 'active' => 'reports.receivables', 'label' => 'Receivables', 'icon' => 'chart'],
                            ['route' => 'reports.low-stock', 'active' => 'reports.low-stock', 'label' => 'Low Stock', 'icon' => 'box'],
                        ];
                    @endphp

                    @foreach ($navItems as $item)
                        @php $isActive = request()->routeIs($item['active']); @endphp
                        <a href="{{ route($item['route']) }}"
                           class="flex items-center gap-3 px-3 py-2 rounded-xl text-[0.9rem] font-medium transition-all {{ $isActive ? 'bg-white text-accent shadow-md shadow-black/10' : 'text-white/80 hover:bg-white/10 hover:text-white' }}">
                            <x-nav-icon :name="$item['icon']" class="w-[18px] h-[18px] shrink-0" />
                            <span class="flex-1">{{ $item['label'] }}</span>
                            @if (!empty($item['badge']))
                                <span class="inline-flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full text-[11px] font-semibold {{ $isActive ? 'bg-accent text-white' : 'bg-warn text-white' }}">
                                    {{ $item['badge'] }}
                                </span>
                            @endif
                        </a>
                    @endforeach

                    @if (Auth::user()->isAdmin())
                        <div class="pt-3 mt-3 border-t border-white/15">
                            <a href="{{ route('reports.dashboard') }}"
                               class="flex items-center gap-3 px-3 py-2 rounded-xl text-[0.9rem] font-medium transition-all {{ request()->routeIs('reports.dashboard') ? 'bg-white text-accent shadow-md shadow-black/10' : 'text-white/80 hover:bg-white/10 hover:text-white' }}">
                                <x-nav-icon name="chart" class="w-[18px] h-[18px] shrink-0" />
                                Reports Dashboard
                            </a>
                            <a href="{{ route('users.index') }}"
                               class="flex items-center gap-3 px-3 py-2 rounded-xl text-[0.9rem] font-medium transition-all {{ request()->routeIs('users.*') ? 'bg-white text-accent shadow-md shadow-black/10' : 'text-white/80 hover:bg-white/10 hover:text-white' }}">
                                <x-nav-icon name="badge" class="w-[18px] h-[18px] shrink-0" />
                                Staff
                            </a>
                            <a href="{{ route('shop-settings.edit') }}"
                               class="flex items-center gap-3 px-3 py-2 rounded-xl text-[0.9rem] font-medium transition-all {{ request()->routeIs('shop-settings.*') ? 'bg-white text-accent shadow-md shadow-black/10' : 'text-white/80 hover:bg-white/10 hover:text-white' }}">
                                <x-nav-icon name="settings" class="w-[18px] h-[18px] shrink-0" />
                                Shop Details
                            </a>
                        </div>
                    @endif
                </nav>

                <div class="border-t border-white/15 p-3">
                    <div x-data="{ open: false }" class="relative">
                        <button @click="open = !open" @click.outside="open = false"
                                class="w-full flex items-center gap-3 px-2.5 py-2 rounded-lg hover:bg-white/10 transition-colors text-left">
                            <span class="w-8 h-8 rounded-full bg-white text-accent flex items-center justify-center text-xs font-semibold shrink-0">
                                {{ strtoupper(substr(Auth::user()->name, 0, 1)) }}
                            </span>
                            <span class="min-w-0 flex-1">
                                <span class="block text-sm font-medium text-white truncate">{{ Auth::user()->name }}</span>
                                <span class="block text-xs text-white/70 capitalize">{{ Auth::user()->role }}</span>
                            </span>
                            <svg class="w-4 h-4 text-white/70 shrink-0" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" /></svg>
                        </button>

                        <div x-show="open" x-transition style="display: none;"
                             class="absolute bottom-full left-0 mb-2 w-full rounded-lg border border-line bg-surface shadow-lg py-1 z-50">
                            <a href="{{ route('profile.edit') }}" class="flex items-center gap-2.5 px-3 py-2 text-sm text-ink-soft hover:bg-line-soft hover:text-ink transition-colors">
                                <x-nav-icon name="settings" class="w-4 h-4" />
                                Profile settings
                            </a>
                            <form method="POST" action="{{ route('logout') }}">
                                @csrf
                                <button type="submit" class="w-full flex items-center gap-2.5 px-3 py-2 text-sm text-critical hover:bg-critical-soft transition-colors">
                                    <x-nav-icon name="logout" class="w-4 h-4" />
                                    Log out
                                </button>
                            </form>
                        </div>
                    </div>
                </div>
            </aside>

            <!-- Mobile nav backdrop -->
            <div x-show="mobileNavOpen" @click="mobileNavOpen = false" x-transition.opacity
                 style="display: none;" class="fixed inset-0 bg-ink/40 z-30 lg:hidden print:hidden"></div>

            <!-- Main -->
            <div class="flex-1 flex flex-col min-w-0 lg:pl-64 print:pl-0">
                <!-- Mobile top bar -->
                <div class="lg:hidden print:hidden h-14 flex items-center gap-3 px-4 border-b border-line bg-surface/90 backdrop-blur sticky top-0 z-20">
                    <button @click="mobileNavOpen = true" class="p-1.5 -ml-1.5 text-ink-soft">
                        <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path stroke-linecap="round" d="M4 6h16M4 12h16M4 18h16"/></svg>
                    </button>
                    <span class="font-display font-bold text-ink">{{ $shopName ?? config('app.name') }}</span>
                </div>

                @isset($header)
                    <header class="bg-surface/80 backdrop-blur border-b border-line px-6 lg:px-10 py-6 print:hidden">
                        <div class="max-w-6xl">
                            {{ $header }}
                        </div>
                    </header>
                @endisset

                <main class="flex-1 px-6 lg:px-10 py-8">
                    <div class="max-w-6xl">
                        @if (session('status'))
                            <div class="mb-6 flex items-center gap-2.5 rounded-xl border border-good/25 bg-good-soft px-4 py-3 text-sm font-medium text-good">
                                <svg class="w-4 h-4 shrink-0" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" /></svg>
                                {{ session('status') }}
                            </div>
                        @endif

                        {{ $slot }}
                    </div>
                </main>
            </div>
        </div>

    </body>
</html>
