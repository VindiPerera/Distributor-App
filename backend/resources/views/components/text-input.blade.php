@props(['disabled' => false])

<input @disabled($disabled) {{ $attributes->merge(['class' => 'border-line bg-surface text-ink placeholder:text-ink-soft/60 rounded-xl text-sm py-2.5 focus:border-accent focus:ring-accent focus:ring-2 focus:ring-accent/20 transition-colors']) }}>
