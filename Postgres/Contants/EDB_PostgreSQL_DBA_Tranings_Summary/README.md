
# EDB PostgreSQL Training Summary

## PostgreSQL Performance Tuning

### Parameter Tuning Part 1

#### Overview 

| Parameter      | Value         | Extensions                 |
| -------------- | ------------- | -------------------------- |
| shared_buffers | %25-40 of RAM | pg_buffercache, pg_prewarm |
| work_mem       | 12            |                            |
#### **Shared Buffer** 

`Shared_buffers`: It is a parameter determines how much memory is dedicated to the server for caching data.

Below table shows the some key features of shared Buffer and OS cache:

| Shared Buffer | Shared Buffer                                           | OS Cache                                         |
| ------------- | ------------------------------------------------------- | ------------------------------------------------ |
| Algorithm     | Clock Sweep                                             | LRU (Least Recent Used)                          |
| Managed By    | PostgreSQL Internal                                     | OS Kernel                                        |
| Memory pct    | 25% - 40% of RAM                                        | OS kernel Auto Manage                            |
| How it works  | empty buffer pages, pin buffer pages dirty buffer pages | Spread the write operation across a span of time |
| Default Value | 128 MB, must be adjusted                                | NA                                               |
##### Check Shared_Buffers

How I can set the Shared_buffers:

```bash
show shared_buffers;
```

##### Update `shared_buffers` in `postgresql.conf`

Adjust this parameter in `postgresql.conf` and restart the service:

```bash
shared_buffers = 4GB
```

A good rule of thumb:

- **Small systems (<=2GB RAM):** `shared_buffers = 20-25% of total RAM`
- **Larger systems (>2GB RAM):** `shared_buffers = 25-40% of total RAM`
- **EnterpriseDB recommendation:** `shared_buffers = 15-40% of total RAM` (especially for high-availability setups)

##### Additional Considerations

- `shared_buffers` works best when `work_mem`, `effective_cache_size`, and `maintenance_work_mem` are properly tuned.

- Ensure the kernel allows allocating enough shared memory (`sysctl -w kernel.shmmax=<size>`).


##### Check if table is reading from Buffers

```bash
app_db1=> explain(analyze,buffers) select * from t1;
                                           QUERY PLAN
------------------------------------------------------------------------------------------------
 Seq Scan on t1  (cost=0.00..32.60 rows=2260 width=8) (actual time=0.005..0.005 rows=5 loops=1)
   Buffers: shared hit=1
 Planning:
   Buffers: shared hit=19 #### here means it reading from buffers
 Planning Time: 0.176 ms
 Execution Time: 0.013 ms
(6 rows)

app_db1=>
```

### PG_BUFFERCACHE EXTENSION

The pg_buffercache module provides a means for examining what's happening in the shared buffer cache in real time.

 use is restricted to superusers and roles with privileges of the pg_monitor role. Access may be granted to others using GRANT.

**Test Cases:**

**How to install** **pg_buffercache** **: (Linux user please install** **contrib** **module)**

```sql
psql
\dx
Create extension pg_buffercache;
```

**Check database** **buffercache** **for all cache blocks in each database:**

```sql
SELECT CASE WHEN c.reldatabase IS NULL THEN ''
WHEN c.reldatabase = 0 THEN ''
ELSE d.datname
END AS database,
count(*) AS cached_blocks
FROM  pg_buffercache AS c
LEFT JOIN pg_database AS d
	ON c.reldatabase = d.oid
GROUP BY d.datname, c.reldatabase
ORDER BY d.datname, c.reldatabase;
```

**Check how many blocks are empty/dirty/clean:**

```sql
SELECT buffer_status, sum(count) AS count

  FROM (SELECT CASE isdirty

                 WHEN true THEN 'dirty'

                 WHEN false THEN 'clean'

                 ELSE 'empty'

               END AS buffer_status,

               count(*) AS count

          FROM pg_buffercache

          GROUP BY buffer_status

        UNION ALL

          SELECT * FROM (VALUES ('dirty', 0), ('clean', 0), ('empty', 0)) AS tab2 (buffer_status,count)) tab1

  GROUP BY buffer_status;
```

**Issue Checkpoint:** (Run the above query again and check how many pages are dirty)

```sql
Checkpoint;
```

