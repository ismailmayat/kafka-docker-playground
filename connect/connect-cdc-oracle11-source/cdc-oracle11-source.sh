#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

if [ ! -z "$SQL_DATAGEN" ]
then
     log "🌪️ SQL_DATAGEN is set, make sure to increase redo.log.row.fetch.size, have a look at https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-cdc-oracle19-source/README.md#note-on-redologrowfetchsize"
     for component in oracle-datagen
     do
     set +e
     log "🏗 Building jar for ${component}"
     docker run -i --rm -e KAFKA_CLIENT_TAG=$KAFKA_CLIENT_TAG -e TAG=$TAG_BASE -v "${DIR}/${component}":/usr/src/mymaven -v "$HOME/.m2":/root/.m2 -v "$PWD/../../scripts/settings.xml:/tmp/settings.xml" -v "${DIR}/${component}/target:/usr/src/mymaven/target" -w /usr/src/mymaven maven:3.6.1-jdk-11 mvn -s /tmp/settings.xml -Dkafka.tag=$TAG -Dkafka.client.tag=$KAFKA_CLIENT_TAG package > /tmp/result.log 2>&1
     if [ $? != 0 ]
     then
          logerror "ERROR: failed to build java component "
          tail -500 /tmp/result.log
          exit 1
     fi
     set -e
     done
else
     log "🛑 SQL_DATAGEN is not set"
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

# Verify Oracle DB has started within MAX_WAIT seconds
MAX_WAIT=900
CUR_WAIT=0
log "⌛ Waiting up to $MAX_WAIT seconds for Oracle DB to start"
docker container logs oracle > /tmp/out.txt 2>&1
while [[ ! $(cat /tmp/out.txt) =~ "Grant succeeded." ]]; do
sleep 10
docker container logs oracle > /tmp/out.txt 2>&1
CUR_WAIT=$(( CUR_WAIT+10 ))
if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
     logerror "ERROR: The logs in oracle container do not show 'Grant succeeded.' after $MAX_WAIT seconds. Please troubleshoot with 'docker container ps' and 'docker container logs'.\n"
     exit 1
fi
done
log "Oracle DB has started!"

log "create table"
docker exec -i oracle bash -c "ORACLE_SID=XE;export ORACLE_SID;export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe;/u01/app/oracle/product/11.2.0/xe/bin/sqlplus MYUSER/password@//localhost:1521/XE" << EOF
create table CUSTOMERS (
        id NUMBER(10) NOT NULL PRIMARY KEY,
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        email VARCHAR(50),
        gender VARCHAR(50),
        club_status VARCHAR(20),
        comments CLOB,
        create_ts timestamp DEFAULT CURRENT_TIMESTAMP,
        update_ts timestamp
);

CREATE SEQUENCE CUSTOMERS_SEQ START WITH 1;

CREATE OR REPLACE TRIGGER CUSTOMERS_TRIGGER_ID
BEFORE INSERT ON CUSTOMERS
FOR EACH ROW

BEGIN
  SELECT CUSTOMERS_SEQ.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;
/

CREATE OR REPLACE TRIGGER CUSTOMERS_TRIGGER_TS
BEFORE INSERT OR UPDATE ON CUSTOMERS
REFERENCING NEW AS NEW_ROW
  FOR EACH ROW
BEGIN
  SELECT SYSDATE
        INTO :NEW_ROW.UPDATE_TS
        FROM DUAL;
END;
/

insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (1, 'Rica', 'Blaisdell', 'rblaisdell0@rambler.ru', 'Female', 'bronze', to_clob('Universal optimal hierarchy'));
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (2, 'Ruthie', 'Brockherst', 'rbrockherst1@ow.ly', 'Female', 'platinum', to_clob('Reverse-engineered tangible interface'));
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (3, 'Mariejeanne', 'Cocci', 'mcocci2@techcrunch.com', 'Female', 'bronze', to_clob('Multi-tiered bandwidth-monitored capability'));
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (4, 'Hashim', 'Rumke', 'hrumke3@sohu.com', 'Male', 'platinum', to_clob('Self-enabling 24/7 firmware'));
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (5, 'Hansiain', 'Coda', 'hcoda4@senate.gov', 'Male', 'platinum', to_clob('Centralized full-range approach'));

