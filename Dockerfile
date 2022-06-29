FROM swr.cn-north-4.myhuaweicloud.com/huaweiOfficialDetail/tomcat:latest
ADD target/intro.war /usr/local/tomcat/webapps
