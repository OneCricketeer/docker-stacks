hadoop
===

Services

- Hadoop NN + DN
- Hue
- Jupyter w/ Spark

TODO: 

- Hive (Metastore)  
- Some SQL thing other than Spark
- While Jupyter or Hue notebooks work, I prefer Zeppelin 
- NiFi / Airflow


## Adding Kafka

Example: Using Kafka with Spark

Clone other repo and start Kafka

```sh
git clone git@github.com:OneCricketeer/apache-kafka-connect-docker.git
cd apache-kafka-connect-docker
docker-compose up -d zookeeper kafka
```

Link kafka to the hadoop network

```sh
docker ps | grep kafka  # copy container ID
docker network connect --alias kafka hadoop-docker_hadoop <kafka container ID>
```

(optional: verify it worked)

```sh
docker run --rm -ti --network=hadoop-spark_hadoop busybox
nc vz kafka 29092  # inside busybox container
```

open Jupyter at http://localhost:8888

Example pyspark producer code

```python
from pyspark.sql import SparkSession

scala_version = '2.12'  # TODO: Ensure this is correct
spark_version = '3.2.1'
packages = [
    f'org.apache.spark:spark-sql-kafka-0-10_{scala_version}:{spark_version}',
    'org.apache.kafka:kafka-clients:3.2.0'
]
spark = SparkSession.builder\
   .master("local")\
   .appName("kafka-example")\
   .config("spark.jars.packages", ",".join(packages))\
   .getOrCreate()

# Read all lines into a single value dataframe  with column 'value'
# TODO: Replace with real file. 
df = spark.read.text('file:///tmp/data.csv')

# TODO: Remove the file header, if it exists

# Write
df.write.format("kafka")\
  .option("kafka.bootstrap.servers", "kafka:29092")\
  .option("topic", "foobar")\
  .save()
  ```