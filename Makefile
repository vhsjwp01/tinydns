REGISTRY_SERVER      = lvicdockregp01.ingramcontent.com
REGISTRY_NAMESPACE   = ingramcontent
IMAGE_NAME           = tinydns
IMAGE_TAG            = $(shell git branch | egrep "^\*" | awk '{print $$NF}')
REPO_DISTRO          = OracleServer
REPO_DISTRO_VERSION  = 6.5
REPO_CPU_ARCH        = x86_64
REPO_WEB_SERVER      = 10.50.3.2:88
DISTRO_MAJOR_VERSION = $(shell echo ${REPO_DISTRO_VERSION} | cut -c 1)

build:
	sed -e "s/::IMAGE_TAG::/${IMAGE_TAG}/g" -e "s/::REPO_DISTRO_VERSION::/${REPO_DISTRO_VERSION}/g" \
	    -e "s/::DISTRO_MAJOR_VERSION::/${DISTRO_MAJOR_VERSION}/g" Dockerfile.template > Dockerfile
	sed -e "s/::REPO_DISTRO::/${REPO_DISTRO}/g" -e "s/::REPO_DISTRO_VERSION::/${REPO_DISTRO_VERSION}/g" \
	    -e "s/::REPO_CPU_ARCH::/${REPO_CPU_ARCH}/g" -e "s/::REPO_WEB_SERVER::/${REPO_WEB_SERVER}/g" files/base.repo > ol_base.repo
	docker build -t ${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} .
push:
	docker push ${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}