**In the current database** **how** **many table are cache and how many buffer used.**

```sql
SELECT n.nspname, c.relname, count(*) AS buffers

             FROM pg_buffercache b JOIN pg_class c

             ON b.relfilenode = pg_relation_filenode(c.oid) AND

                b.reldatabase IN (0, (SELECT oid FROM pg_database

                                      WHERE datname = current_database()))

             JOIN pg_namespace n ON n.oid = c.relnamespace

             GROUP BY n.nspname, c.relname

             ORDER BY 3 DESC

             LIMIT 10;
```

**Inspect Individual table in buffer cache.**

```sql
SELECT * FROM pg_buffercache WHERE relfilenode = pg_relation_filenode('pgbench_history');
```

**Inspect buffer cache for tables and indexes which are cache:**

```sql
SELECT c.relname, c.relkind, count(*)

       FROM   pg_database AS a, pg_buffercache AS b, pg_class AS c

       WHERE  c.relfilenode = b.relfilenode

              AND b.reldatabase = a.oid 

              AND c.oid >= 16384

              AND a.datname = 'postgres'

       GROUP BY 1, 2

       ORDER BY 3 DESC, 1;
```


#### WORK_MEM

The `work_mem` parameter in PostgreSQL controls the amount of memory allocated for internal operations such as sorting, hashing, and materialization within a single SQL query before using temporary disk storage. Proper tuning of `work_mem` helps optimize query performance by reducing disk I/O, which can significantly slow down operations.

You can Set the `work_mem` parameter per session or system wide:

```json
psql > SET WORK_MEM TO '128MB';
-- or 
psql > SET work_mem = '128MB';

-- system wide 
vim postgresql.conf 
work_mem = 128MB
```

**Recommended `work_mem` Values for 128GB RAM**

| Workload Type             | Estimated Concurrent Queries | Suggested `work_mem` |
| ------------------------- | ---------------------------- | -------------------- |
| OLTP (many small queries) | 500+                         | 64MB - 128MB         |
| Mixed workload            | 200-300                      | 128MB - 256MB        |
| OLAP (complex reporting)  | <100                         | 512MB - 1GB+         |

**Memory Paarameters:-**

- shared_buffer -- store data in memory fetch from OS cache default 128 MB

- work_mem -- sort join hashing merging operation default value is `4MB`

- maintenance_work_mem -- maximum amount of memory to be used by maintenance operations (vacuum, create index, alter table add foreign key) default value 64MB.

- autovacuum_work_mem --  specifies the maximum amount of memory to be used by each autovacuum worker process default value `-1` if this parameter is not enabled the maintenance_work_mem will be used.

**Connections Parameters:-**

- max_connections -- the maximum number of concurrent connections to the database server default value is `100` connections, if these connection reach the maximum buffer the application will through  "system out of memory" error. to test the connection we can use `pgbench` command and the command will be as follows `pgbench -c 100 -j 2 -C -T 600 pgtest` -s scale factor -c number of client -j number of threads -T duratio of test 10 minutes

- idle_session_timeout -- terminate any session that has been idle -- session level 

- idle_in_transaction_session_timeout :- Terminate any session that has been idle within an open transaction for longer that the specified amount of time.

- tcp_keepalives_idle:- specifies the number of seconds of inactivity after which a keepalive message will be sent to the client by the postgresQL 

- tcp_keepalives_interval:- this is the number of seconds after which the tcp keepalive message will be re transmitted if there is no acknowledgment from the client 

- tcp_keepalives_count:- this is the number of keepalive messages that can be lost before the client connection is considered as "dead". and terminated.

- client_connection_check_internal:- detect whether the connection to the client has gone away or not.

- authentication_timeout: if a would-be client has not completed the authentication protocol in this much time the server closes the connection.



```sql
alter user app_user SET idle_session_timeout='5min';
ALTER USER app_user SET idle_in_transaction_session_timeout='5s';

```


```sql
-- list user connected to database 
select usename as username from pg_stat_activity where usename !='' order by usename;

-- list number of 
select usename as username, count(*) as Concurrent_stataements from pg_stat_activity where state = 'active' Group by usename;

-- list 
select datname, numbackends from pg_stat_database;

-- list activities on specific database 
select * from pg_stat_activity where datname = 'edb';

```



