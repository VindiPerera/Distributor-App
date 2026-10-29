<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Orders placed by sales reps through the mobile app land here as
     * 'pending' until the back office confirms (completes) or cancels them.
     * Counter sales recorded directly in the admin panel still default to
     * 'completed' immediately, same as before.
     */
    public function up(): void
    {
        DB::statement("ALTER TABLE sales MODIFY status ENUM('pending', 'completed', 'cancelled') NOT NULL DEFAULT 'completed'");
    }

    public function down(): void
    {
        DB::statement("UPDATE sales SET status = 'completed' WHERE status = 'pending'");
        DB::statement("ALTER TABLE sales MODIFY status ENUM('completed', 'cancelled') NOT NULL DEFAULT 'completed'");
    }
};
