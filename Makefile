SO:=$(shell uname -s | awk '{print tolower($$0)}')
AZK_VERSION:=$(shell cat package.json | grep -e "version" | cut -d' ' -f4 | sed -n 's/\"//p' | sed -n 's/\"//p' | sed -n 's/,//p')

AZK_ROOT_PATH:=$(shell pwd)
AZK_LIB_PATH:=${AZK_ROOT_PATH}/lib
AZK_NPM_PATH:=${AZK_ROOT_PATH}/node_modules
NVM_BIN_PATH:=${AZK_ROOT_PATH}/src/libexec/nvm.sh

AZK_BIN:=${AZK_ROOT_PATH}/bin/azk

# Load dependencies versions
include .dependencies

# default target
all: bootstrap

# BOOTSTRAP
NVM_DIR := ${AZK_LIB_PATH}/nvm
NVM_NODE_VERSION := $(shell cat ${AZK_ROOT_PATH}/.nvmrc)
NODE = ${NVM_DIR}/${NVM_NODE_VERSION}/bin/node
VM_DISKS_DIR := ${AZK_LIB_PATH}/vm/${AZK_ISO_VERSION}

SRC_JS = $(shell cd ${AZK_ROOT_PATH} && find ./src -name '*.*' -print 2>/dev/null)

teste_envs:
	@echo ${LIBNSS_RESOLVER_VERSION}
	@echo ${AZK_ISO_VERSION}

${AZK_LIB_PATH}/azk: $(SRC_JS) ${AZK_NPM_PATH}/.install
	@echo "task: $@"
	@export AZK_LIB_PATH=${AZK_LIB_PATH} && \
		export AZK_NPM_PATH=${AZK_NPM_PATH} && \
		${AZK_BIN} nvm gulp babel && touch ${AZK_LIB_PATH}/azk

${AZK_NPM_PATH}/.install: npm-shrinkwrap.json package.json ${NODE}
	@echo "task: $@"
	@mkdir -p ${AZK_NPM_PATH}
	@export AZK_LIB_PATH=${AZK_LIB_PATH} && \
		${AZK_BIN} nvm npm install && \
		touch ${AZK_NPM_PATH}/.install

${NODE}:
	@echo "task: $@: ${NVM_NODE_VERSION}"
	@export NVM_DIR=${NVM_DIR} && \
		mkdir -p ${NVM_DIR} && \
		. ${NVM_BIN_PATH} && \
		nvm install $(NVM_NODE_VERSION) && \
		npm install npm -g

