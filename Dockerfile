FROM registry-cbu.huawei.com/roma-compose/tomcat:9.0.39-jdk11
ADD target/intro.war /usr/local/tomcat/webapps
