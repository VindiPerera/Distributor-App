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
            <div class="hidden lg:flex flex-col p-12 brand-gradient text-white relative overflow-hidden">
                <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full bg-white/10"></div>
                <div class="absolute -bottom-32 -left-24 w-[28rem] h-[28rem] rounded-full bg-white/[0.07]"></div>

                <div class="relative flex items-center gap-3">
                    <img src="{{ asset('logo/logo.png') }}" alt="{{ config('app.name') }}" class="w-11 h-11 rounded-xl bg-white p-1 object-contain shadow-lg">
                    <span class="text-lg font-bold tracking-tight">{{ config('app.name') }}</span>
                </div>

                <div class="relative flex-1 flex items-center">
                    <div class="max-w-md">
                        <p class="font-display text-[2.4rem] font-extrabold leading-[1.1]">
                            One system for sales, stock, and customer accounts.
                        </p>
                        <p class="mt-5 text-base text-white/80 leading-relaxed">
                            Ring up sales, track inventory in real time, manage customer credit, and print receipts in English or Sinhala — all from one distribution management system.
                        </p>
                    </div>
                </div>

                <p class="relative text-xs text-white/60">&copy; {{ date('Y') }} {{ config('app.name') }}</p>
            </div>

            <!-- Form side -->
            <div class="flex items-center justify-center p-6 sm:p-12">
                <div class="w-full max-w-md bg-surface rounded-3xl p-8 sm:p-10 shadow-[0_8px_40px_rgba(5,96,65,0.10)] border border-line">
                    <div class="lg:hidden flex items-center justify-center gap-2.5 mb-8">
                        <img src="{{ asset('logo/logo.png') }}" alt="{{ config('app.name') }}" class="w-9 h-9 rounded-lg object-contain">
                        <span class="font-display text-lg font-bold text-ink">{{ config('app.name') }}</span>
                    </div>

                    {{ $slot }}
                </div>
            </div>
        </div>
    </body>
</html>
