#! /bin/bash


kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic site-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic catalog-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic stock-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic order-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic client-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic cart-snapshot-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic sms-stream-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic mail-stream-v1
kafka-topics --bootstrap-server kafka:9092 --command-config /admin.config --partitions 1 --replication-factor 1 --create --topic delivery-snapshot-v1




kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-catalog
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-site
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-cart
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-stock
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-order
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-client
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-sms
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-mail
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name api-delievry

kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name loader-site
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name loader-catalog
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name loader-stock
kafka-configs --zookeeper zookeeper:2181 --alter --add-config SCRAM-SHA-512='[password=api-secret]' --entity-type users --entity-name loader-client


kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:loader-site --producer --topic 'site-snapshot-v1'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:api-site --consumer --topic 'site-snapshot-v1' --group 'site'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:loader-catalog --producer --topic 'catalog-snapshot-v1'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:api-catalog --consumer --topic 'catalog-snapshot-v1' --group 'catalog'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:loader-stock --producer --topic 'stock-snapshot-v1'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:loader-stock --consumer --topic 'order-snapshot-v1' --group 'stock'
kafka-acls --bootstrap-server kafka:9092 --command-config /admin.config --add --allow-principal User:api-stock --consumer --topic 'stock-snapshot-v1' --group 'stock'














