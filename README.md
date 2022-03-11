一、当前workflow实现功能如下
  1、打包maven项目
  2、将打包出来的war包上传到OBS
  3、基于tomcat制作docker镜像，并上传到SWR
  4、对端服务器上启动容器
  5、检查服务启动后,web页面是否能正常访问

二、运行该项目，需要提前在华为云上开通如下服务
	1、OBS服务，并创建桶
	2、SWR服务，并创建组织
	3、准备一台ECS虚机安装Docker，或者一台已经安装好docker的CCE节点，修改防火墙策略，开通8080端口
三、需要准备如下数据
	1、生成AK/SK
	2、生成swr的长期登录指令
四、需要提前添加如下Actions secrets
1、CCE_PASSWORD    --CCE节点的密码
2、HUAWEI_AK             --账号的AK
3、HUAWEI_SK             --账号的SK
4、SWR_PASSWD        --登录SWR的密码
5、SWR_USERNAME   --登录SWR的用户名  

五、触发方式
将代码提交到master分支即可触发