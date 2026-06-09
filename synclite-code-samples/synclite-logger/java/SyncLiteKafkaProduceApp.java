/*
 * Copyright (c) 2024 mahendra.chavan@synclite.io, all rights reserved.
 *
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied.  See the License for the specific language governing permissions and limitations
 * under the License.
 *
 */
import java.nio.file.Path;
import java.util.Properties;

import org.apache.kafka.clients.producer.ProducerRecord;

import io.synclite.KafkaProducer;

/**
 * KafkaProducer API sample.
 *
 * This sample shows producer-style publishing through the SyncLite KafkaProducer
 * API. The application deals with records and topics directly instead of
 * modeling messages as rows through a SQL surface.
 *
 * That makes it the API-oriented counterpart to the SQL-based streaming samples.
 * Use this path when the application is already structured around Kafka producer
 * semantics and you want SyncLite persistence behind that API.
 */
public class SyncLiteKafkaProduceApp {

    public static void main(String[] args) throws Exception {
        Properties props = new Properties();
        props.put("bootstrap.servers", "localhost:9092");
        props.put("device-path", Path.of("sample_kafka_device.db").toAbsolutePath().toString());
        props.put("device-type", "STREAMING");

        try (KafkaProducer producer = new KafkaProducer(props)) {
            producer.send(new ProducerRecord<>("orders", "order-1", "{\"status\":\"created\"}"));
            producer.send(new ProducerRecord<>("orders", "order-2", "{\"status\":\"confirmed\"}"));
            producer.flush();
        }
    }
}
