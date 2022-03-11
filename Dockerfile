FROM tomcat:latest
ADD target/intro.war /usr/local/tomcat/webapps
