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
        comments VARCHAR(4000),
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

insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (1, 'Rica', 'Blaisdell', 'rblaisdell0@rambler.ru', 'Female', 'bronze', 'Universal optimal hierarchy');
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (2, 'Ruthie', 'Brockherst', 'rbrockherst1@ow.ly', 'Female', 'platinum', 'Reverse-engineered tangible interface');
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (3, 'Mariejeanne', 'Cocci', 'mcocci2@techcrunch.com', 'Female', 'bronze', 'Multi-tiered bandwidth-monitored capability');
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (4, 'Hashim', 'Rumke', 'hrumke3@sohu.com', 'Male', 'platinum', 'Self-enabling 24/7 firmware');
insert into CUSTOMERS (id, first_name, last_name, email, gender, club_status, comments) values (5, 'Hansiain', 'Coda', 'hcoda4@senate.gov', 'Male', 'platinum', 'Centralized full-range approach');

create table USERS (
                           id NUMBER(10) NOT NULL PRIMARY KEY,
                           first_name VARCHAR(50),
                           last_name VARCHAR(50),
                           data CLOB,
                           create_ts timestamp DEFAULT CURRENT_TIMESTAMP,
                           update_ts timestamp
);

CREATE SEQUENCE USERS_SEQ START WITH 1;

CREATE OR REPLACE TRIGGER USERS_TRIGGER_ID
BEFORE INSERT ON USERS
FOR EACH ROW

BEGIN
  SELECT USERS_SEQ.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;
/

CREATE OR REPLACE TRIGGER USERS_TRIGGER_TS
BEFORE INSERT OR UPDATE ON USERS
REFERENCING NEW AS NEW_ROW
  FOR EACH ROW
BEGIN
  SELECT SYSDATE
        INTO :NEW_ROW.UPDATE_TS
        FROM DUAL;
END;
/

INSERT INTO USERS (id, first_name, last_name, data, create_ts, update_ts)
SELECT
    level,
    'First_Name_' || level,
    'Last_Name_' || level,
    to_clob('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'),
    CURRENT_TIMESTAMP - NUMTODSINTERVAL(DBMS_RANDOM.VALUE(1, 100), 'DAY'),
    CURRENT_TIMESTAMP - NUMTODSINTERVAL(DBMS_RANDOM.VALUE(1, 100), 'DAY')
FROM dual
CONNECT BY level <= 10;

EOF

log "Creating Oracle source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
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
               "table.inclusion.regex": ".*CUSTOMERS.*",
               "table.topic.name.template": "${databaseName}.${schemaName}.${tableName}",
               "numeric.mapping": "best_fit",
               "connection.pool.max.size": 20,
               "redo.log.row.fetch.size": 1,
               "topic.creation.redo.include": "redo-log-topic",
               "topic.creation.redo.replication.factor": 1,
               "topic.creation.redo.partitions": 1,
               "topic.creation.redo.cleanup.policy": "delete",
               "topic.creation.redo.retention.ms": 1209600000,
               "topic.creation.default.replication.factor": 1,
               "topic.creation.default.partitions": 1,
               "topic.creation.default.cleanup.policy": "delete",
               "lob.topic.name.template": "${databaseName}.${schemaName}.${tableName}.${columnName}",
               "enable.large.lob.object.support":true
          }' \
     http://localhost:8083/connectors/cdc-oracle11-source/config | jq .

log "Waiting 10s for connector to read existing data"
sleep 10

