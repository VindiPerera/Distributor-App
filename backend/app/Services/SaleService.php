<?php

namespace App\Services;

use App\Exceptions\InvalidReturnException;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use Illuminate\Support\Facades\DB;

class SaleService
{
    public function __construct(
        private CreditService $creditService,
        private InvoiceNumberService $invoiceNumbers,
    ) {
    }

    /**
     * Mark a pending order as completed, i.e. the back office has processed
     * it (stock and any credit ledger entry were already posted when the
     * order was placed, so nothing else needs to change here).
     */
    public function completeSale(Sale $sale): Sale
    {
        if (!$sale->isPending()) {
            throw new \RuntimeException('Only a pending order can be marked as completed.');
        }

        $sale->update(['status' => 'completed']);

        return $sale;
    }

    /**
     * Cancel an order, undoing what it committed: every sold item is
     * restocked, and any balance it posted to the customer's account is
     * reversed. Once cancelled, a sale is terminal — it can't be revived.
     */
    public function cancelSale(Sale $sale, int $userId): Sale
    {
        if ($sale->isCancelled()) {
            throw new \RuntimeException('This order is already cancelled.');
        }

        return DB::transaction(function () use ($sale, $userId) {
            $sale->load('items.product');

            foreach ($sale->items as $item) {
                // withTrashed(): the product may have been soft-deleted since
                // this sale was made — cancellation must still be able to
                // restock it (and reinstating stock on a deleted product is
                // harmless; it simply isn't sellable again until restored).
                $product = Product::withTrashed()->whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                $newStock = $product->stock_quantity + $item->quantity;

                $product->stockMovements()->create([
                    'type' => 'adjustment',
                    'quantity' => $item->quantity,
                    'quantity_after' => $newStock,
                    'reference_type' => Sale::class,
                    'reference_id' => $sale->id,
                    'notes' => "Order {$sale->invoice_number} cancelled — stock restored",
                    'user_id' => $userId,
                ]);

                $product->update(['stock_quantity' => $newStock]);
            }

            $this->creditService->reverseSaleCredit($sale);

            $sale->update(['status' => 'cancelled']);

            return $sale;
        });
    }

