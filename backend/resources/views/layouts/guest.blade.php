<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        <title>{{ config('app.name') }}</title>

        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="font-sans antialiased bg-paper text-ink">
        <div class="min-h-screen grid lg:grid-cols-2">

            <!-- Brand side -->
            <div class="hidden lg:flex flex-col p-12 bg-ink text-paper relative overflow-hidden">
                <div class="absolute inset-0 opacity-[0.07]" style="background-image: radial-gradient(circle at 1px 1px, currentColor 1px, transparent 0); background-size: 28px 28px;"></div>

                <div class="relative flex-1 flex items-center">
                    <div class="max-w-sm">
                        <p class="font-display text-[2rem] leading-[1.15] text-wrap-balance">
                            One system for sales, stock, and customer accounts.
                        </p>
                        <p class="mt-4 text-sm text-paper/60 leading-relaxed">
                            Ring up sales, track inventory in real time, manage customer credit, and print receipts in English or Sinhala — all from one distribution management system.
                        </p>
                    </div>
                </div>

                <p class="relative text-xs text-paper/40">&copy; {{ date('Y') }} {{ config('app.name') }}</p>
            </div>

            <!-- Form side -->
            <div class="flex items-center justify-center p-6 sm:p-12">
                <div class="w-full max-w-sm">
                    <div class="lg:hidden flex items-center gap-2.5 mb-10">
                        <img src="{{ asset('logo/logo.png') }}" alt="{{ config('app.name') }}" class="w-7 h-7 rounded object-contain">
                        <span class="font-display text-lg font-semibold text-ink">{{ config('app.name') }}</span>
                    </div>

                    {{ $slot }}
                </div>
            </div>
        </div>
    </body>
</html>
