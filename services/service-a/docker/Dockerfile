# ---- build stage ------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /workspace

# Erst die Maven-Metadaten, damit Docker Dependencies cachen kann
COPY app/pom.xml app/pom.xml
RUN mvn -f app/pom.xml -q -DskipTests dependency:go-offline

# Dann Source-Code kopieren und bauen
COPY app/src app/src
RUN mvn -f app/pom.xml -q -DskipTests package


# ---- runtime stage ----------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# optional: nicht als root laufen
RUN addgroup -S app && adduser -S app -G app
USER app

# Jar aus dem Build-Stage kopieren (Spring Boot Maven Plugin erzeugt target/*.jar)
COPY --from=build /workspace/app/target/*.jar /app/app.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]
