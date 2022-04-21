FROM swr.cn-north-5.myhuaweicloud.com/codeci/tomcat:10
ADD target/intro.war /usr/local/tomcat/webapps
