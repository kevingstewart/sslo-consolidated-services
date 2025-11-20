# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set local environment variables
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

# Update and install required packages
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

# Update openssl.conf
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

# Install and configure nginx
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

# Expose ports -> 80=HTTP, 443=HTTPS, 444=HTTPS w/PQC and static HTML response, 445=Juiceshop, 446=mTLS and static response
EXPOSE 80
EXPOSE 443
EXPOSE 444
EXPOSE 445
EXPOSE 446

# Generate and install new server cert and key
# RUN openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
#     -subj "/C=US/ST=NE/L=Omaha/O=F5/CN=www.f5labs.com" \
#     -keyout /etc/server.key  -out /etc/server.crt

# Create makecerts script
RUN <<"EOF" cat > /usr/local/bin/makecerts
#!/usr/bin/env bash

const_sha=sha256
const_rsa=2048
const_days=1024

create_rootca() {
    ## Test for potential overwrite
    if [ -e "${SUBJECT}.cer" ]; then
        while true; do
            read -p "${SUBJECT}.cer already exists. Are you sure you want to overwrite? [yes|no] " yn
            case $yn in
                yes ) break;;
                no ) exit 0;;
                * ) echo "Please answer yes or no";;
            esac
        done
    fi

    ## Test for create password on subca
    if [ "${ENCRYPT}" != "" ]; then nodes=""; else nodes="-nodes"; fi

    ## Create root CA
    touch ca.cnf && openssl req -new -x509 -${const_sha} ${nodes} -newkey rsa:${const_rsa} -days ${const_days} -keyout ${SUBJECT}.key -out ${SUBJECT}.cer -batch -subj "/CN=${SUBJECT}" \
    -config <(cat ca.cnf <(printf "[req]\ndistinguished_name=rdn\nx509_extensions=v3_ca\n[rdn]\n[v3_ca]\nsubjectKeyIdentifier=hash\nbasicConstraints=critical, CA:TRUE\nkeyUsage=digitalSignature, keyCertSign, cRLSign"))
    rm -f ca.cnf
}

create_subca() {
    ## Test for potential overwrite
    if [ -e "${SUBJECT}.cer" ]; then
        while true; do
            read -p "${SUBJECT}.cer already exists. Are you sure you want to overwrite? [yes|no] " yn
            case $yn in
                yes ) break;;
                no ) exit 0;;
                * ) echo "Please answer yes or no";;
            esac
        done
    fi

    ## Test for existence of issuer
    if [ ! -e "${ISSUER}.cer" ]; then
        echo "Issuer (${ISSUER}) does not exist. Exiting."
        exit 1
    fi

    ## Test for create password on subca
    if [ "${ENCRYPT}" != "" ]; then nodes=""; else nodes="-nodes"; fi

    ## Create and sign subordinate CA
    touch csr.cnf && openssl req -new -newkey rsa:${const_rsa} -${const_sha} ${nodes} -days ${const_days} -keyout ${SUBJECT}.key -out ${SUBJECT}.csr -subj "/CN=${SUBJECT}"
    openssl x509 -req -${const_sha} -days ${const_days} -CA ${ISSUER}.cer -CAkey ${ISSUER}.key -CAcreateserial -in ${SUBJECT}.csr -out ${SUBJECT}.cer \
    -extensions v3_ext \
    -extfile <(cat csr.cnf <(printf "[v3_ext]\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nbasicConstraints=critical, CA:TRUE\nkeyUsage=digitalSignature, keyCertSign, cRLSign"))
    rm -f ${SUBJECT}.csr csr.cnf

    ## Test for create CA bundle file
    if [ "${BUNDLE}" != "" ]; then cat ${ISSUER}.cer ${SUBJECT}.cer > ${BUNDLE}.pem; fi
}

create_server() {
    ## Test for existence of issuer
    if [ ! -e "${ISSUER}.cer" ]; then
        echo "Issuer (${ISSUER}) does not exist. Exiting."
        exit 1
    fi

    ## Create and sign TLS server certificate
    touch csr.cnf && openssl req -new -nodes -newkey rsa:${const_rsa} -keyout ${SUBJECT}.key -out ${SUBJECT}.csr -batch -subj "/CN=${SUBJECT}"
    openssl x509 -req -${const_sha} -days ${const_days} -CA ${ISSUER}.cer -CAkey ${ISSUER}.key -CAcreateserial -in ${SUBJECT}.csr -out ${SUBJECT}.crt \
    -extensions v3_ext \
    -extfile <(cat csr.cnf <(printf "[v3_ext]\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nsubjectAltName=DNS:${SUBJECT}\nextendedKeyUsage=clientAuth, serverAuth"))
    rm -f ${SUBJECT}.csr csr.cnf
}

