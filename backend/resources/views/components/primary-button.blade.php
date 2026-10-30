<button {{ $attributes->merge(['type' => 'submit', 'class' => 'inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-accent border border-transparent rounded-xl font-semibold text-sm text-white shadow-md shadow-accent/25 hover:bg-accent-hover focus:outline-none focus:ring-2 focus:ring-accent focus:ring-offset-2 focus:ring-offset-surface active:scale-[0.98] transition']) }}>
    {{ $slot }}
</button>
