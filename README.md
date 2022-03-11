当前workflow实现功能如下
1、打包maven项目
2、将打包出来的war包上传到OBS
3、基于tomcat制作docker镜像，并上传到SWR
4、对端服务器上启动容器
5、检查服务启动后,web页面是否能正常访问