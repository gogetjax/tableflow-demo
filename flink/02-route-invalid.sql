-- Route rows that fail validation to orders.rejected with a reason.
-- Pure filter + projection: append-only. Note orders.raw's `customer_id` is nullable and
-- `status` is an Avro enum (read as STRING by Confluent Cloud Flink).
INSERT INTO `orders.rejected`
SELECT
  `order_id`,
  `customer_id`,
  `product_id`,
  `quantity`,
  `unit_price_cents`,
  `currency`,
  `ordered_at`,
  CAST(`status` AS STRING) AS `status`,
  `source`,
  CASE
    WHEN `customer_id` IS NULL THEN 'null_customer'
    WHEN `quantity` <= 0 THEN 'non_positive_quantity'
    WHEN `ordered_at` > CURRENT_TIMESTAMP + INTERVAL '1' DAY THEN 'future_timestamp'
  END AS `reject_reason`
FROM `orders.raw`
WHERE `customer_id` IS NULL
   OR `quantity` <= 0
   OR `ordered_at` > CURRENT_TIMESTAMP + INTERVAL '1' DAY;
