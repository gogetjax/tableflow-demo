-- Athena reads Tableflow's Iceberg table through Glue natively. Run in the
-- tableflow-demo-consumers workgroup (results bucket set on the workgroup).
-- Database = Kafka cluster id; table name per docs/09 Q3.
SELECT count(*) AS row_count, max(ordered_at) AS latest_order
FROM "lkc-q2zqngd"."orders.clean";