CREATE TABLE AGDA (
    ID NUMBER(10) NOT NULL PRIMARY KEY,
    PART_NBR NUMBER,
    PLANT_ID VARCHAR(50),
    MODIFIED_BY VARCHAR(50),
    CREATED_DATE timestamp,
    LAST_MODIFIED_DATE timestamp,
    VERSION NUMBER,
    FORECAST NUMBER,
    CURRENT_ROW NUMBER,
    TOTAL_ROWS NUMBER,
    PART_QUANTITY NUMBER,
    TARGET_DATE VARCHAR(50),
    SAP_TYPE VARCHAR(50),
    SAP_PERIOD_TYPE VARCHAR(50),
    SAP_VERSION VARCHAR(50),
    MYCLOB CLOB,
    update_ts timestamp
);

CREATE SEQUENCE AGDA_SEQ START WITH 1;

CREATE OR REPLACE TRIGGER AGDA_TRIGGER_ID
BEFORE INSERT ON AGDA
FOR EACH ROW

BEGIN
  SELECT AGDA_SEQ.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;
/

CREATE OR REPLACE TRIGGER AGDA_TRIGGER_TS
BEFORE INSERT OR UPDATE ON AGDA
REFERENCING NEW AS NEW_ROW
  FOR EACH ROW
BEGIN
  SELECT SYSDATE
        INTO :NEW_ROW.UPDATE_TS
        FROM DUAL;
END;
/

