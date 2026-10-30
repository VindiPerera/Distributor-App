<x-guest-layout>
    <h1 class="font-display text-[1.8rem] font-extrabold text-ink">Welcome back</h1>
    <p class="mt-1.5 text-sm text-ink-soft">Sign in to manage sales, stock, and customer accounts.</p>

    <x-auth-session-status class="mt-5" :status="session('status')" />

    <form method="POST" action="{{ route('login') }}" class="mt-7 space-y-5">
        @csrf

        <div>
            <x-input-label for="email" value="Email" required />
            <x-text-input id="email" class="block w-full" type="email" name="email" :value="old('email')" required autofocus autocomplete="username" placeholder="you@company.com" />
            <x-input-error :messages="$errors->get('email')" class="mt-1.5" />
        </div>

        <div>
            <x-input-label for="password" value="Password" required />
            <x-text-input id="password" class="block w-full" type="password" name="password" required autocomplete="current-password" placeholder="••••••••" />
            <x-input-error :messages="$errors->get('password')" class="mt-1.5" />
        </div>

        <div class="flex items-center justify-between">
            <label for="remember_me" class="inline-flex items-center gap-2 cursor-pointer">
                <input id="remember_me" type="checkbox" class="rounded border-line text-accent focus:ring-accent" name="remember">
                <span class="text-sm text-ink-soft">Remember me</span>
            </label>

            @if (Route::has('password.request'))
                <a class="text-sm text-accent hover:text-accent-hover font-medium" href="{{ route('password.request') }}">
                    Forgot password?
                </a>
            @endif
        </div>

        <x-primary-button class="w-full py-3 brand-gradient">
            Sign in
        </x-primary-button>
    </form>
</x-guest-layout>
