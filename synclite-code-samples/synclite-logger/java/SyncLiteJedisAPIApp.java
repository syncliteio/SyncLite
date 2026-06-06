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
import java.util.Map;

import io.synclite.logger.Jedis;

/**
 * Jedis API sample.
 *
 * This sample shows Redis-style key/value usage backed by a SyncLite store
 * device. It is useful when the application already speaks in Jedis terms and
 * wants SyncLite-managed persistence under that API.
 *
 * The sample uses the managed builder mode added to Jedis, so the underlying
 * store initialize, open, and close lifecycle is handled by Jedis rather than by
 * the application.
 */
public class SyncLiteJedisAPIApp {

    public static void main(String[] args) throws Exception {
        Path dbPath = Path.of("sample_jedis_store.db");

        // Managed mode: Jedis handles SQLiteStore initialize/open/close internally.
        try (Jedis jedis = Jedis.builder(dbPath, Path.of("synclite.conf"), "jedis-sample")
                .host("localhost")
                .port(6379)
                .build()) {
            // Clear keys used by this sample so repeated runs stay deterministic.
            jedis.del(
                "sample:user:1:name",
                "sample:user:2:name",
                "sample:user:3:name",
                "sample:session:42",
                "sample:queue",
                "sample:tags",
                "sample:leaderboard",
                "sample:tmp"
            );

            // 1) Strings
            jedis.set("sample:user:1:name", "Alice");
            jedis.mset("sample:user:2:name", "Bob", "sample:user:3:name", "Carol");
            System.out.println("GET sample:user:1:name = " + jedis.get("sample:user:1:name"));
            System.out.println("MGET users = " + jedis.mget("sample:user:2:name", "sample:user:3:name"));

            // 2) Hashes
            jedis.hset("sample:session:42", Map.of(
                "token", "abc123",
                "status", "active",
                "region", "us-east"
            ));
            System.out.println("HGET token = " + jedis.hget("sample:session:42", "token"));
            System.out.println("HGETALL session = " + jedis.hgetAll("sample:session:42"));
            jedis.hdel("sample:session:42", "region");

            // 3) Lists
            jedis.rpush("sample:queue", "job-1", "job-2");
            jedis.lpush("sample:queue", "job-0");
            System.out.println("LRANGE queue = " + jedis.lrange("sample:queue", 0, -1));
            System.out.println("LPOP queue = " + jedis.lpop("sample:queue"));
            System.out.println("RPOP queue = " + jedis.rpop("sample:queue"));

            // 4) Sets
            jedis.sadd("sample:tags", "etl", "cdc", "ops");
            jedis.srem("sample:tags", "ops");
            System.out.println("SMEMBERS tags = " + jedis.smembers("sample:tags"));

            // 5) Sorted sets
            jedis.zadd("sample:leaderboard", Map.of(
                "alice", 9.5,
                "bob", 8.0,
                "carol", 9.8
            ));
            jedis.zincrby("sample:leaderboard", 0.3, "bob");
            System.out.println("ZRANGE leaderboard = " + jedis.zrange("sample:leaderboard", 0, -1));
            System.out.println("ZSCORE bob = " + jedis.zscore("sample:leaderboard", "bob"));

            // 6) Key lifecycle
            jedis.set("sample:tmp", "ephemeral");
            jedis.expire("sample:tmp", 60);
            System.out.println("TTL sample:tmp = " + jedis.ttl("sample:tmp"));
            jedis.rename("sample:tmp", "sample:tmp:renamed");
            jedis.persist("sample:tmp:renamed");
            jedis.del("sample:tmp:renamed");
        }
    }
}