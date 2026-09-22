-- Sink for rows that fail validation. Not Tableflow-enabled; exists so bad rows are observable.
-- Append-only with a primary key: the PK gives the topic an Avro key schema (orders.rejected-key)
-- without switching to upsert semantics. Confluent Cloud Flink CREATE TABLE reference:
-- https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html
CREATE TABLE `orders.rejected` (
  `order_id`         STRING NOT NULL,
  `customer_id`      STRING,
  `product_id`       STRING NOT NULL,
  `quantity`         INT NOT NULL,
  `unit_price_cents` BIGINT NOT NULL,
  `currency`         STRING NOT NULL,
  `ordered_at`       TIMESTAMP_LTZ(3) NOT NULL,
  `status`           STRING NOT NULL,
  `source`           STRING NOT NULL,
  `reject_reason`    STRING NOT NULL,
  PRIMARY KEY (`order_id`) NOT ENFORCED
)
DISTRIBUTED BY HASH(`order_id`) INTO 6 BUCKETS
WITH (
  'changelog.mode'       = 'append',
  'key.format'           = 'avro-registry',
  'value.format'         = 'avro-registry',
  'value.fields-include' = 'all',
  'kafka.retention.time' = '7 day'
);