    /**
     * Create a sale (cash or credit) with its line items, deduct stock,
     * apply any returned items from earlier purchases as a credit against
     * this sale's total, and — for credit sales, or a cash sale that wasn't
     * paid in full — post the outstanding amount to the customer's ledger.
     *
     * A customer is always required: bills are always issued to a named
     * customer, never anonymously.
     *
     * $items: array of ['product_id' => int, 'quantity' => int, 'discount_type' => 'percent'|'amount'|null,
     *                    'discount_percent' => float|null, 'discount_amount' => float|null]
     * $data['returns']: array of ['sale_item_id' => int, 'quantity' => int]
     */
    public function createSale(array $data, array $items): Sale
    {
        return DB::transaction(function () use ($data, $items) {
            $subtotal = 0;
            $lineItems = [];

            foreach ($items as $item) {
                $product = Product::whereKey($item['product_id'])->lockForUpdate()->firstOrFail();

                if ($product->stock_quantity < $item['quantity']) {
                    throw new \RuntimeException("Insufficient stock for product: {$product->name}");
                }

                $unitPrice = (float) $product->selling_price;
                $discountType = ($item['discount_type'] ?? 'percent') === 'amount' ? 'amount' : 'percent';

                if ($discountType === 'amount') {
                    $discountAmount = min(max((float) ($item['discount_amount'] ?? 0), 0), $unitPrice);
                    $discountPercent = 0;
                    $discountedPrice = round($unitPrice - $discountAmount, 2);
                } else {
                    $discountPercent = min(max((float) ($item['discount_percent'] ?? 0), 0), 100);
                    $discountAmount = 0;
                    $discountedPrice = round($unitPrice * (1 - $discountPercent / 100), 2);
                }

                $lineTotal = $discountedPrice * $item['quantity'];
                $subtotal += $lineTotal;

                $lineItems[] = [
                    'product' => $product,
                    'quantity' => $item['quantity'],
                    'unit_price' => $unitPrice,
                    'discount_type' => $discountType,
                    'discount_percent' => $discountPercent,
                    'discount_amount' => $discountAmount,
                    'discounted_price' => $discountedPrice,
                    'line_total' => $lineTotal,
                ];
            }

            $returnLines = $this->prepareReturns($data['returns'] ?? [], $data['customer_id']);
            $returnAmount = array_sum(array_column($returnLines, 'amount'));

            $paymentType = $data['payment_type'];
            $totalAmount = max($subtotal - $returnAmount, 0);

            // Credit sales are paid 0 up front. Cash sales are normally paid
            // in full, but the cashier may report a partial "paid_amount"
            // (the customer only handed over part of the total); anything
            // not explicitly reported is assumed paid in full.
            $paidAmount = $paymentType === 'credit'
                ? 0
                : (float) ($data['paid_amount'] ?? $totalAmount);
            $paidAmount = min(max($paidAmount, 0), $totalAmount);
            $balanceDue = round($totalAmount - $paidAmount, 2);

            $sale = Sale::create([
                'invoice_number' => $this->invoiceNumbers->next(),
                'customer_id' => $data['customer_id'],
                'user_id' => $data['user_id'],
                'payment_type' => $paymentType,
                'payment_reference' => $data['payment_reference'] ?? null,
                'subtotal' => $subtotal,
                'return_amount' => $returnAmount,
                'total_amount' => $totalAmount,
                'paid_amount' => $paidAmount,
                'status' => $data['status'] ?? 'completed',
                'sale_date' => now(),
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($lineItems as $line) {
                $sale->items()->create([
                    'product_id' => $line['product']->id,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'discount_type' => $line['discount_type'],
                    'discount_percent' => $line['discount_percent'],
                    'discount_amount' => $line['discount_amount'],
                    'discounted_price' => $line['discounted_price'],
                    'line_total' => $line['line_total'],
                ]);

                $newStock = $line['product']->stock_quantity - $line['quantity'];

                $line['product']->stockMovements()->create([
                    'type' => 'sale_out',
                    'quantity' => -$line['quantity'],
                    'quantity_after' => $newStock,
                    'reference_type' => Sale::class,
                    'reference_id' => $sale->id,
                    'user_id' => $data['user_id'],
                ]);

                $line['product']->update(['stock_quantity' => $newStock]);
            }

            $this->applyReturns($sale, $returnLines, $data['user_id']);

            if ($balanceDue > 0) {
                $customer = Customer::findOrFail($data['customer_id']);
                $this->creditService->recordSaleOnCredit($customer, $sale, $balanceDue);
            }

            return $sale->load('items.product', 'customer', 'returns.product');
        });
    }

    /**
     * Validates each requested return against how much of that original
     * sale item is still returnable (its quantity minus whatever was
     * already returned against it in earlier sales), and resolves the
     * refund amount at the price the customer actually paid for it.
     *
     * $returns: array of ['sale_item_id' => int, 'quantity' => int]
     *
     * @return array<int, array{originalItem: SaleItem, quantity: int, unitPrice: float, amount: float}>
     */
    private function prepareReturns(array $returns, int $customerId): array
    {
        $lines = [];

        foreach ($returns as $return) {
            $quantity = (int) ($return['quantity'] ?? 0);
            if ($quantity <= 0) {
                continue;
            }

            $originalItem = SaleItem::with('sale', 'product')
                ->whereKey($return['sale_item_id'])
                ->lockForUpdate()
                ->firstOrFail();

            // A return can only be made against that same customer's own
            // past purchase — never someone else's sale.
            if ((int) $originalItem->sale->customer_id !== $customerId) {
                throw InvalidReturnException::notOwnedByCustomer($originalItem->product->name);
            }

            $alreadyReturned = (int) SaleReturn::where('original_sale_item_id', $originalItem->id)->sum('quantity');
            $returnable = $originalItem->quantity - $alreadyReturned;

            if ($quantity > $returnable) {
                throw InvalidReturnException::tooMany($originalItem->product->name, $quantity, max($returnable, 0));
            }

            $unitPrice = (float) $originalItem->discounted_price;

            $lines[] = [
                'originalItem' => $originalItem,
                'quantity' => $quantity,
                'unitPrice' => $unitPrice,
                'amount' => round($unitPrice * $quantity, 2),
            ];
        }

        return $lines;
    }

    /**
     * Records each prepared return against the new sale and puts the
     * returned quantity back into stock.
     */
    private function applyReturns(Sale $sale, array $returnLines, int $userId): void
    {
        foreach ($returnLines as $line) {
            $originalItem = $line['originalItem'];
            $product = $originalItem->product;

            $sale->returns()->create([
                'original_sale_item_id' => $originalItem->id,
                'product_id' => $product->id,
                'quantity' => $line['quantity'],
                'unit_price' => $line['unitPrice'],
                'amount' => $line['amount'],
            ]);

            $freshProduct = Product::whereKey($product->id)->lockForUpdate()->first();
            $newStock = $freshProduct->stock_quantity + $line['quantity'];

            $freshProduct->stockMovements()->create([
                'type' => 'return_in',
                'quantity' => $line['quantity'],
                'quantity_after' => $newStock,
                'reference_type' => Sale::class,
                'reference_id' => $sale->id,
                'user_id' => $userId,
            ]);

            $freshProduct->update(['stock_quantity' => $newStock]);
        }
    }
}
