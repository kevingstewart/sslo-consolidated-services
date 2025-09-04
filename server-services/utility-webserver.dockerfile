# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_PREFIX=/usr/local
ENV OPENSSL_CONF=${OPENSSL_PREFIX}/ssl/openssl.cnf

# Install dependencies
RUN apt update && apt install -y \
    build-essential \
    git \
    cmake \
    ninja-build \
    perl \
    python3 \
    g++ \
    libtool \
    automake \
    autoconf \
    pkg-config \
    curl \
    wget \
    ca-certificates \
    zlib1g-dev \
    libpcre3 \
    libpcre3-dev \
    && apt clean

RUN apt update && apt install -y ca-certificates

# Clone and build OpenSSL 3.5 from source
WORKDIR /build
RUN git clone --depth 1 --branch openssl-3.5 https://github.com/openssl/openssl.git
WORKDIR /build/openssl
RUN ./config --prefix=${OPENSSL_PREFIX} --openssldir=${OPENSSL_PREFIX}/ssl --libdir=lib -Wl,-rpath,${OPENSSL_PREFIX}/lib shared zlib && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Update system path to use the new OpenSSL
ENV PATH="${OPENSSL_PREFIX}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib"

## Update openssl.conf
RUN <<EOF cat >> ${OPENSSL_PREFIX}/ssl/openssl.cnf
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
oqsprovider = oqsprovider_sect

[default_sect]
activate = 1

[oqsprovider_sect]
activate = 1
EOF

# Set OpenSSL configuration globally
ENV OPENSSL_CONF=${OPENSSL_CONF}

## Install and configure nginx
WORKDIR /build
RUN wget --no-check-certificate https://nginx.org/download/nginx-1.27.4.tar.gz
RUN tar zxf nginx-1.27.4.tar.gz
WORKDIR /build/nginx-1.27.4
RUN ./configure --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -fPIC'      \
    --prefix=/opt                                      \
    --conf-path=/opt/nginx/nginx.conf              	\
    --http-log-path=/var/log/nginx/access.log      	\
    --error-log-path=/var/log/nginx/error.log      	\
    --lock-path=/var/lock/nginx.lock               	\
    --pid-path=/run/nginx.pid                      	\
    --modules-path=/opt/lib/nginx/modules              \
    --http-client-body-temp-path=/var/lib/nginx/body   \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi    \
    --http-proxy-temp-path=/var/lib/nginx/proxy        \
    --http-scgi-temp-path=/var/lib/nginx/scgi          \
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi        \
    --with-compat                                  	\
    --with-debug                                   	\
    --with-http_ssl_module                         	\
    --with-http_stub_status_module                 	\
    --with-http_realip_module                      	\
    --with-http_auth_request_module                	\
    --with-http_v2_module                          	\
    --with-http_dav_module                         	\
    --with-http_slice_module                       	\
    --with-threads                                 	\
    --with-http_addition_module                    	\
    --with-http_gunzip_module                      	\
    --with-http_gzip_static_module                 	\
    --with-http_sub_module                         	\
    --with-pcre                                    	\
    --with-openssl-opt=enable-tls1_3               	\
    --with-ld-opt="-L/opt/lib64 -Wl,-rpath,/opt/lib64" \
    --with-cc-opt="-I/opt/include"
RUN make && make install
RUN mkdir /var/lib/nginx && mkdir /opt/nginx/conf.d
ENV PATH="/opt/sbin:${PATH}"

## Expose ports
EXPOSE 80
EXPOSE 443
EXPOSE 444

## Create and install new server cert and key
RUN openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=NE/L=Omaha/O=F5/CN=www.f5labs.com" \
    -keyout /etc/server.key  -out /etc/server.crt

## Copy website files
WORKDIR /var/www/site/html
COPY webserver ./

## Create nginx.conf
RUN <<EOF cat > /opt/nginx/nginx.conf
user  www-data;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}
http {
    server {
        listen                  0.0.0.0:80;
        server_name             webserver.local;
        location ./images/ {
            root                /var/www/site/html/images;
        }
        location / {
            root                /var/www/site/html;
            index               index.html;
            include             /opt/nginx/mime.types;
        }
    }
    server {
        listen                  0.0.0.0:443 ssl;
        server_name             webserver.local;
        ssl_certificate         /etc/server.crt;
        ssl_certificate_key     /etc/server.key;
        location ./images/ {
            root                /var/www/site/html/images;
        }
        location / {
            root                /var/www/site/html;
            index               index.html;
            include             /opt/nginx/mime.types;
        }
    }
    server {
        listen                  0.0.0.0:444 ssl;
        ssl_certificate         /etc/server.crt;
        ssl_certificate_key     /etc/server.key;
        ssl_protocols           TLSv1.3;
        ssl_ecdh_curve          X25519MLKEM768;

        location / {
            default_type text/html;
            return 200 "<html><head><title>PQC Test Success!</title></head><body><H2>PQC Test Success!</H1><p><b>Negotiated Protocol</b>: \$ssl_protocol </p><p><b>Negotiated Cipher</b>: \$ssl_cipher </p><p><b>Negotiated Curve</b>: \$ssl_curve </p><p><b>Supported Curves</b>: \$ssl_curves </p></body></html>";
        }
    }
}
EOF

## Delete /build folder
RUN rm -rf /build

## Start daemon on container run
CMD ["nginx", "-g", "daemon off;"]
