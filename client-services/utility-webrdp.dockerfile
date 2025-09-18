ARG VERSION="1.6.0"

# Ref: https://github.com/flcontainers/guacamole/blob/main/README.md

# Use same Alpine version as the base for the runtime image
FROM guacamole/guacd:${VERSION}

ARG PREFIX_DIR=/opt/guacamole
ARG VERSION
ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2025-07-07T23:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Fully Packaged and Multi-Arch Guacamole container"
ARG PACKAGE="flcontainers/guacamole"

LABEL org.opencontainers.image.ref.name="${PACKAGE}" \
  org.opencontainers.image.created=$BUILD_RFC3339 \
  org.opencontainers.image.authors="MaxWaldorf" \
  org.opencontainers.image.documentation="https://github.com/${PACKAGE}/README.md" \
  org.opencontainers.image.description="${DESCRIPTION}" \
  org.opencontainers.image.licenses="GPLv3" \
  org.opencontainers.image.source="https://github.com/${PACKAGE}" \
  org.opencontainers.image.revision=$REVISION \
  org.opencontainers.image.version=$VERSION \
  org.opencontainers.image.url="https://hub.docker.com/r/${PACKAGE}/"

ENV \
  GUAC_VER=${VERSION} \
  GUACAMOLE_HOME=/app/guacamole \
  CATALINA_HOME=/opt/tomcat \
  PG_MAJOR=13 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db

# Runtime environment
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info
ENV TZ=UTC

# Set working DIR
USER root
RUN mkdir -p /config
RUN mkdir -p ${GUACAMOLE_HOME}/extensions ${GUACAMOLE_HOME}/extensions-available ${GUACAMOLE_HOME}/lib
RUN mkdir /docker-entrypoint-initdb.d
WORKDIR ${GUACAMOLE_HOME}

# Bring runtime environment up to date and install runtime dependencies
RUN apk add --no-cache                \
        bash                          \
        bash-completion               \
        ca-certificates               \
        curl                          \
        ghostscript                   \
        netcat-openbsd                \
        openjdk11-jdk                 \
        postgresql${PG_MAJOR}         \
        pwgen                         \
        shadow                        \
        supervisor                    \
        terminus-font                 \
        ttf-dejavu                    \
        ttf-liberation                \
        tzdata                        \
        util-linux-login && \
    xargs apk add --no-cache < ${PREFIX_DIR}/DEPENDENCIES

RUN apk add --no-cache -X https://dl-cdn.alpinelinux.org/alpine/edge/community gosu

RUN chown guacd:guacd -R ${PREFIX_DIR}

