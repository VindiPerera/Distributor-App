<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Sale extends Model
{
    protected $fillable = [
        'invoice_number',
        'customer_id',
        'user_id',
        'payment_type',
        'payment_reference',
        'subtotal',
        'return_amount',
        'total_amount',
        'paid_amount',
        'status',
        'sale_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'return_amount' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'paid_amount' => 'decimal:2',
            'sale_date' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleItem::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SalePayment::class);
    }

    public function returns(): HasMany
    {
        return $this->hasMany(SaleReturn::class);
    }

    public function isCredit(): bool
    {
        return $this->payment_type === 'credit';
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }

    public function isCancelled(): bool
    {
        return $this->status === 'cancelled';
    }

    public function statusLabel(): string
    {
        return ucfirst($this->status);
    }

    public function statusBadgeClasses(): string
    {
        return match ($this->status) {
            'pending' => 'bg-warn-soft text-warn',
            'cancelled' => 'bg-critical-soft text-critical',
            default => 'bg-good-soft text-good',
        };
    }

    public function paymentTypeLabel(): string
    {
        // 'bank_transfer'/'split' can still appear on sales recorded before
        // POS billing was restricted to Cash/Credit only.
        return match ($this->payment_type) {
            'bank_transfer' => 'Bank Transfer',
            default => ucfirst($this->payment_type),
        };
    }

    public function paymentTypeBadgeClasses(): string
    {
        return match ($this->payment_type) {
            'credit' => 'bg-warn-soft text-warn',
            'split' => 'bg-accent-soft text-accent',
            default => 'bg-good-soft text-good',
        };
    }
}