clean:
	@echo "task: $@"
	@find ${AZK_LIB_PATH} -maxdepth 1 -not -name "lib" | egrep -v '\/vm$$' | xargs rm -Rf
	@rm -Rf ${AZK_NPM_PATH}/..?* ${AZK_NPM_PATH}/.[!.]* ${AZK_NPM_PATH}/*
	@rm -Rf ${NVM_DIR}/..?* ${NVM_DIR}/.[!.]* ${NVM_DIR}/*

bootstrap: ${AZK_LIB_PATH}/azk ${AZK_LIB_PATH}/azk dependencies

dependencies: ${AZK_LIB_PATH}/bats ${VM_DISKS_DIR}/azk.iso ${VM_DISKS_DIR}/azk-agent.vmdk.gz

S3_URL=https://s3-sa-east-1.amazonaws.com/repo.azukiapp.com/vm_disks/${AZK_ISO_VERSION}
${VM_DISKS_DIR}/azk.iso:
	@echo Downloading: ${S3_URL}/azk.iso ...
	@mkdir -p ${VM_DISKS_DIR}
	@curl ${S3_URL}/azk.iso -o ${VM_DISKS_DIR}/azk.iso

${VM_DISKS_DIR}/azk-agent.vmdk.gz:
	@echo Downloading: ${S3_URL}/azk-agent.vmdk.gz ...
	@curl ${S3_URL}/azk-agent.vmdk.gz -o ${VM_DISKS_DIR}/azk-agent.vmdk.gz

${AZK_LIB_PATH}/bats:
	@git clone -b ${BATS_VERSION} https://github.com/sstephenson/bats ${AZK_LIB_PATH}/bats

# PACKAGE
AZK_PACKAGE_PATH:=${AZK_ROOT_PATH}/package
AZK_PACKAGE_PREFIX = ${AZK_PACKAGE_PATH}/v${AZK_VERSION}
PATH_USR_LIB_AZK:=${AZK_PACKAGE_PREFIX}/usr/lib/azk
PATH_USR_BIN:=${AZK_PACKAGE_PREFIX}/usr/bin
PATH_NODE_MODULES:=${PATH_USR_LIB_AZK}/node_modules
PATH_AZK_LIB:=${PATH_USR_LIB_AZK}/lib
PATH_AZK_NVM:=${PATH_AZK_LIB}/nvm
NODE_PACKAGE = ${PATH_AZK_NVM}/${NVM_NODE_VERSION}/bin/node
PATH_MAC_PACKAGE = ${AZK_PACKAGE_PATH}/azk_${AZK_VERSION}.tar.gz

# Build package folders tree
package_brew: package_build fix_permissions ${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION} ${PATH_MAC_PACKAGE}
package_mac:
	@export AZK_PACKAGE_PATH=${AZK_PACKAGE_PATH}/brew && \
		mkdir -p $$AZK_PACKAGE_PATH && \
		make -e package_brew

# Alias to create a distro package
LINUX_CLEAN:="--clean"
package_linux: package_build creating_symbolic_links fix_permissions
package_deb:
	@mkdir -p package
	@./src/libexec/package.sh deb ${LINUX_CLEAN}
package_rpm:
	@mkdir -p package
	@./src/libexec/package.sh rpm ${LINUX_CLEAN}

package_clean:
	@echo "task: $@"
	@rm -Rf ${AZK_PACKAGE_PREFIX}/..?* ${AZK_PACKAGE_PREFIX}/.[!.]* ${AZK_PACKAGE_PREFIX}/*

${PATH_NODE_MODULES}: ${PATH_USR_LIB_AZK}/npm-shrinkwrap.json ${NODE_PACKAGE}
	@echo "task: $@"
	@cd ${PATH_USR_LIB_AZK} && ${AZK_BIN} nvm npm install --production

${PATH_USR_LIB_AZK}/npm-shrinkwrap.json: ${PATH_USR_LIB_AZK}/package.json
	@echo "task: $@"
	@ln -s ${AZK_NPM_PATH} ${PATH_NODE_MODULES}
	@cd ${PATH_USR_LIB_AZK} && ${AZK_BIN} nvm npm shrinkwrap
	@rm ${PATH_NODE_MODULES}

${NODE_PACKAGE}:
	@echo "task: $@"
	@export NVM_DIR=${PATH_AZK_NVM} && \
		mkdir -p ${PATH_AZK_NVM} && \
		. ${NVM_BIN_PATH} && \
		nvm install $(NVM_NODE_VERSION) && \
		npm install npm -g

define COPY_FILES
$(abspath $(2)/$(3)): $(abspath $(1)/$(3))
	@echo "task: copy from $$< to $$@"
	@mkdir -p $$(dir $$@)
	@if [ -d "$$<" ]; then \
		if [ -d "$$@" ]; then \
			touch $$@; \
		else \
			mkdir -p $$@; \
		fi \
	fi
	@[ -d $$< ] || cp -f $$< $$@
endef

# copy regular files
FILES_FILTER  = package.json bin shared .nvmrc CHANGELOG.md LICENSE README.md .dependencies
FILES_ALL     = $(shell cd ${AZK_ROOT_PATH} && find $(FILES_FILTER) -print 2>/dev/null)
FILES_TARGETS = $(foreach file,$(addprefix $(PATH_USR_LIB_AZK)/, $(FILES_ALL)),$(abspath $(file)))
$(foreach file,$(FILES_ALL),$(eval $(call COPY_FILES,$(AZK_ROOT_PATH),$(PATH_USR_LIB_AZK),$(file))))

# Copy transpiled files
FILES_JS         = $(shell cd ${AZK_LIB_PATH}/azk 2>/dev/null && find ./ -name '*.*' -print 2>/dev/null)
FILES_JS_TARGETS = $(foreach file,$(addprefix ${PATH_AZK_LIB}/azk/, $(FILES_JS)),$(abspath $(file)))
$(foreach file,$(FILES_JS),$(eval $(call COPY_FILES,$(AZK_LIB_PATH)/azk,$(PATH_AZK_LIB)/azk,$(file))))

# Debug opts
#$(warning $(FILES_JS))
#$(foreach file,$(FILES_ALL),$(warning $(file)))
# $(warning $(abspath $(2)/$(3)): $(abspath $(1)/$(3)))

fix_permissions:
	@chmod 755 ${PATH_USR_LIB_AZK}/bin/*

creating_symbolic_links:
	@echo "task: $@"
	@mkdir -p ${PATH_USR_BIN}
	@ln -sf ../lib/azk/bin/azk ${PATH_USR_BIN}/azk
	@ln -sf ../lib/azk/bin/adocker ${PATH_USR_BIN}/adocker

${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION}: ${AZK_LIB_PATH}/vm
	@mkdir -p ${PATH_AZK_LIB}/vm/${AZK_ISO_VERSION}
	@cp -r ${VM_DISKS_DIR} ${PATH_AZK_LIB}/vm

${PATH_MAC_PACKAGE}: ${AZK_PACKAGE_PREFIX}
	@cd ${PATH_USR_LIB_AZK}/.. && tar -czf ${PATH_MAC_PACKAGE} ./

package_build: bootstrap ${AZK_LIB_PATH}/azk $(FILES_TARGETS) $(FILES_JS_TARGETS) ${PATH_NODE_MODULES}

.PHONY: bootstrap clean fast_clean package package_brew package_mac package_deb package_rpm package_build package_clean copy_files fix_permissions creating_symbolic_links dependencies
