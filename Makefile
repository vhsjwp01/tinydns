REGISTRY_SERVER    = lvicdockregp01.ingramcontent.com
REGISTRY_NAMESPACE = ingramcontent
IMAGE_NAME         = tinydns
IMAGE_TAG          = $(shell git branch | egrep "^\*" | awk '{print $$NF}')

build:
	sed -e "s/::IMAGE_TAG::/${IMAGE_TAG}/g" Dockerfile.template > Dockerfile
	docker build -t ${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} .
push:
	docker push ${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}
