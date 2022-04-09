# 部署服务到华为云CCE服务
CCE支持两种方式部署
1、docker部署，将CCE节点当做安装了Docker环境的普通节点来部署(或自行安装docker环境)，需要在节点上下载对应的容器，然后启动
2、k8s部署，需要在客户端节点安装kubectl，且有对应k8s集群的kubeconfig文件，然后通过apply的方式完成服务或集群部署
## **前置工作**
### 1.云服务资源使用
(1)、华为云 云容器引擎（[Cloud Container Engine](https://www.huaweicloud.com/product/cce.html)）提供高可靠高性能的企业级容器应用管理服务，支持Kubernetes社区原生应用和工具，简化云上自动化容器运行环境搭建，面向云原生2.0打造CCE Turbo容器集群，计算、网络、调度全面加速，全面加速企业应用创新。
需要提前学习CCE相关概念和操作，并创建好CCE集群或节点
(2)、华为云 容器镜像服务（[SoftWare Repository for Container](https://www.huaweicloud.com/product/swr.html)）是一种支持容器镜像全生命周期管理的服务，提供简单易用、安全可靠的镜像管理功能，帮助用户快速部署容器化服务。
需要提前学习SWR相关概念和操作，并创建好登录指令，获取账号和密码
长期登录指令获取方式:`https://support.huaweicloud.com/usermanual-swr/swr_01_1000.html`
临时登录指令获取方式:

### 3.部署CCE-Docker服务
#### 部署过程分为如下几个节点
  1、打包maven项目
  2、将打包出来的war包上传到OBS
  3、基于tomcat制作docker镜像，并上传到SWR
  4、对端服务器上启动容器
  5、检查服务启动后,web页面是否能正常访问

#### 运行该项目，需要提前在华为云上开通如下服务
	1、OBS服务，并创建桶
	2、SWR服务，并创建组织
	3、准备一台ECS虚机安装Docker，或者一台已经安装好docker的CCE节点，修改防火墙策略，开通8080端口
#### 参数准备:需要准备如下数据
1、生成ACCESSKEY,SECRETACCESSKEY获取方式请参考 `https://support.huaweicloud.com/apm_faq/apm_03_0001.html`
2、生成swr的长期登录指令，请参考 `https://support.huaweicloud.com/usermanual-swr/swr_01_1000.html`
3、获取CCE节点的IP，账号和密码
#### 需要提前在github仓库-->settings-->Actions下添加如下secrets
1、USERNAME    --CCE节点的登录账号
2、PASSWORD    --CCE节点的登录密码
3、HUAWEI_AK             --账号的AK
4、HUAWEI_SK             --账号的SK
5、SWR_PASSWD        --登录SWR的密码
6、SWR_USERNAME   --登录SWR的用户名  

#### 项目打包
```yaml
    - name: build maven project
      run: mvn clean -U package -Dmaven.test.skip 
```
#### 上传OBS
上传当前版本到OBS中归档
```yaml
    - name: Upload To Huawei OBS
      uses: huaweicloud/obs-helper@v1.0.0
      id: upload_file_to_obs
      with:
        access_key: ${{ secrets.ACCESSKEY }}
        secret_key: ${{ secrets.SECRETACCESSKEY }}
        region: region
        bucket_name: bucket-test
        operation_type: upload
        local_file_path: target/intro.war
        obs_file_path: workflow/intro/v1.0.0.1/
```
#### 制作镜像并推送到SWR
```yaml
    # 检查docker版本
    - name: check docker version
      run: docker -v
      
    # docker login,设置登陆到华为的swr
    - name: Login to huawei SWR
      uses: docker/login-action@v1
      with:
        registry: "swr.cn-north-4.myhuaweicloud.com"
        username: ${{ secrets.SWR_USERNAME }}
        password: ${{ secrets.SWR_PASSWD }}

    # 设置 docker 环境
    - name: Set up Docker Buildx
      id: buildx
      uses: docker/setup-buildx-action@v1
      
    # build 并且 push docker 镜像
    - name: Build and push
      id: docker_build
      uses: docker/build-push-action@v2
      with:
        context: ./
        file: ./Dockerfile
        push: true
        tags: swr.cn-north-4.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
```
#### docker环境处理(如果已经安装好可以跳过)
```yaml
    # 在服务器上部署docker并启动，如果服务器已经安装了docker环境，可以跳过
    - name: install docker and start docker service
      uses: huaweicloud/ssh-remote-action@v1.2
      with:
        ipaddr: 192.168.158.132
        username: ${{ secrets.USERNAME }}
        password: ${{ secrets.PASSWORD }}
        commands: |
          curl -sSL https://get.docker.com/ | sh
          systemctl enable docker.service
          systemctl start docker.service
          docker -v
```
#### 下载镜像并启动服务
```yaml
    # 下载镜像并启动服务
    - name: install docker and start docker service
      uses: huaweicloud/ssh-remote-action@v1.2
      with:
        ipaddr: 192.168.158.132
        username: ${{ secrets.USERNAME }}
        password: ${{ secrets.PASSWORD }}
        commands: |
          docker stop `docker ps -a | grep tomcat | grep maven-sample | awk '{print $1}'`
          docker rm `docker ps -a | grep tomcat | grep maven-sample | awk '{print $1}'`
          docker pull swr.cn-north-4.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
          docker run -d -p 8080:8080 swr.cn-north-4.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
```
#### 检查服务是否启动
```yaml
    - name: check docker version
      run: |
        sleep 30
        curl -kv http://192.168.158.132:8080
```        