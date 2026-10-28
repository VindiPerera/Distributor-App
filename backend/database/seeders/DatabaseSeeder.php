<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Customer;
use App\Models\CustomerCategory;
use App\Models\Product;
use App\Models\Supplier;
use App\Models\User;
use App\Services\CreditService;
use App\Services\SaleService;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * Every write here goes through the same services the app itself uses
     * (SaleService, CreditService) rather than inserting rows directly, so
     * stock levels, invoice numbers, and customer balances/ledgers all stay
     * internally consistent — exactly as if a cashier had entered this data
     * by hand.
     */
    public function run(): void
    {
        // Default admin login: admin@test.com / password
        $admin = User::updateOrCreate(
            ['email' => 'admin@test.com'],
            [
                'name' => 'Admin',
                'password' => Hash::make('password'),
                'role' => 'admin',
            ]
        );

        $staff = User::updateOrCreate(
            ['email' => 'staff@test.com'],
            [
                'name' => 'Staff Cashier',
                'password' => Hash::make('password'),
                'role' => 'staff',
            ]
        );

        $categories = $this->seedCategories();
        $suppliers = $this->seedSuppliers();
        $products = $this->seedProducts($categories, $suppliers);
        $customerCategories = $this->seedCustomerCategories();
        $customers = $this->seedCustomers($customerCategories);
        $this->seedSalesAndPayments($customers, $products, $admin, $staff);
        $this->seedStockAdjustments($products, $admin);
    }

    /**
     * @return array<int, Category>
     */
    private function seedCategories(): array
    {
        $names = ['Beverages', 'Snacks', 'Dairy', 'Bakery', 'Household'];

        return collect($names)->map(fn ($name) => Category::updateOrCreate(
            ['name' => $name],
            ['description' => "$name products", 'is_active' => true]
        ))->all();
    }

    /**
     * @return array<int, Supplier>
     */
    private function seedSuppliers(): array
    {
        $suppliers = [
            ['name' => 'Ceylon Distributors', 'contact_person' => 'Nimal Perera', 'phone' => '0712345671', 'email' => 'nimal@ceylondist.lk'],
            ['name' => 'Lanka Wholesale', 'contact_person' => 'Kamal Silva', 'phone' => '0712345672', 'email' => 'kamal@lankawholesale.lk'],
            ['name' => 'Colombo Traders', 'contact_person' => 'Saman Fernando', 'phone' => '0712345673', 'email' => 'saman@colombotraders.lk'],
        ];

        return collect($suppliers)->map(fn ($s) => Supplier::updateOrCreate(
            ['name' => $s['name']],
            [
                'contact_person' => $s['contact_person'],
                'phone' => $s['phone'],
                'email' => $s['email'],
                'address' => 'Colombo, Sri Lanka',
                'is_active' => true,
            ]
        ))->all();
    }

    /**
     * @param array<int, Category> $categories
     * @param array<int, Supplier> $suppliers
     * @return array<int, Product>
     */
    private function seedProducts(array $categories, array $suppliers): array
    {
        $catalog = [
            ['name' => 'Coca Cola 1.5L', 'category' => 'Beverages', 'price' => 350, 'cost' => 280, 'stock' => 120, 'alert' => 20],
            ['name' => 'Orange Juice 1L', 'category' => 'Beverages', 'price' => 420, 'cost' => 330, 'stock' => 60, 'alert' => 15],
            ['name' => 'Mineral Water 500ml', 'category' => 'Beverages', 'price' => 80, 'cost' => 50, 'stock' => 300, 'alert' => 50],
            ['name' => 'Potato Chips 100g', 'category' => 'Snacks', 'price' => 220, 'cost' => 160, 'stock' => 18, 'alert' => 25],
            ['name' => 'Chocolate Biscuits', 'category' => 'Snacks', 'price' => 180, 'cost' => 130, 'stock' => 90, 'alert' => 20],
            ['name' => 'Cashew Nuts 200g', 'category' => 'Snacks', 'price' => 950, 'cost' => 760, 'stock' => 8, 'alert' => 10],
            ['name' => 'Fresh Milk 1L', 'category' => 'Dairy', 'price' => 390, 'cost' => 310, 'stock' => 45, 'alert' => 20],
            ['name' => 'Cheddar Cheese 200g', 'category' => 'Dairy', 'price' => 680, 'cost' => 540, 'stock' => 30, 'alert' => 10],
            ['name' => 'Yogurt Cup', 'category' => 'Dairy', 'price' => 95, 'cost' => 65, 'stock' => 150, 'alert' => 30],
            ['name' => 'White Bread Loaf', 'category' => 'Bakery', 'price' => 160, 'cost' => 110, 'stock' => 40, 'alert' => 15],
            ['name' => 'Chocolate Cake Slice', 'category' => 'Bakery', 'price' => 250, 'cost' => 180, 'stock' => 12, 'alert' => 10],
            ['name' => 'Dish Washing Liquid', 'category' => 'Household', 'price' => 450, 'cost' => 350, 'stock' => 55, 'alert' => 15],
            ['name' => 'Laundry Detergent 1kg', 'category' => 'Household', 'price' => 780, 'cost' => 620, 'stock' => 9, 'alert' => 10],
            ['name' => 'Toilet Tissue 4-pack', 'category' => 'Household', 'price' => 320, 'cost' => 250, 'stock' => 70, 'alert' => 20],
        ];

        $categoriesByName = collect($categories)->keyBy('name');

        return collect($catalog)->map(function ($p, $i) use ($categoriesByName, $suppliers) {
            return Product::updateOrCreate(
                ['sku' => 'SKU-' . str_pad($i + 1, 4, '0', STR_PAD_LEFT)],
                [
                    'name' => $p['name'],
                    'category_id' => $categoriesByName[$p['category']]->id,
                    'supplier_id' => $suppliers[$i % count($suppliers)]->id,
                    'unit' => 'pcs',
                    'cost_price' => $p['cost'],
                    'selling_price' => $p['price'],
                    'stock_quantity' => $p['stock'],
                    'low_stock_alert' => $p['alert'],
                    'is_active' => true,
                ]
            );
        })->all();
    }

    /**
     * @return array<int, CustomerCategory>
     */
    private function seedCustomerCategories(): array
    {
        $retail = CustomerCategory::updateOrCreate(
            ['name' => 'Retail', 'parent_id' => null],
            ['description' => 'Walk-in retail customers', 'is_active' => true]
        );
        $wholesale = CustomerCategory::updateOrCreate(
            ['name' => 'Wholesale', 'parent_id' => null],
            ['description' => 'Bulk-buying wholesale customers', 'is_active' => true]
        );
        $vip = CustomerCategory::updateOrCreate(
            ['name' => 'VIP', 'parent_id' => $wholesale->id],
            ['description' => 'High-volume VIP wholesale accounts', 'is_active' => true]
        );

        return [$retail, $wholesale, $vip];
    }

    /**
     * @param array<int, CustomerCategory> $categories
     * @return array<int, Customer>
     */
    private function seedCustomers(array $categories): array
    {
        [$retail, $wholesale, $vip] = $categories;

        $customers = [
            ['name' => 'Sunil Jayawardena', 'phone' => '0771234561', 'category_id' => $retail->id, 'credit_limit' => 10000],
            ['name' => 'Nadeesha Kumari', 'phone' => '0771234562', 'category_id' => $retail->id, 'credit_limit' => 5000],
            ['name' => 'Chaminda Perera', 'phone' => '0771234563', 'category_id' => $wholesale->id, 'credit_limit' => 50000],
            ['name' => 'Priyantha Store', 'phone' => '0771234564', 'category_id' => $vip->id, 'credit_limit' => 150000],
            ['name' => 'Dilani Fernando', 'phone' => '0771234565', 'category_id' => $retail->id, 'credit_limit' => 8000],
            ['name' => 'Ruwan Traders', 'phone' => '0771234566', 'category_id' => $wholesale->id, 'credit_limit' => 75000],
        ];

        return collect($customers)->map(fn ($c) => Customer::updateOrCreate(
            ['phone' => $c['phone']],
            [
                'name' => $c['name'],
                'email' => strtolower(str_replace(' ', '.', $c['name'])) . '@example.com',
                'address' => 'No. 12, Galle Road, Colombo',
                'customer_category_id' => $c['category_id'],
                'credit_limit' => $c['credit_limit'],
                'is_active' => true,
            ]
        ))->all();
    }

    /**
     * @param array<int, Customer> $customers
     * @param array<int, Product> $products
     */
    private function seedSalesAndPayments(array $customers, array $products, User $admin, User $staff): void
    {
        // Skip if sales already look seeded, so re-running db:seed doesn't
        // keep stacking duplicate sales/stock deductions on top of
        // whatever's already there.
        if (\App\Models\Sale::where('notes', 'Seeded demo sale')->exists()) {
            return;
        }

        $saleService = app(SaleService::class);
        $creditService = app(CreditService::class);

        // A spread of cash, credit, and cheque sales across the last couple
        // of weeks so Sales history, Receivables aging, and "collected
        // today" all have something to show.
        $plan = [
            ['customer' => 0, 'user' => $staff, 'daysAgo' => 10, 'paymentType' => 'cash', 'items' => [[0, 2, 0], [2, 5, 0]]],
            ['customer' => 1, 'user' => $staff, 'daysAgo' => 8, 'paymentType' => 'cash', 'items' => [[6, 3, 10], [9, 1, 0]]],
            ['customer' => 2, 'user' => $admin, 'daysAgo' => 35, 'paymentType' => 'credit', 'items' => [[3, 10, 0], [12, 4, 0]]],
            ['customer' => 3, 'user' => $admin, 'daysAgo' => 65, 'paymentType' => 'credit', 'items' => [[5, 6, 5], [7, 8, 0], [13, 15, 0]]],
            ['customer' => 4, 'user' => $staff, 'daysAgo' => 2, 'paymentType' => 'cash', 'items' => [[4, 4, 0], [8, 6, 0]]],
            ['customer' => 5, 'user' => $admin, 'daysAgo' => 95, 'paymentType' => 'credit', 'items' => [[1, 12, 0], [11, 5, 0]]],
            ['customer' => 0, 'user' => $staff, 'daysAgo' => 0, 'paymentType' => 'cheque', 'paymentReference' => 'Cheque No: 004521 BOC', 'items' => [[10, 3, 0]]],
            ['customer' => 2, 'user' => $admin, 'daysAgo' => 1, 'paymentType' => 'credit', 'items' => [[0, 20, 15], [1, 10, 0]]],
        ];

        $createdSales = [];

        foreach ($plan as $p) {
            $customer = $customers[$p['customer']];
            $saleDate = now()->subDays($p['daysAgo']);

            $items = collect($p['items'])->map(function ($item) use ($products) {
                [$productIndex, $qty, $discountPercent] = $item;
                return [
                    'product_id' => $products[$productIndex]->id,
                    'quantity' => $qty,
                    'discount_type' => 'percent',
                    'discount_percent' => $discountPercent,
                ];
            })->all();

            $sale = $saleService->createSale([
                'customer_id' => $customer->id,
                'user_id' => $p['user']->id,
                'payment_type' => $p['paymentType'],
                'payment_reference' => $p['paymentReference'] ?? null,
                'notes' => 'Seeded demo sale',
            ], $items);

            // Backdate the sale so history/aging/receivables filters have a
            // realistic spread instead of everything landing on "today".
            $sale->forceFill(['sale_date' => $saleDate, 'created_at' => $saleDate])->save();
            $sale->items()->update(['created_at' => $saleDate, 'updated_at' => $saleDate]);
            \App\Models\StockMovement::where('reference_type', \App\Models\Sale::class)
                ->where('reference_id', $sale->id)
                ->update(['created_at' => $saleDate, 'updated_at' => $saleDate]);
            \App\Models\CustomerLedgerEntry::where('reference_type', \App\Models\Sale::class)
                ->where('reference_id', $sale->id)
                ->update(['created_at' => $saleDate, 'updated_at' => $saleDate]);

            $createdSales[] = $sale;
        }

        // A couple of partial payments against the older credit sales, so
        // Receivables shows aging buckets with some already-collected
        // amounts, and the customer ledger/payment history has entries.
        $creditService->recordPayment($customers[2], [
            'user_id' => $admin->id,
            'amount' => 3000,
            'method' => 'cash',
            'paid_at' => now()->subDays(20),
            'notes' => 'Partial credit settlement',
        ]);

        $creditService->recordPayment($customers[3], [
            'user_id' => $admin->id,
            'amount' => 8000,
            'method' => 'bank_transfer',
            'paid_at' => now()->subDays(30),
            'notes' => 'Partial credit settlement',
        ]);

        // One payment made today, so Receivables' "Collected Today" column
        // and total aren't empty by default.
        $creditService->recordPayment($customers[5], [
            'user_id' => $staff->id,
            'amount' => 5000,
            'method' => 'cash',
            'paid_at' => now(),
            'notes' => 'Today\'s collection',
        ]);

        // A return against the very first sale, so the Returns page and
        // Sales list's Returns column have something to show.
        $firstSale = $createdSales[0];
        $firstItem = $firstSale->items()->first();
        if ($firstItem && $firstItem->quantity > 1) {
            $saleService->createSale([
                'customer_id' => $firstSale->customer_id,
                'user_id' => $staff->id,
                'payment_type' => 'cash',
                'notes' => 'Seeded demo sale (with return)',
                'returns' => [
                    ['sale_item_id' => $firstItem->id, 'quantity' => 1],
                ],
            ], [
                ['product_id' => $products[1]->id, 'quantity' => 1],
            ]);
        }
    }

    /**
     * @param array<int, Product> $products
     */
    private function seedStockAdjustments(array $products, User $admin): void
    {
        if (\App\Models\StockMovement::where('notes', 'Seeded opening stock count')->exists()) {
            return;
        }

        // A stock-in and a stock-out adjustment, so Stock Adjustments /
        // Stock Transactions have a mix of movement types to look at
        // beyond what the seeded sales already generated.
        // Restock a healthy-stock product (not one of the seeded low-stock
        // items) so this adjustment doesn't accidentally push it out of the
        // Low Stock report — that report should keep showing Potato Chips /
        // Cashew Nuts / Laundry Detergent as seeded.
        $restock = $products[6]; // Fresh Milk 1L
        $freshRestock = Product::find($restock->id);
        $newQty = $freshRestock->stock_quantity + 50;
        $freshRestock->stockMovements()->create([
            'type' => 'adjustment',
            'quantity' => 50,
            'quantity_after' => $newQty,
            'notes' => 'Seeded opening stock count',
            'user_id' => $admin->id,
        ]);
        $freshRestock->update(['stock_quantity' => $newQty]);

        $writeOff = Product::find($products[10]->id); // Chocolate Cake Slice — perishable
        $newQty = max($writeOff->stock_quantity - 3, 0);
        $writeOff->stockMovements()->create([
            'type' => 'adjustment',
            'quantity' => -3,
            'quantity_after' => $newQty,
            'notes' => 'Seeded damaged stock write-off',
            'user_id' => $admin->id,
        ]);
        $writeOff->update(['stock_quantity' => $newQty]);
    }
}