# Install tomcat (robust TOMCAT_VER extraction)
RUN mkdir -p ${CATALINA_HOME} && \
    export TOMCAT_VER=$(curl -s https://dlcdn.apache.org/tomcat/tomcat-9/ \
      | grep -Eo 'v9\.[0-9]+\.[0-9]+/' \
      | sed 's|/||' | sed 's|v||' \
      | sort -V | tail -n1) && \
    echo "Latest Tomcat version: $TOMCAT_VER" && \
    curl -SLo /tmp/apache-tomcat.tar.gz "https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz" && \
    tar xvzf /tmp/apache-tomcat.tar.gz --strip-components 1 --directory ${CATALINA_HOME} && \
    chmod +x ${CATALINA_HOME}/bin/*.sh

RUN groupadd tomcat && \
useradd -s /bin/false -g tomcat -d ${CATALINA_HOME} tomcat

RUN chgrp -R tomcat ${CATALINA_HOME} && \
chmod -R g+r ${CATALINA_HOME}/conf && \
chmod g+x ${CATALINA_HOME}/conf && \
chown -R tomcat ${CATALINA_HOME}/webapps/ ${CATALINA_HOME}/work/ ${CATALINA_HOME}/temp/ ${CATALINA_HOME}/logs/ && \
chmod 777 -R ${CATALINA_HOME}/logs/

# Install guacamole-client and postgres auth adapter
RUN set -x \
  && rm -rf ${CATALINA_HOME}/webapps/ROOT \
  && curl -SLo ${CATALINA_HOME}/webapps/ROOT.war "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.7.7.jar "https://jdbc.postgresql.org/download/postgresql-42.7.7.jar" \
  && curl -SLo ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-auth-jdbc-${GUAC_VER}.tar.gz" \
  && tar -xzf ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz \
  && cp -R ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions/ \
  && cp -R ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/postgresql/schema ${GUACAMOLE_HOME}/ \
  && rm -rf ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER} ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz

###############################################################################
################################# EXTENSIONS ##################################
###############################################################################

# Download all extensions
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  curl -SLo ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${ext_name}-${GUAC_VER}.tar.gz" \
  && tar -xzf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

# Copy standalone extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-json auth-ldap auth-quickconnect auth-totp history-recording-storage; do \
  cp ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}/guacamole-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy SSO extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in openid saml cas; do \
  cp ${GUACAMOLE_HOME}/guacamole-auth-sso-${GUAC_VER}/${ext_name}/guacamole-auth-sso-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy JDBC extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in mysql postgresql sqlserver; do \
  cp ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/${ext_name}/guacamole-auth-jdbc-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy vault extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in ksm; do \
  cp ${GUACAMOLE_HOME}/guacamole-vault-${GUAC_VER}/${ext_name}/guacamole-vault-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Clear all extensions leftovers
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  rm -rf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER} ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

###############################################################################
###############################################################################
###############################################################################

# Finishing Container configuration
RUN chown tomcat:tomcat -R ${GUACAMOLE_HOME}

ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole
ENV CATALINA_PID=/tmp/tomcat.pid
ENV POSTGRES_PID=/config/postgresql/postmaster.pid
ENV GUACD_PID=/tmp/guacd.pid

# Copy files
COPY guacamole/filefs /
RUN chmod +x /usr/local/bin/*.sh
RUN chmod +x /startup.sh

# Copy Scripts
COPY guacamole/scripts/tomcat ${CATALINA_HOME}/bin
RUN chown tomcat:tomcat ${CATALINA_HOME}/bin/wrapper_supervisor.sh
RUN chmod +x ${CATALINA_HOME}/bin/wrapper_supervisor.sh

COPY guacamole/scripts/guacd ${PREFIX_DIR}
RUN chown guacd:guacd ${PREFIX_DIR}/wrapper_supervisor.sh
RUN chmod +x ${PREFIX_DIR}/wrapper_supervisor.sh

RUN mkdir -p /scripts/postgres
RUN chmod 755 -R /scripts
COPY guacamole/scripts/postgres /scripts/postgres
RUN chown postgres:postgres -R /scripts/postgres
RUN chmod +x /scripts/postgres/wrapper_supervisor.sh

# Prepare logs folder for supervisor
RUN mkdir -p /var/log/supervisor
RUN chmod 755 -R /var/log/supervisor

# Stop Signal type
STOPSIGNAL SIGTERM

EXPOSE 8080

# Create Passgen utility to create Guacamole user password hash
RUN <<"EOF" cat > /passgen.py
import sys
from hashlib import sha256

def main():
    if len(sys.argv) < 2:
        exit(1)
    else:
        password = sys.argv[1]
        password_salt = bytes.fromhex('')
        password_hash = sha256(password.encode() + password_salt.hex().upper().encode())
        print(password_hash.hexdigest().upper())

if __name__ == "__main__":
    main()
EOF

# Create specialized _post_startup.sh script that auto-generates a new initdb.sql on container startup
RUN <<"EOF" cat > /usr/local/bin/_post_startup.sh
#!/bin/sh

# Wait for postgres to be ready
while ! nc -z localhost 5432; do
echo "Guacamole client waiting for DB"   
sleep 5
done

echo "database port open... Finishing Configuration"

# Create database if it does not exist
if [ -f "/config/db_check/.database-version" ]; then
  if [ "$(cat /config/db_check/.database-version)" != "$GUAC_VER" ]; then
    if [ -f "/app/guacamole/schema/upgrade/upgrade-pre-$GUAC_VER.sql" ]; then
    cat /app/guacamole/schema/upgrade/upgrade-pre-$GUAC_VER.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
    echo "$GUAC_VER" > /config/db_check/.database-version
    echo "guacamole database updated to $GUAC_VER"
    fi
  else
    echo "guacamole database already up-to-date. Nothing applied..."
  fi
else
  cat /app/guacamole/schema/*.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
  echo "$GUAC_VER" > /config/db_check/.database-version
fi

# Get password hash
PASSHASH=$(python /passgen.py $ARG_GUAC_PASS)
echo "$ARG_GUAC_PASS password hash is: $PASSHASH"

# Create new initdb.sql
echo "Generating initdb.sql"
echo "/* Delete all existing records */" > /config/db_check/initdb.sql
echo "DELETE FROM guacamole_connection_permission;" >> /config/db_check/initdb.sql
echo "DELETE FROM guacamole_connection_parameter;" >> /config/db_check/initdb.sql
echo "DELETE FROM guacamole_entity WHERE name != 'guacadmin';" >> /config/db_check/initdb.sql
echo "" >> /config/db_check/initdb.sql
echo "/* Create the RDP connection */" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection (connection_name, protocol) SELECT 'client', 'rdp' WHERE NOT EXISTS (SELECT 1 FROM guacamole_connection WHERE connection_name = 'client');" >> /config/db_check/initdb.sql
echo "" >> /config/db_check/initdb.sql
echo "/* Create RDP connection */" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'hostname', '$ARG_RDP_HOST' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'port', '$ARG_RDP_PORT' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'username', '$ARG_RDP_USER' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'password', '$ARG_RDP_PASS' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'security', 'any' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'ignore-cert', 'true' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'enable-wallpaper', 'true' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'enable-theming', 'true' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT connection_id, 'normalize-clipboard', 'preserve' FROM guacamole_connection WHERE connection_name = 'client' AND parent_id IS NULL;" >> /config/db_check/initdb.sql
echo "" >> /config/db_check/initdb.sql
echo "/* Create Guacamole user login */" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_entity (name, type) VALUES ('$ARG_GUAC_USER','USER');" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date) SELECT entity_id, decode('$PASSHASH', 'hex'), NULL, CURRENT_TIMESTAMP FROM guacamole_entity WHERE name = '$ARG_GUAC_USER' and guacamole_entity.type = 'USER';" >> /config/db_check/initdb.sql
echo "" >> /config/db_check/initdb.sql
echo "/* Add Guacamole user to RDP connection */" >> /config/db_check/initdb.sql
echo "INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission) SELECT guacamole_entity.entity_id, guacamole_connection.connection_id, 'READ' FROM guacamole_entity INNER JOIN guacamole_connection ON guacamole_entity.name = '$ARG_GUAC_USER' and guacamole_entity.type = 'USER' AND guacamole_connection.connection_name = 'client';" >> /config/db_check/initdb.sql

# Run initdb.sql
echo "Loading initdb.sql with provided user/host data"
psql -d postgres -U guacamole -d guacamole_db -f /config/db_check/initdb.sql
EOF

RUN chmod +x /usr/local/bin/_post_startup.sh

WORKDIR /config

# Set the entrypoint
ENTRYPOINT ["/startup.sh"]
