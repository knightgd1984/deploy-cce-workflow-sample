FROM swr.cn-north-4.myhuaweicloud.com/codeci/tomcat:10
ADD target/intro.war /usr/local/tomcat/webapps
