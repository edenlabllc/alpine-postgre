# alpine-postgre

PostgreSQL Docker container based on Alpine Linux and with the same API as [official container has](https://hub.docker.com/_/postgres/).

Whats different? 

  1. Added `POSTGRES_LOG_STATEMENTS` environment variable that helps with settings custom verbosity for statements log.
  2. Added `REPLICATOR_USER` (default: `phhoard`) and `REPLICATOR_PASSWORD` environment variables that will allow replication connections to a running container. (By default PostgreSQL `all` statement does not include `replication` in `pg_hba.conf`.)
  3. Improved entrypoint script to support backups from restored PostgeSQL data directory.

## How to restore from backup?

Place your restored `PGDATA` to `${PGDATA}/../restored_data` (by default: `var/lib/postgresql/restored_data`) and restart the container. During restart it will:

  1. Move current PGDATA to `${PGDATA}/../corrupted_data`. (You will need to remove it manually later.)
  2. Move files from `restored_data` to `$PGDATA`.
  3. Remove `restored_data` directory.

# How to create a logical replication?
All necessary documentation can be found on [pglogical official webpage](https://www.2ndquadrant.com/en/resources/pglogical/pglogical-docs/).
## Requirements
1. The pglogical extension must be installed on both provider and subscriber. You must CREATE EXTENSION pglogical on both.
2. Tables on the provider and subscriber must have the same names and be in the same schema. 
3. Tables on the provider and subscriber must have the same columns, with the same data types in each column. CHECK constraints, NOT NULL constraints, etc must be the same or weaker (more permissive) on the subscriber than the provider.

#### There are 4 provider databases: 
- `PRM` 
- `MPI` 
- `OPS` 
- `UADDRESSES` 
#### Subscriber database: 
- `REPORT`
## How to Configure providers databases?
#### 1. To configure PRM provider database -  execute the following sql scripts:
 - Drop node if necessary:
```
SELECT pglogical.drop_node('provider_prm');
```
- Create pglogical providers node:
```
SELECT pglogical.create_node( node_name := 'provider_prm', dsn := 'host=db-svc.prm.svc.cluster.local port=5432  dbname=prm user=databaseuser password=databasepassword');
```
 - Add tables to replication set:
 ```
SELECT pglogical.replication_set_add_table('default' , 'divisions' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'employees' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'employee_doctors' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'medical_service_providers' ,   'true') ;
SELECT pglogical.replication_set_add_table('default' , 'parties' ,   'true' , columns := '{id}');
SELECT pglogical.replication_set_add_table('default' , 'party_users' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'legal_entities' ,   'true' , columns :=
'{id,name,short_name,public_name,type,edrpou,addresses,phones,email,inserted_at,inserted_by,updated_at,updated_by,is_active,kveds,status,owner_property_type,legal_form,created_by_mis_client_id,nhs_verified,mis_verified}');
``` 
#### 2.Configure UADDRESSES provider database -  execute the following sql scripts:
- Drop node if necessary:
```
SELECT pglogical.drop_node('provider-uaddresses');
```
- Create pglogical providers node:
```
SELECT pglogical.create_node( node_name := 'provider-uaddresses', dsn := 'host=db-svc.prm.svc.cluster.local port=5432  dbname=uaddresses user=databaseuser password=databasepassword');
```
 - Add tables to replication set:
```
SELECT pglogical.replication_set_add_table('default' , 'regions' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'districts' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'settlements' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'streets' ,   'true');
SELECT pglogical.replication_set_add_table('default' , 'streets_aliases');
``` 
#### 3.Configure MPI provider database -  execute the following sql scripts:
- Drop node if necessary:
```
SELECT pglogical.drop_node('provider_mpi');
```
- Create pglogical providers node:
```
SELECT pglogical.create_node( node_name := 'provider_mpi', dsn := 'host=db-svc.mpi.svc.cluster.local port=5432  dbname=mpi user=databaseuser password=databasepassword');
```
- Add tables to replication set:
```
SELECT pglogical.replication_set_add_table('default' , 'persons' ,   'true' , columns :=
'{id,birth_date,death_date,addresses,inserted_at,updated_at}');
```
#### 4.Configure OPS provider database -  execute the following sql scripts:
- Drop node if necessary:
```
SELECT pglogical.drop_node('provider_ops');
```
- Create pglogical providers node:
```
SELECT pglogical.create_node(node_name := 'provider_ops',dsn := 'host=db-svc.ops.svc.cluster.local port=5432  dbname=ops user=databaseuser password=databasepassword');
```
- Add tables to replication set:
```
SELECT pglogical.replication_set_add_table('default' , 'declarations' ,   'true') ;
SELECT pglogical.replication_set_add_table('default' , 'declarations_status_hstr' ,   'true') ;
```
### 5. Configure REPORT subscriber database:
- Drop node if necessary:
```
SELECT pglogical.drop_node('subscriber')
```
- Create pglogical subscriber node:
```
SELECT pglogical.create_node(
    node_name := 'subscriber',
    dsn := 'host=db-svc.reports.svc.cluster.local port=5432  dbname=report user=databaseuser password=databasepassword');
```
- Create subscribtions:
```
SELECT pglogical.create_subscription(
    subscription_name := 'subscription_mpi',
    provider_dsn := 'host=db-svc.mpi.svc.cluster.local  port=5432 dbname=mpi user=databaseuser password=databasepassword');


SELECT pglogical.create_subscription(
    subscription_name := 'subscription_prm',
    provider_dsn := 'host=db-svc.prm.svc.cluster.local  port=5432 dbname=prm user=databaseuser password=databasepassword');

SELECT pglogical.create_subscription(
    subscription_name := 'subscription_uaddresses',
    provider_dsn := 'host=db-svc.uaddresses.svc.cluster.local  port=5432 dbname=uaddresses user=databaseuser password=databasepassword');

SELECT pglogical.create_subscription(
    subscription_name := 'subscription_ops',
    provider_dsn := 'host=db-svc.ops.svc.cluster.local  port=5432 dbname=ops user=databaseuser password=databasepassword');
```
## Useful scripts execute on subcriber
- Check replication status:
```
SELECT *  FROM pglogical.show_subscription_status();
```
- Check replication table status:
```
SELECT * FROM pglogical.show_subscription_table('subscription_prm','divisions') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','employees') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','employee_doctors') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','legal_entities') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','medical_service_providers') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','parties') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_prm','party_users') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_uaddresses','regions') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_uaddresses','districts') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_uaddresses','settlements') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_uaddresses','streets') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_uaddresses','streets_aliases') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_ops','declarations') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_ops','declarations_status_hstr') UNION
SELECT * FROM pglogical.show_subscription_table('subscription_mpi','persons');
```
- resynchronize tables if necessary. The tables will be truncated!
```
#-------------------------------subscription_prm----------------------------------
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'divisions');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'employees');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'employee_doctors');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'legal_entities');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'medical_service_providers');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'parties');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_prm' , 'party_users');

#-------------------------------subscription_uaddresses----------------------------------
SELECT pglogical.alter_subscription_resynchronize_table('subscription_uaddresses' , 'regions');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_uaddresses' , 'districts');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_uaddresses' , 'settlements');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_uaddresses' , 'streets');
SELECT pglogical.alter_subscription_resynchronize_table('subscription_uaddresses' , 'streets_aliases');
```
