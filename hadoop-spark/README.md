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
docker network connect --alias kafka hadoop-spark_hadoop apache-kafka-connect-docker_kafka_1
```

(optional: verify network connected)

```sh
docker run --rm -ti --network=hadoop-spark_hadoop busybox
nc vz kafka 29092  # inside busybox container
```

open Jupyter at http://localhost:8888

Navigate to `work/kafka-sql` notebook
