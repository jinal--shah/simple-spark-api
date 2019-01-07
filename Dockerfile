FROM openjdk:8-jdk-alpine

ENV JAVA_OPTS="-Xmx100m -Xms100m" \
    JAR_PATH="/simple-spark-api.jar"

COPY simple-spark-api-*-jar-with-dependencies.jar ${JAR_PATH}
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod a+x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
