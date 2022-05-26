# 部署服务到华为云CCE服务
CCE支持两种方式部署  
1、docker部署，将CCE节点当做安装了Docker环境的普通节点来部署(或自行安装docker环境)，需要在节点上下载对应的容器，然后启动  
2、k8s部署，需要在客户端节点安装kubectl，且有对应k8s集群的kubeconfig文件，然后通过apply的方式完成服务或集群部署  
## 1、**前置工作:云服务资源使用**  
(1)、华为云 云容器引擎（[Cloud Container Engine](https://www.huaweicloud.com/product/cce.html)）提供高可靠高性能的企业级容器应用管理服务，支持Kubernetes社区原生应用和工具，简化云上自动化容器运行环境搭建，面向云原生2.0打造CCE Turbo容器集群，计算、网络、调度全面加速，全面加速企业应用创新。  
需要提前学习CCE相关概念和操作，并创建好CCE集群或节点  
(2)、华为云 容器镜像服务（[SoftWare Repository for Container](https://www.huaweicloud.com/product/swr.html)）是一种支持容器镜像全生命周期管理的服务，提供简单易用、安全可靠的镜像管理功能，帮助用户快速部署容器化服务。  
需要提前学习SWR相关概念和操作，并创建好登录指令，获取账号和密码  
(3)、对象存储服务（[Object Storage Service，OBS](https://www.huaweicloud.com/product/obs.html)）提供海量、安全、高可靠、低成本的数据存储能力，可供用户存储任意类型和大小的数据。适合企业备份/归档、视频点播、视频监控等多种数据存储场景。  
需要提前学习OBS的基本操作，并创建好桶  

## 2.部署CCE-Docker服务
#### 部署过程分为如下几个阶段  
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
3、ACCESSKEY             --华为云账号的AK  
4、SECRETACCESSKEY       --华为云账号的SK  

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
    - name: Log in to HuaweiCloud SWR
      uses: huaweicloud/swr-login@v1
      with:
      region: ${{ env.REGIONID }}
      access-key-id: ${{ secrets.ACCESSKEY }}
      access-key-secret: ${{ secrets.SECRETACCESSKEY }}

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
        tags: swr.${{ env.REGIONID }}.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
```
#### docker环境处理(如果已经安装好可以跳过)
```yaml
    # 在服务器上部署docker并启动，如果服务器已经安装了docker环境，可以跳过
    - name: install docker and start docker service
      uses: huaweicloud/ssh-remote-action@v1.2
      with:
        ipaddr: ${{ env.IPADDR }}
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
        ipaddr: ${{ env.IPADDR }}
        username: ${{ secrets.USERNAME }}
        password: ${{ secrets.PASSWORD }}
        commands: |
          docker stop `docker ps -a | grep tomcat | grep maven-sample | awk '{print $1}'`
          docker rm `docker ps -a | grep tomcat | grep maven-sample | awk '{print $1}'`
          docker pull swr.${{ env.REGIONID }}.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
          docker run -d -p 8080:8080 swr.${{ env.REGIONID }}.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
```
#### 检查服务是否启动
```yaml
    - name: check docker version
      run: |
        sleep 30
        curl -kv http://${{ env.IPADDR }}:8080
```  
详情请参考: .github/workflow/deploy-cce-docker.yml  
## 3.部署CCE-k8s服务
#### 部署过程分为如下几个阶段
  1、打包maven项目  
  2、将打包出来的war包上传到OBS  
  3、基于tomcat制作docker镜像，并上传到SWR  
  4、通过apply deployment等yml将镜像部署到目标k8s集群  

#### 运行该项目，需要提前在华为云上开通如下服务  
	1、OBS服务，并创建桶  
	2、SWR服务，并创建组织  
	3、准备好CCE的k8s集群，并获取kubeconfig配置文件，存储到OBS桶里备用  

#### 参数准备:需要准备如下数据  
1、生成ACCESSKEY,SECRETACCESSKEY获取方式请参考 `https://support.huaweicloud.com/apm_faq/apm_03_0001.html`  
2、CCE-K8s集群的kubeconfig文件，可以到集群详情页面中下载  
3、注意将env:ipaddr中的${ip_address}替换为真实的IP地址  
4、填写env:REGIONID中的${region_id}为需要部署的真实region，如cn-north-4  

#### 需要提前在github仓库-->settings-->Actions下添加如下secrets  
1、USERNAME    --CCE节点的登录账号  
2、PASSWORD    --CCE节点的登录密码  
3、ACCESSKEY   --华为云账号的ACCESSKEY  
4、SECRETACCESSKEY   --华为云账号的SECRETACCESSKEY  

#### 部署过程:前面的打包，上传OBS和制作镜像不在赘述
```yaml
#安装kubectl并配置kubeconfig
    - name: install kubectl
      run: |
        mkdir -p ~/k8s
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        ls -la
        mv kubectl ~/k8s
        chmod +x ~/k8s/kubectl
        ls -la ~/k8s
        export PATH=~/k8s:$PATH
        mkdir ~/.kube

    # 需要提前准备好kubectconfig，并存放到可以方便下载到的地方，不建议放到代码仓库里，容易泄露，这里我们放在了obs里
    - name: Upload To Huawei OBS
      uses: huaweicloud/obs-helper@v1.0.0
      id: upload_file_to_obs
      with:
        access_key: ${{ secrets.ACCESSKEY }}
        secret_key: ${{ secrets.SECRETACCESSKEY }}
        region: region
        bucket_name: bucket-test
        operation_type: download
        obs_file_path: k8s/kubeconfig.json
        local_file_path: ~/.kube/config
```        
####  部署tomcat镜像 到k8s集群
```yaml
    - name: deploy tomcat to CCE k8s from SWR
      run: |
        sed -i 's/_IMAGE_TAG_/${{ IMAGE_TAG }}/g' ./tomcat/tomcat-deployment.yml
        kubectl apply -f tomcat/tomcat-deployment.yml
        kubectl apply -f tomcat/tomcat-service.yml
        sleep 60
        kubectl get deployment
        kubectl get pods --show-labels
        kubectl get service
```  
详情请参考: .github/workflow/deploy-cce-k8s.yml

####  手工控制image tag
如果希望手工控制镜像tag,可以配置放开这个参数，这样每次action执行，都会弹出来image_tag对话框让你填写
```yaml
on:
  push:
    branches: 
    - 'master'
  workflow_dispatch: 
    inputs:
      tags:
        required: true
        default: 'v1.0.0.1'
        description: 'docker build image tag'  
env: 
 IMAGE_TAG: ${{ github.event.inputs.image_tag }}
```

## 4.基于cce-credentials-action部署CCE-k8s服务
说明:可以通过 huaweicloud/cce-credentials-action@v1.0.0 自动完成kubect的安装和kubeconfig的配置，省略手动安装kubectl和配置kubeconfig的过程
参数说明:
(1).获取华为云用户的AK/SK和project_id,详情请参考 https://support.huaweicloud.com/apm_faq/apm_03_0001.html,AK和SK需要设置到github仓库的secrets中
(2).获取CCE集群的集群ID,获取方法:点击CCE集群进入CCE详情页面,然后拷贝左上角的 集群ID
(3).由于要从外网github上访问华为云CCE集群，需要为集群创建并绑定弹性公网IP
使用样例如下:
```yaml
    # docker login,设置登陆到华为的swr
    - name: Log in to HuaweiCloud SWR
      uses: huaweicloud/swr-login@v1
      with:
      region: ${{ env.REGIONID }}
      access-key-id: ${{ secrets.ACCESSKEY }}
      access-key-secret: ${{ secrets.SECRETACCESSKEY }}

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
        tags: swr.${{ env.REGIONID }}.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}

    # 镜像安全扫描，如果需要扫描镜像里是否有安全漏洞，可以使用如下方式进行扫描,severity默认为UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
    - name: Scan image by trivy
      uses: cfy9/trivy-action@v0.0.2
      with:
        image_name: swr.${{ env.REGIONID }}.myhuaweicloud.com/ptworkflow/tomcat:${{ IMAGE_TAG }}
        scan_type: image
        format: table
        severity: MEDIUM,HIGH,CRITICAL

    - name: install kubectl and set cce  credentials
      uses: huaweicloud/cce-credentials-action@v1.0.0
      with:
        ak: ${{ secrets.ACCESSKEY }}
        sk: ${{ secrets.SECRETACCESSKEY }}
        region: ${{ env.REGIONID }}
        project_id: "0dd8cb413000906a2fcdc019b5a84546"
        cluster_id: "f288d212-d299-11ec-8e06-0255ac101534"

      
    # 部署tomcat 到k8s集群
    - name: deploy tomcat to CCE k8s from SWR
      run: |
        sed -i 's/_IMAGE_TAG_/${{ IMAGE_TAG }}/g' ./tomcat/tomcat-deployment.yml
        kubectl apply -f tomcat/tomcat-deployment.yml
        kubectl apply -f tomcat/tomcat-service.yml
        sleep 60
        kubectl get deployment
        kubectl get pods --show-labels
        kubectl get service
```        