{
  "AGDAforecastSEBA": {
    "ID": 103411,
    "PART_NBR": 815873,
    "PLANT_ID": "SEBA",
    "MODIFIED_BY": "SYSTEM",
    "CREATED_DATE": 1684326017000,
    "LAST_MODIFIED_DATE": 1684326017000,
    "VERSION": 0,
    "FORECAST": 1708,
    "CURRENT_ROW": 19391,
    "TOTAL_ROWS": 19471,
    "PART_QUANTITY": 114,
    "TARGET_DATE": "20240507",
    "SAP_TYPE": "LSF",
    "SAP_PERIOD_TYPE": "D",
    "SAP_VERSION": "02"
  }
}

{
  "connector.class": "io.confluent.connect.oracle.cdc.OracleCdcSourceConnector",
  "tasks.max": 2,
  "key.converter": "io.confluent.connect.avro.AvroConverter",
  "key.converter.schema.registry.url": "http://schema-registry:8081",
  "value.converter": "io.confluent.connect.avro.AvroConverter",
  "value.converter.schema.registry.url": "http://schema-registry:8081",
  "confluent.license": "",
  "confluent.topic.bootstrap.servers": "broker:9092",
  "confluent.topic.replication.factor": "1",
  "oracle.server": "oracle",
  "oracle.port": 1521,
  "oracle.sid": "XE",
  "oracle.username": "MYUSER",
  "oracle.password": "password",
  "start.from":"snapshot",
  "redo.log.topic.name": "redo-log-topic",
  "redo.log.consumer.bootstrap.servers":"broker:9092",
  "table.inclusion.regex": ".*AGDA.*",
  "table.topic.name.template": "${databaseName}.${schemaName}.${tableName}",
  "numeric.mapping": "best_fit",
  "connection.pool.max.size": 20,
  "redo.log.row.fetch.size":100000,
  "snapshot.row.fetch.size": 100000,
  "topic.creation.redo.include": "redo-log-topic",
  "topic.creation.redo.replication.factor": 1,
  "topic.creation.redo.partitions": 1,
  "topic.creation.redo.cleanup.policy": "delete",
  "topic.creation.redo.retention.ms": 1209600000,
  "topic.creation.default.replication.factor": 1,
  "topic.creation.default.partitions": 1,
  "topic.creation.default.cleanup.policy": "delete",
  "lob.topic.name.template": "${databaseName}.${schemaName}.${tableName}.${columnName}",
  "enable.large.lob.object.support":true,
  "producer.override.linger.ms": "10",
  "producer.override.batch.size": "500000"
}


CREATE STREAM AGDA_FORECAST_STREAM (
  `AGDAforecastSEBA` STRUCT< `ID` INTEGER,
   `PART_NBR` INTEGER,
    `PLANT_ID` VARCHAR,
    `MODIFIED_BY` VARCHAR,
    `CREATED_DATE` TIMESTAMP,
    `LAST_MODIFIED_DATE` TIMESTAMP,
    `VERSION` INTEGER,
    `FORECAST` INTEGER,
    `CURRENT_ROW` INTEGER,
    `TOTAL_ROWS` INTEGER,
    `PART_QUANTITY` INTEGER,
    `TARGET_DATE` VARCHAR,
    `SAP_TYPE` VARCHAR,
    `SAP_PERIOD_TYPE` VARCHAR,
    `SAP_VERSION` VARCHAR>
) WITH (
    KAFKA_TOPIC='o2d.d2p.agda.gross-demand-forecast.json.preprod',
    VALUE_FORMAT='JSON'
);


CREATE STREAM AGDA_FORECAST_STREAM_CLOB (
  `mykey` STRUCT<`table` VARCHAR, `column` VARCHAR, `primary_key` INTEGER> KEY,
  `VALUE` VARCHAR
) WITH (
  KAFKA_TOPIC = 'XE.MYUSER.AGDA.MYCLOB',
  VALUE_FORMAT = 'KAFKA',
  KEY_FORMAT = 'JSON'
);


select * from AGDA_FORECAST_STREAM 
WHERE `AGDAforecastSEBA`->`ID` = 120555
EMIT CHANGES;

PRINT 'XE.MYUSER.AGDA.MYCLOB' FROM BEGINNING;