create_client() {
    ## Test for existence of issuer
    if [ ! -e "${ISSUER}.cer" ]; then
        echo "Issuer (${ISSUER}) does not exist. Exiting."
        exit 1
    fi

    ## Create and sign TLS server certificate
    touch csr.cnf && openssl req -new -nodes -newkey rsa:${const_rsa} -keyout ${SUBJECT}.key -out ${SUBJECT}.csr -batch -subj "/CN=${SUBJECT}"
    openssl x509 -req -${const_sha} -days ${const_days} -CA ${ISSUER}.cer -CAkey ${ISSUER}.key -CAcreateserial -in ${SUBJECT}.csr -out ${SUBJECT}.crt \
    -extensions v3_ext \
    -extfile <(cat csr.cnf <(printf "[v3_ext]\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nsubjectAltName=DNS:${SUBJECT}\nextendedKeyUsage=clientAuth"))
    rm -f ${SUBJECT}.csr csr.cnf
}

process_handler() {
    if [ "${CMD}" == "rootca" ]; then
        if [[ -z "${SUBJECT}" ]]; then
            printf "\nThe specified command requires additional parameters. Please see --help" >&2
            echo .&2
            command_help >&2
            exit 1
        fi
        create_rootca
    elif [ "${CMD}" == "subca" ]; then
        if [[  -z "${SUBJECT}" || -z "${ISSUER}" ]]; then
            printf "\nThe specified command requires additional parameters. Please see --help" >&2
            echo .&2
            command_help >&2
            exit 1
        fi
        create_subca
    elif [ "${CMD}" == "server" ]; then
        if [[  -z "${SUBJECT}" || -z "${ISSUER}" ]]; then
            printf "\nThe specified command requires additional parameters. Please see --help" >&2
            echo .&2
            command_help >&2
            exit 1
        fi
        create_server
    elif [ "${CMD}" == "client" ]; then
        if [[  -z "${SUBJECT}" || -z "${ISSUER}" ]]; then
            printf "\nThe specified command requires additional parameters. Please see --help" >&2
            echo .&2
            command_help >&2
            exit 1
        fi
        create_client
    fi
}

command_help() {
    printf "\nUsage: --help\n"
    printf "Usage: --rootca\t--subject <subject name> [--encrypt]\n"
    printf "Usage: --subca\t--subject <subject name> --issuer <issuer name> [--bundle <bundle file>] [--encrypt]\n"
    printf "Usage: --server\t--subject <subject name> --issuer <issuer name>\n"
    printf "Usage: --client\t--subject <subject name> --issuer <issuer name>\n\n"
    printf "Parameters:\n"
    printf " --help: Print this help information\n"
    printf " --rootca: Create a Root CA certificate\n\t[required] --subject <subject name>\n\t[optional] --encrypt (default: no)\n"
    printf " --subca: Create a Subordinate CA certificate\n\t[required] --subject <subject name>\n\t[required] --issuer <issuer name>\n\t[optional] --bundle <bundle file>\n\t[optional] --encrypt (default: no)\n"
    printf " --server: Create a TLS server certificate\n\t[required] --subject <subject name>\n\t[required] --issuer <issuer name>\n"
    printf " --client: Create a TLS client certificate\n\t[required] --subject <subject name>\n\t[required] --issuer <issuer name>\n"
}