INSERT INTO AGDA ( ID, PART_NBR, PLANT_ID, MODIFIED_BY, CREATED_DATE, LAST_MODIFIED_DATE, VERSION, FORECAST, CURRENT_ROW, TOTAL_ROWS, PART_QUANTITY, TARGET_DATE, SAP_TYPE, SAP_PERIOD_TYPE, SAP_VERSION,MYCLOB ) VALUES ( 1, 815873, 'SEBA', 'SYSTEM', TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), 0, 1708, 19391, 19471, 114, '20240507', 'LSF', 'D', '02',to_clob('Juxtaposing ethereal intergalactic manifestations, kaleidoscopic supernovae pulsate relentlessly through the cosmic tapestry, igniting nebulous constellations amidst the boundless expanse. Multidimensional echoes resonate with sublime harmonies as shimmering celestial orbs cascade in symphonic crescendos, evoking ineffable wonder. Serendipitous stardust dances upon the celestial stage, entwining with cosmic melodies, an eternal ballet of celestial majesty. Interstellar galaxies spiral in cosmic choreography, entangling serpentine tendrils across the velvety fabric of the universe, a grand symphony of cosmic marvels. Nebulae pirouette in iridescent swirls, their resplendent hues painting the canvas of eternity, a mesmerizing tableau of astral brilliance.') );
INSERT INTO AGDA ( ID, PART_NBR, PLANT_ID, MODIFIED_BY, CREATED_DATE, LAST_MODIFIED_DATE, VERSION, FORECAST, CURRENT_ROW, TOTAL_ROWS, PART_QUANTITY, TARGET_DATE, SAP_TYPE, SAP_PERIOD_TYPE, SAP_VERSION,MYCLOB ) VALUES ( 2, 815874, 'SEBA', 'SYSTEM', TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), 0, 1708, 19391, 19471, 114, '20240507', 'LSF', 'D', '02',to_clob('Juxtaposing ethereal intergalactic manifestations, kaleidoscopic supernovae pulsate relentlessly through the cosmic tapestry, igniting nebulous constellations amidst the boundless expanse. Multidimensional echoes resonate with sublime harmonies as shimmering celestial orbs cascade in symphonic crescendos, evoking ineffable wonder. Serendipitous stardust dances upon the celestial stage, entwining with cosmic melodies, an eternal ballet of celestial majesty. Interstellar galaxies spiral in cosmic choreography, entangling serpentine tendrils across the velvety fabric of the universe, a grand symphony of cosmic marvels. Nebulae pirouette in iridescent swirls, their resplendent hues painting the canvas of eternity, a mesmerizing tableau of astral brilliance.') );
INSERT INTO AGDA ( ID, PART_NBR, PLANT_ID, MODIFIED_BY, CREATED_DATE, LAST_MODIFIED_DATE, VERSION, FORECAST, CURRENT_ROW, TOTAL_ROWS, PART_QUANTITY, TARGET_DATE, SAP_TYPE, SAP_PERIOD_TYPE, SAP_VERSION,MYCLOB ) VALUES ( 3, 815875, 'SEBA', 'SYSTEM', TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('2023-05-24 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), 0, 1708, 19391, 19471, 114, '20240507', 'LSF', 'D', '02',to_clob('Juxtaposing ethereal intergalactic manifestations, kaleidoscopic supernovae pulsate relentlessly through the cosmic tapestry, igniting nebulous constellations amidst the boundless expanse. Multidimensional echoes resonate with sublime harmonies as shimmering celestial orbs cascade in symphonic crescendos, evoking ineffable wonder. Serendipitous stardust dances upon the celestial stage, entwining with cosmic melodies, an eternal ballet of celestial majesty. Interstellar galaxies spiral in cosmic choreography, entangling serpentine tendrils across the velvety fabric of the universe, a grand symphony of cosmic marvels. Nebulae pirouette in iridescent swirls, their resplendent hues painting the canvas of eternity, a mesmerizing tableau of astral brilliance.') );
EOF

log "Creating Oracle source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
    "connector.class": "io.confluent.connect.oracle.cdc.OracleCdcSourceConnector",
    "tasks.max": 2,
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "confluent.license": "",
    "confluent.topic.bootstrap.servers": "broker:9092",
    "confluent.topic.replication.factor": "1",
    "producer.override.enable.idempotence": "true",
    "transforms": "ReplaceField, HoistField",
    "predicates": "isDEMAND_SAP_DISTRIBUTE_DATA",
    "topic.creation.groups": "redo",
    "transforms.ReplaceField.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
    "transforms.ReplaceField.predicate": "isDEMAND_SAP_DISTRIBUTE_DATA",
    "transforms.ReplaceField.blacklist": "table, scn, op_type, op_ts, current_ts, row_id, username",
    "transforms.HoistField.type": "org.apache.kafka.connect.transforms.HoistField$Value",
    "transforms.HoistField.field": "AGDAforecastSEBA",
    "transforms.HoistField.predicate": "isDEMAND_SAP_DISTRIBUTE_DATA",
    "predicates.isDEMAND_SAP_DISTRIBUTE_DATA.type": "org.apache.kafka.connect.transforms.predicates.TopicNameMatches",
    "predicates.isDEMAND_SAP_DISTRIBUTE_DATA.pattern": ".*o2d.d2p.agda.gross-demand-forecast.json.preprod*",
    "oracle.server": "oracle",
    "oracle.port": 1521,
    "oracle.sid": "XE",
    "oracle.username": "MYUSER",
    "oracle.password": "password",
    "start.from": "snapshot",
    "redo.log.topic.name": "o2d.d2p.agda.gross-demand-forecast.redo.json.preprod01",
    "redo.log.corruption.topic": "o2d.d2p.agda.gross-demand-forecast.corrupt.json.preprod01",
    "redo.log.consumer.bootstrap.servers": "broker:9092",
    "table.inclusion.regex": ".*AGDA.*",
    "table.topic.name.template": "o2d.d2p.agda.gross-demand-forecast.json.preprod",
    "numeric.mapping": "best_fit",
    "behavior.on.dictionary.mismatch": "log",
    "behavior.on.unparsable.statement": "log",
    "oracle.date.mapping": "timestamp",
    "connection.pool.max.size": 20,
    "redo.log.row.fetch.size": 100000,
    "snapshot.row.fetch.size": 100000,
    "topic.creation.redo.include": "o2d.d2p.agda.gross-demand-forecast.redo.json.preprod01",
    "topic.creation.redo.replication.factor": 1,
    "topic.creation.redo.partitions": 1,
    "topic.creation.redo.cleanup.policy": "delete",
    "_redo.log.consumer.fetch.min.bytes": "4",
    "heartbeat.interval.ms": "86400000",
    "topic.creation.redo.retention.ms": 1209600000,
    "topic.creation.default.replication.factor": 1,
    "topic.creation.default.partitions": 1,
    "topic.creation.default.cleanup.policy": "delete",
    "lob.topic.name.template": "${databaseName}.${schemaName}.${tableName}.${columnName}",
    "enable.large.lob.object.support": true,
    "producer.override.linger.ms": "10",
    "producer.override.batch.size": "500000",
    "value.converter.schemas.enable": "false"
}' \
     http://localhost:8083/connectors/cdc-oracle11-source/config | jq .

log "Waiting 10s for connector to read existing data"
sleep 10


if [ ! -z "$SQL_DATAGEN" ]
then
     DURATION=10
     log "Injecting data for $DURATION minutes"
     docker exec -d sql-datagen bash -c "java ${JAVA_OPTS} -jar sql-datagen-1.0-SNAPSHOT-jar-with-dependencies.jar --host oracle --username MYUSER --password password --sidOrServerName XE --sidOrServerNameVal ORCLCDB --maxPoolSize 10 --durationTimeMin $DURATION"
                                         
fi