
FROM tomcat:11.0.27-jdk21-temurin

# Copy the generated WAR into Tomcat
# Name it wwp.war so the application URL is /wwp/
COPY target/*.war /usr/local/tomcat/webapps/wwp.war

EXPOSE 8080
