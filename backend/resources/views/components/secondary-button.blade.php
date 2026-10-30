<button {{ $attributes->merge(['type' => 'button', 'class' => 'inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-surface border border-line rounded-xl font-semibold text-sm text-ink hover:bg-line-soft focus:outline-none focus:ring-2 focus:ring-accent focus:ring-offset-2 focus:ring-offset-surface active:scale-[0.98] transition disabled:opacity-40']) }}>
    {{ $slot }}
</button>
