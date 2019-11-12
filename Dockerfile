FROM node:10.16.0
ARG codeServerVersion=docker
ARG vscodeVersion
ARG githubToken

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y \
	libxkbfile-dev \
	libsecret-1-dev

# Ensure latest yarn.
RUN npm install -g yarn@1.13

WORKDIR /src
COPY . .

RUN yarn \
	&& MINIFY=true GITHUB_TOKEN="${githubToken}" yarn build "${vscodeVersion}" "${codeServerVersion}" \
	&& yarn binary "${vscodeVersion}" "${codeServerVersion}" \
	&& mv "/src/binaries/code-server${codeServerVersion}-vsc${vscodeVersion}-linux-x86_64" /src/binaries/code-server \
	&& rm -r /src/build \
	&& rm -r /src/source

# We deploy with ubuntu so that devs have a familiar environment.
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive
ENV TZ UTC

RUN apt-get update && apt-get install -y \
	openssl \
	gcc \
	g++ \
	make \
	net-tools \
	git \
	locales \
	sudo \
	dumb-init \
	vim \
	curl \
	wget \
	jq \
	php-mysql \
	phpunit \
	subversion

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
RUN curl -O https://getcomposer.org/download/1.9.1/composer.phar && chmod +x composer.phar && mv composer.phar /usr/local/bin/composer
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && chmod +x phpcs.phar && mv phpcs.phar /usr/local/bin/phpcs
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && chmod +x phpcbf.phar && mv phpcbf.phar /usr/local/bin/phpcbf
RUN git clone -b master https://github.com/WordPress/WordPress-Coding-Standards.git wpcs && mv wpcs /usr/local/lib/wpcs
RUN phpcs --config-set installed_paths /usr/local/lib/wpcs

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash && apt-get install -y nodejs

RUN npm install -g eslint babel-eslint
RUN npm install -g "git+https://github.com/Automattic/wp-prettier.git#wp-prettier-1.18.2"

RUN locale-gen en_US.UTF-8
# We cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LC_ALL=en_US.UTF-8 \
	SHELL=/bin/bash

RUN adduser --gecos '' --disabled-password coder && \
	echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER coder
# We create first instead of just using WORKDIR as when WORKDIR creates, the
# user is root.
RUN mkdir -p /home/coder/project

WORKDIR /home/coder/project

# This ensures we have a volume mounted even if the user forgot to do bind
# mount. So that they do not lose their data if they delete the container.
VOLUME [ "/home/coder/project" ]

COPY --from=0 /src/binaries/code-server /usr/local/bin/code-server
EXPOSE 8080

ENTRYPOINT ["dumb-init", "code-server", "--host", "0.0.0.0"]
