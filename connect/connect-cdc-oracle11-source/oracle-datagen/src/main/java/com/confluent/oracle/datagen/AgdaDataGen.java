package com.confluent.oracle.datagen;

import com.beust.jcommander.JCommander;
import com.confluent.oracle.datagen.connection.OracleDatabase;
import com.confluent.oracle.datagen.domain.InputParams;
import oracle.ucp.UniversalConnectionPoolException;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.sql.*;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.List;
import java.util.TimerTask;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;
import com.github.javafaker.Faker;
import static java.time.Duration.*;

public class AgdaDataGen {
    private static final Logger log = LogManager.getLogger(AgdaDataGen.class);
    private static final AtomicInteger numTransactions = new AtomicInteger();

    public static void main(String[] args) throws IOException, UniversalConnectionPoolException, InterruptedException, ExecutionException {

        InputParams params = new InputParams();
        JCommander jc = new JCommander();
        jc.setProgramName("java -jar <jarFile>");
        jc.addObject(params);
        try {
            jc.parse(args);
            if (params.isHelp()) {
                jc.usage();
                return;
            }
        } catch (Exception e) {
            System.out.println("\n"+e.getMessage() +" \n\n");
            jc.usage();
            return;
        }

        /*

    'Type1',
    'PeriodType1',
    'Version1',
    'Some text',
        * */


        int durationTimeMin = params.getdurationTimeMin();
        ExecutorService invokeTxnPool = Executors.newFixedThreadPool(params.getPoolSize());
        ExecutorService heavyTxnPool = Executors.newSingleThreadExecutor();
        AtomicBoolean finishExecution = new AtomicBoolean();
        OracleDatabase database = new OracleDatabase(params);
        Faker faker = new Faker();
        long startTime = new Date().getTime();
        long endTime = startTime + (durationTimeMin*60*1000) + (10*1000);
        log.info("startTime::{}", new Date(startTime));
        log.info("endTime::{}", new Date(endTime));
        for (int i = 0; i < params.getPoolSize() - 1; i++) {
            invokeTxnPool.execute(() -> {
                try (Connection connection = database.getConnection()) {
                    while (!finishExecution.get()) {
                        connection.setAutoCommit(false);
                        java.sql.Clob clobData = connection.createClob();
                        clobData.setString(1, String.join(" ",faker.lorem().words(4000)));

                        PreparedStatement stmt = connection.prepareStatement("INSERT INTO AGDA ( PART_NBR, PLANT_ID, MODIFIED_BY, CREATED_DATE, LAST_MODIFIED_DATE, VERSION, FORECAST, CURRENT_ROW, TOTAL_ROWS, PART_QUANTITY, TARGET_DATE, SAP_TYPE, SAP_PERIOD_TYPE, SAP_VERSION, MYCLOB) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
                        stmt.setInt(1, faker.number().randomDigitNotZero()); //PART_NBR
                        stmt.setString(2, faker.company().name()); // PLANT_ID
                        stmt.setString(3, faker.name().fullName()); //MODIFIED_BY
                        stmt.setTimestamp(4, Timestamp.from(faker.date().past(1,TimeUnit.DAYS).toInstant())); // CREATED_DATE
                        stmt.setTimestamp(5, Timestamp.from(faker.date().past(1,TimeUnit.DAYS).toInstant())); //LAST_MODIFIED_DATE
                        stmt.setInt(6,1); //version
                        stmt.setInt(7,faker.number().numberBetween(50,500)); //FORECAST
                        stmt.setInt(8,faker.number().numberBetween(50,500)); //CURRENT_ROW
                        stmt.setInt(9,faker.number().numberBetween(500,1500)); //TOTAL_ROWS
                        stmt.setInt(10,faker.number().numberBetween(1,100)); //PART_QUANTITY

                        LocalDate currentDate = LocalDate.now();
                        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyyMMdd");
                        String formattedDate = currentDate.format(formatter);

                        stmt.setString(11,formattedDate); //Targetdate
                        stmt.setString(12,"Type1"); //SAP_TYPE
                        stmt.setString(13,"PeriodType1"); //SAP_PERIOD_TYPE
                        stmt.setString(14,"Version1"); //SAP_Version
                        stmt.setClob(15,clobData); //clob

                        stmt.executeUpdate();
                        connection.commit();
                        stmt.close();

                        int row =  numTransactions.getAndIncrement();
                        log.info("processed row " + row);
                        stmt.close();
                    }
                } catch (SQLException sqlException) {
                    sqlException.printStackTrace();
                }
            });
        }

        while (true) {
            if (new Date().getTime() > endTime) {
                finishExecution.set(true);
                break;
            }
        }
        log.info("End load test at: {}",new Date());
        log.info("Num Transactions clocked:{}", numTransactions.get());
        database.recycleConnections();
        System.exit(0);
    }
}
