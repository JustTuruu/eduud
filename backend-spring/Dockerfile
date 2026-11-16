# Multi-stage build: Maven-аар jar гаргаад жижиг JRE image дээр ажиллуулна.
#   docker build -t eduud-backend:local .
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
# Dependency-г тусад нь татаж layer cache ашиглана (pom өөрчлөгдөөгүй бол дахин татахгүй)
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN useradd --system --uid 10001 app
COPY --from=build /src/target/eduud-backend-spring-0.1.0.jar app.jar
USER 10001
EXPOSE 3000 3001
# Container-ийн memory limit-ийг харгалзаж heap тохируулна
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar \"$@\"", "--"]