main() {
    while (( ${#} )); do
        case "${1}" in
            --help)
                ## Show help
                command_help >&2
                exit 0
                ;;

            --issuer)
                ## Set --issuer option
                shift 1
                if [[ -z "${1:-}" ]]; then
                    printf "\nThe specified command requires additional parameters. Please see --help" >&2
                    echo .&2
                    command_help >&2
                    exit 1
                fi
                ISSUER="${1}"
                ;;

            --subject)
                ## Set --subject option
                shift 1
                if [[ -z "${1:-}" ]]; then
                    printf "\nThe specified command requires additional parameters. Please see --help" >&2
                    echo >&2
                    command_help >&2
                    exit 1
                fi
                SUBJECT="${1}"
                ;;

            --bundle)
                ## Set bundle option
                shift 1
                if [[ -z "${1:-}" ]]; then
                    printf "\nThe specified command requires additional parameters. Please see --help" >&2
                    echo >&2
                    command_help >&2
                    exit 1
                fi
                BUNDLE="${1}"
                ;;

            --encrypt)
                ENCRYPT=1
                ;;

            --rootca)
                ## Launch rootca function
                CMD="rootca"
                ;;

            --subca)
                ## Launch subca function
                CMD="subca"
                ;;

            --server)
                ## launch server function
                CMD="server"
                ;;

            --client)
                ## Launch client function
                CMD="client"
                ;;
            
            *)
                ## Default if no arguments supplied
                printf "\n${0} requires parameters. Please see --help" >&2
                echo >&2
                command_help >&2
                exit 1
                ;;
        esac
    shift 1
    done

    process_handler
}

main "${@:-}"
EOF

# Make makecerts script executable
RUN chmod +x /usr/local/bin/makecerts

# Create a set of certs in /opt/ssl/certs
WORKDIR /opt/ssl/certs
RUN /usr/local/bin/makecerts --rootca --subject internal-rootca
RUN /usr/local/bin/makecerts --subca --subject internal-subca --issuer internal-rootca --bundle cabundle
RUN /usr/local/bin/makecerts --server --subject internal-tls-server --issuer internal-subca
RUN /usr/local/bin/makecerts --client --subject internal-tls-client-user1 --issuer internal-subca

# Copy website files
WORKDIR /var/www/site/html
COPY webserver ./

# Create nginx.conf
#    80=HTTP with travel site
#   443=HTTPS with travel site
#   444=HTTPS w/PQC and static response showing negotiated TLS
RUN <<"EOF" cat > /opt/nginx/nginx.conf
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
        ssl_certificate         /opt/ssl/certs/internal-tls-server.crt;
        ssl_certificate_key     /opt/ssl/certs/internal-tls-server.key;
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
        ssl_certificate         /opt/ssl/certs/internal-tls-server.crt;
        ssl_certificate_key     /opt/ssl/certs/internal-tls-server.key;
        ssl_protocols           TLSv1.3;
        ssl_ecdh_curve          X25519MLKEM768;

        location / {
            default_type text/html;
            return 200 "<html><head><title>PQC Test Success!</title></head><body><H2>PQC Test Success!</H1><p><b>Negotiated Protocol</b>: \$ssl_protocol </p><p><b>Negotiated Cipher</b>: \$ssl_cipher </p><p><b>Negotiated Curve</b>: \$ssl_curve </p><p><b>Supported Curves</b>: \$ssl_curves </p></body></html>";
        }
    }
    server {
        listen                  0.0.0.0:445 ssl;
        ssl_certificate         /opt/ssl/certs/internal-tls-server.crt;
        ssl_certificate_key     /opt/ssl/certs/internal-tls-server.key;
        location / {
                set $juiceshop_host "utility-juiceshop";
                proxy_pass http://$juiceshop_host:3000/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $remote_addr;
                proxy_set_header X-Forwared-Proto $scheme;
                proxy_buffering off;
                proxy_redirect off;
        }
    }
    server {
	    listen			        0.0.0.0:446 ssl;
	    ssl_certificate         /opt/ssl/certs/internal-tls-server.crt;
        ssl_certificate_key     /opt/ssl/certs/internal-tls-server.key;
	    ssl_client_certificate	/opt/ssl/certs/cabundle.pem;
	    ssl_verify_client on;
	    ssl_verify_depth 2;

	    location / {
            default_type text/html;
            return 200 "<html><head><title>mTLS Test Success!</title></head><body><H2>mTLS Test Success!</H1><p><b>Negotiated Protocol</b>: $ssl_protocol </p><p><b>Negotiated Cipher</b>: $ssl_cipher </p><p><b>Client Certificate Subject</b>: $ssl_client_s_dn</p><p><b>Client Certificate Issuer</b>: $ssl_client_i_dn</p><p><b>Client Certificate Serial</b>: $ssl_client_serial</p><p><b>Client Certificate Fingerprint</b>: $ssl_client_fingerprint</p></body></html>";
    	}
    }
}
EOF

# Delete /build folder
RUN rm -rf /build

# Start daemon on container run
CMD ["nginx", "-g", "daemon off;"]
