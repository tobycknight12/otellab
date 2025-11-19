# Stage 1: Build the application with Maven
FROM maven:3.8.5-openjdk-17 AS build
WORKDIR /src
# Copy the pom file and the source code
COPY pom.xml .
COPY simplespring.java ./src/main/java/simplespring.java
# Build the application and create the executable JAR
RUN mvn package -DskipTests

# Stage 2: Create the final, smaller runtime image
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# Copy the built JAR from the 'build' stage
COPY --from=build /src/target/*.jar app.jar
# Expose the port Spring Boot runs on (default 8080)
EXPOSE 8080
# The command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]