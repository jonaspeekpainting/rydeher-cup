/**
 * Apply SQL migrations in order against POSTGRES_URL / DATABASE_URL.
 * Usage: npx tsx scripts/migrate-local.ts
 */
import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import pg from "pg";

const connectionString =
  process.env.POSTGRES_URL ??
  process.env.RYDEHER_POSTGRES_URL ??
  process.env.DATABASE_URL ??
  "postgres://rydeher:rydeher@127.0.0.1:5432/rydeher";

async function main() {
  const migrationsDir = join(__dirname, "..", "migrations");
  const files = readdirSync(migrationsDir)
    .filter((f) => /^\d+_.*\.sql$/.test(f) && !f.includes(".example."))
    .sort();

  const client = new pg.Client({ connectionString });
  await client.connect();

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    for (const file of files) {
      const already = await client.query(
        `SELECT 1 FROM schema_migrations WHERE filename = $1`,
        [file],
      );
      if (already.rowCount) {
        console.log(`skip  ${file}`);
        continue;
      }

      const sql = readFileSync(join(migrationsDir, file), "utf8");
      console.log(`apply ${file}`);
      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query(
          `INSERT INTO schema_migrations (filename) VALUES ($1)`,
          [file],
        );
        await client.query("COMMIT");
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }

    console.log("Migrations complete.");
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
