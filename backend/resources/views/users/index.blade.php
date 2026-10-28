<x-app-layout>
    <x-slot name="header">
        <div class="flex justify-between items-center">
            <h2 class="font-display text-xl font-semibold text-ink leading-tight">Staff Accounts</h2>
            <a href="{{ route('users.create') }}" class="px-4 py-2 bg-accent text-white text-sm font-medium rounded-lg hover:bg-accent-hover transition-colors">+ New Account</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-4xl mx-auto sm:px-6 lg:px-8 space-y-4">

            @if (session('status'))
                <div class="bg-good-soft text-good text-sm px-4 py-2 rounded-lg">{{ session('status') }}</div>
            @endif
            @if ($errors->any())
                <div class="bg-critical-soft text-critical text-sm px-4 py-2 rounded-lg">{{ $errors->first() }}</div>
            @endif

            <form method="GET" class="flex gap-2">
                <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by name or email..."
                       class="border-line rounded-md shadow-sm text-sm w-72 focus:border-accent focus:ring-accent">
                <button class="px-3 py-1.5 bg-line-soft text-ink text-sm rounded-md hover:bg-line">Search</button>
                @if (request('search'))
                    <a href="{{ route('users.index') }}" class="self-center text-sm text-accent hover:underline">Reset</a>
                @endif
            </form>

            <div class="bg-surface border border-line shadow-sm rounded-lg overflow-hidden">
                <table class="w-full text-sm">
                    <thead class="bg-line-soft">
                        <tr class="text-left text-ink-soft">
                            <th class="px-4 py-3">Name</th>
                            <th class="px-4 py-3">Email</th>
                            <th class="px-4 py-3">Role</th>
                            <th class="px-4 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($users as $user)
                            <tr class="border-t border-line">
                                <td class="px-4 py-3 font-medium text-ink">{{ $user->name }}</td>
                                <td class="px-4 py-3 text-ink-soft">{{ $user->email }}</td>
                                <td class="px-4 py-3">
                                    <span class="px-2 py-0.5 rounded text-xs {{ $user->role === 'admin' ? 'bg-accent-soft text-accent' : 'bg-line-soft text-ink-soft' }}">
                                        {{ ucfirst($user->role) }}
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-right">
                                    @if ($user->id !== auth()->id())
                                        <form method="POST" action="{{ route('users.destroy', $user) }}" onsubmit="return confirm('Remove this account?')">
                                            @csrf
                                            @method('DELETE')
                                            <button class="text-critical hover:underline">Remove</button>
                                        </form>
                                    @endif
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="4" class="px-4 py-8 text-center text-ink-soft">No accounts found.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $users->links() }}
        </div>
    </div>
</x-app-layout>
