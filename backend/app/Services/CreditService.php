<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerLedgerEntry;
use App\Models\Payment;
use App\Models\Sale;
use Illuminate\Support\Facades\DB;

class CreditService
{
    /**
     * Record a sale's unpaid portion against a customer's account. Used both
     * for full credit sales (nothing paid up front) and for cash/split sales
     * where the customer only paid part of the total — in both cases the
     * outstanding amount is the same debt to track on the ledger.
     */
    public function recordSaleOnCredit(Customer $customer, Sale $sale, ?float $amount = null): CustomerLedgerEntry
    {
        return DB::transaction(function () use ($customer, $sale, $amount) {
            $lockedCustomer = Customer::whereKey($customer->id)->lockForUpdate()->firstOrFail();
            $owed = $amount ?? (float) $sale->total_amount;

            $newBalance = (float) $lockedCustomer->current_balance + $owed;

            $entry = $lockedCustomer->ledgerEntries()->create([
                'type' => 'sale',
                'amount' => $owed,
                'balance_after' => $newBalance,
                'reference_type' => Sale::class,
                'reference_id' => $sale->id,
            ]);

            $lockedCustomer->update(['current_balance' => $newBalance]);

            return $entry;
        });
    }

    /**
     * Reverse whatever this sale posted to the customer's ledger (if
     * anything) — used when an order is cancelled after its balance was
     * already recorded. Fully-paid cash sales never posted a ledger entry,
     * so there's nothing to do for those.
     */
    public function reverseSaleCredit(Sale $sale): ?CustomerLedgerEntry
    {
        return DB::transaction(function () use ($sale) {
            $entries = CustomerLedgerEntry::where('reference_type', Sale::class)
                ->where('reference_id', $sale->id)
                ->whereIn('type', ['sale', 'adjustment'])
                ->get();

            // Net owed for this sale: the original posting plus any edit
            // adjustments made while it was pending.
            $owed = round((float) $entries->sum('amount'), 2);
            $original = $entries->firstWhere('type', 'sale');

            if (!$original || $owed == 0.0) {
                return null;
            }

            $customer = Customer::whereKey($original->customer_id)->lockForUpdate()->firstOrFail();
            $newBalance = (float) $customer->current_balance - $owed;

            $entry = $customer->ledgerEntries()->create([
                'type' => 'adjustment',
                'amount' => -$owed,
                'balance_after' => $newBalance,
                'reference_type' => Sale::class,
                'reference_id' => $sale->id,
                'notes' => "Order {$sale->invoice_number} cancelled — balance reversed",
            ]);

            $customer->update(['current_balance' => $newBalance]);

            return $entry;
        });
    }

    /**
     * After a pending order is edited, bring what it has posted to the
     * customer's ledger in line with the new outstanding amount.
     */
    public function adjustSaleCredit(Sale $sale, float $newBalanceDue): ?CustomerLedgerEntry
    {
        return DB::transaction(function () use ($sale, $newBalanceDue) {
            $entries = CustomerLedgerEntry::where('reference_type', Sale::class)
                ->where('reference_id', $sale->id)
                ->whereIn('type', ['sale', 'adjustment'])
                ->get();

            $currentlyOwed = round((float) $entries->sum('amount'), 2);
            $delta = round($newBalanceDue - $currentlyOwed, 2);

            if ($delta == 0.0) {
                return null;
            }

            $customer = Customer::findOrFail($sale->customer_id);

            if ($entries->isEmpty()) {
                return $this->recordSaleOnCredit($customer, $sale, $newBalanceDue);
            }

            $locked = Customer::whereKey($customer->id)->lockForUpdate()->firstOrFail();
            $newBalance = (float) $locked->current_balance + $delta;

            $entry = $locked->ledgerEntries()->create([
                'type' => 'adjustment',
                'amount' => $delta,
                'balance_after' => $newBalance,
                'reference_type' => Sale::class,
                'reference_id' => $sale->id,
                'notes' => "Order {$sale->invoice_number} edited",
            ]);

            $locked->update(['current_balance' => $newBalance]);

            return $entry;
        });
    }

    /**
     * Record a payment from a customer, reducing their outstanding balance.
     */
    public function recordPayment(Customer $customer, array $data): Payment
    {
        return DB::transaction(function () use ($customer, $data) {
            $lockedCustomer = Customer::whereKey($customer->id)->lockForUpdate()->firstOrFail();

            $payment = $lockedCustomer->payments()->create([
                'user_id' => $data['user_id'],
                'amount' => $data['amount'],
                'method' => $data['method'] ?? 'cash',
                'reference_no' => $data['reference_no'] ?? null,
                'paid_at' => $data['paid_at'] ?? now(),
                'notes' => $data['notes'] ?? null,
            ]);

            $newBalance = (float) $lockedCustomer->current_balance - (float) $payment->amount;

            $lockedCustomer->ledgerEntries()->create([
                'type' => 'payment',
                'amount' => -$payment->amount,
                'balance_after' => $newBalance,
                'reference_type' => Payment::class,
                'reference_id' => $payment->id,
            ]);

            $lockedCustomer->update(['current_balance' => $newBalance]);

            return $payment;
        });
    }

    /**
     * Aging buckets (0-30 / 31-60 / 61-90 / 90+ days) for a customer's
     * outstanding credit sales, based on unpaid sale ledger entries.
     */
    public function agingSummary(Customer $customer): array
    {
        $buckets = ['0_30' => 0.0, '31_60' => 0.0, '61_90' => 0.0, 'over_90' => 0.0];

        $customer->ledgerEntries()
            ->where('type', 'sale')
            ->orderBy('created_at')
            ->get()
            ->each(function (CustomerLedgerEntry $entry) use (&$buckets) {
                $days = $entry->created_at->diffInDays(now());
                $bucket = match (true) {
                    $days <= 30 => '0_30',
                    $days <= 60 => '31_60',
                    $days <= 90 => '61_90',
                    default => 'over_90',
                };
                $buckets[$bucket] += (float) $entry->amount;
            });

        return $buckets;
    }
}
