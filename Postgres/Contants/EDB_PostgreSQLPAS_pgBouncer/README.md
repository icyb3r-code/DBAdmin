The error message:

```
org.postgresql.util.PSQLException: ERROR: prepared statement "S_1" already exists
```

indicates that the issue is related to prepared statements when using PgBouncer in **transaction pooling mode**.

### Cause of the Issue:

- **PgBouncer in Transaction Mode**: In this mode, each transaction gets a new backend connection. However, Hibernate (via HikariCP and the PostgreSQL JDBC driver) relies on **prepared statements** that persist across multiple transactions.
- **Prepared Statements Persistence Issue**: When a prepared statement (e.g., `"S_1"`) is created inside one transaction and reused in another, PgBouncer does not guarantee that the same backend connection will be used. This results in an error when the application tries to reuse the statement that no longer exists in the new backend session.

### Solutions:

#### **1. Disable Prepared Statements in PostgreSQL JDBC**

Since PgBouncer does not support persistent prepared statements in transaction pooling mode, you need to disable them in your PostgreSQL JDBC connection URL.

**Modify your application’s JDBC URL to disable server-side prepared statements:**

```properties
jdbc:postgresql://pgbouncer.mycompany.com:6432/DB_NAME?**prepareThreshold=0&**`**preparedStatementCacheQueries=0**`
```

or in `application.properties`:

```properties
spring.datasource.url=jdbc:postgresql://pgbouncer.mycompany.com:6432/DB_NAME?prepareThreshold=0&preparedStatementCacheQueries=
```

```bash
jdbc:postgresql://10.10.20.19:6432,10.10.20.20:6432/dbanem?prepareThreshold=0&loadBalanceHosts=true&targetServerType=primary&connectTimeout=10&socketTimeout=30&sslmode=require
```

This forces the PostgreSQL JDBC driver to use **client-side prepared statements**, avoiding the issue with PgBouncer.

---

#### **2. Use `statement_cache_size=0` in PgBouncer**

If disabling prepared statements at the JDBC level is not an option, another approach is to disable statement caching in PgBouncer.

Edit your `pgbouncer.ini` configuration file:

```
statement_cache_size = 0
```

This prevents PgBouncer from caching prepared statements across different transactions.

---

#### **3. Use `session` Pooling Mode Instead**

If your application **must use prepared statements**, consider changing the PgBouncer pooling mode from `transaction` to `session`.

In `pgbouncer.ini`:

```
pool_mode = session
```

However, this will reduce connection reuse efficiency, as each application connection will get a dedicated database connection.

---

#### **4. Use `closeIdleConnections` Setting in HikariCP**

If the issue persists, try adding this to your `application.properties`:

```properties
spring.datasource.hikari.maximumPoolSize=30
spring.datasource.hikari.minimumIdle=5
spring.datasource.hikari.idleTimeout=30000
spring.datasource.hikari.maxLifetime=1800000
spring.datasource.hikari.leakDetectionThreshold=60000
```

This ensures that idle connections do not persist stale prepared statements.

---

### **Recommended Fix**

1. **Best solution**: **Disable prepared statements** in JDBC (`prepareThreshold=0`).
2. If needed, also **set `statement_cache_size = 0` in PgBouncer**.
3. If you require prepared statements, **switch PgBouncer to session pooling mode**.

Would you like help applying these changes in your specific setup?