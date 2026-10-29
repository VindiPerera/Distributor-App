<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use App\Models\Supplier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    public function index()
    {
        // The mobile app's product picker needs the full catalog in one shot
        // (search/select while ringing up a sale), so return everything
        // instead of paginating — paginate(20) was silently hiding every
        // product past page 1 from the mobile list.
        return response()->json([
            'data' => Product::with('category', 'supplier')->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'sku' => ['nullable', 'string', 'max:100', 'unique:products,sku'],
            'item_code' => ['nullable', 'string', 'max:100'],
            'barcode' => ['nullable', 'string', 'max:100'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'supplier_id' => ['nullable', 'exists:suppliers,id'],
            'name' => ['required', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:50'],
            'selling_price' => ['required', 'numeric', 'min:0'],
            'stock_quantity' => ['nullable', 'integer', 'min:0'],
            'low_stock_alert' => ['nullable', 'integer', 'min:0'],
            'expiry_date' => ['nullable', 'date'],
            'image' => ['nullable', 'image', 'max:4096'],
        ]);

        $data['sku'] = $data['sku'] ?? $this->generateSku();
        $data['supplier_id'] = $data['supplier_id'] ?? $this->unspecifiedSupplierId();
        $data['category_id'] = $data['category_id'] ?? $this->unspecifiedCategoryId();

        if ($request->hasFile('image')) {
            $data['image_path'] = $request->file('image')->store('products', 'public');
        }
        unset($data['image']);

        return response()->json(Product::create($data), 201);
    }

    public function show(Product $product)
    {
        return $product->load('category', 'supplier');
    }

    public function update(Request $request, Product $product)
    {
        $data = $request->validate([
            'sku' => ['sometimes', 'nullable', 'string', 'max:100', 'unique:products,sku,' . $product->id],
            'item_code' => ['nullable', 'string', 'max:100'],
            'barcode' => ['nullable', 'string', 'max:100'],
            'category_id' => ['sometimes', 'exists:categories,id'],
            'supplier_id' => ['sometimes', 'nullable', 'exists:suppliers,id'],
            'name' => ['sometimes', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:50'],
            'selling_price' => ['sometimes', 'numeric', 'min:0'],
            'low_stock_alert' => ['sometimes', 'integer', 'min:0'],
            'expiry_date' => ['nullable', 'date'],
            'is_active' => ['sometimes', 'boolean'],
            'image' => ['nullable', 'image', 'max:4096'],
        ]);

        if (array_key_exists('sku', $data) && !$data['sku']) {
            $data['sku'] = $this->generateSku();
        }
        if (array_key_exists('supplier_id', $data) && !$data['supplier_id']) {
            $data['supplier_id'] = $this->unspecifiedSupplierId();
        }

        if ($request->hasFile('image')) {
            if ($product->image_path) {
                Storage::disk('public')->delete($product->image_path);
            }
            $data['image_path'] = $request->file('image')->store('products', 'public');
        }
        unset($data['image']);

        $product->update($data);

        return $product;
    }

    /**
     * Soft-delete only — the row (and its image) stays in the database so
     * past sales still resolve a real product with full details. It just
     * disappears from normal listings/pickers (the default query excludes
     * trashed products automatically).
     */
    public function destroy(Product $product)
    {
        $product->delete();

        return response()->noContent();
    }

    private function generateSku(): string
    {
        do {
            $sku = 'SKU-' . strtoupper(Str::random(8));
        } while (Product::where('sku', $sku)->exists());

        return $sku;
    }

    private function unspecifiedSupplierId(): int
    {
        return Supplier::firstOrCreate(
            ['name' => 'Unspecified'],
            ['is_active' => true],
        )->id;
    }

    private function unspecifiedCategoryId(): int
    {
        return Category::firstOrCreate(
            ['name' => 'Uncategorized'],
            ['is_active' => true],
        )->id;
    }
}
