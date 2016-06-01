#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

# Env says we're using SSL
if [ -n "${ENABLE_SSL+1}" ] && [ "${ENABLE_SSL,,}" = "true" ]; then
  echo "Enabling SSL..."
  cp /usr/src/proxy_ssl.conf /etc/nginx/conf.d/proxy.conf
  cp /usr/src/default_ssl.conf /etc/nginx/conf.d/default.conf
else
  # No SSL
  cp /usr/src/proxy_nossl.conf /etc/nginx/conf.d/proxy.conf
  cp /usr/src/default_nossl.conf /etc/nginx/conf.d/default.conf
fi

# If an htpasswd file is provided, download and configure nginx
if [ -n "${ENABLE_BASIC_AUTH+1}" ] && [ "${ENABLE_BASIC_AUTH,,}" = "true" ]; then
  echo "Enabling basic auth..."
   sed -i "s/#auth_basic/auth_basic/g;" /etc/nginx/conf.d/proxy.conf
fi

# If the SERVICE_HOST_ENV_NAME and SERVICE_PORT_ENV_NAME vars are provided,
# they point to the env vars set by Kubernetes that contain the actual
# target address and port. Override the default with them.
if [ -n "${SERVICE_HOST_ENV_NAME+1}" ]; then
  TARGET_SERVICE=${!SERVICE_HOST_ENV_NAME}
fi
if [ -n "${SERVICE_PORT_ENV_NAME+1}" ]; then
  TARGET_SERVICE="$TARGET_SERVICE:${!SERVICE_PORT_ENV_NAME}"
fi

if [ -n "${PROV_SERVICE_HOST_ENV_NAME+1}" ]; then
  PROV_SERVICE=${!PROV_SERVICE_HOST_ENV_NAME}
fi

if [ -n "${PROV_SERVER_NAME+1}" ]; then
  cp /usr/src/prov.conf /etc/nginx/conf.d/prov.conf
  sed -i "s/{{PROV_SERVER_NAME}}/${PROV_SERVER_NAME}/g;" /etc/nginx/conf.d/prov.conf
fi


if [ -n "${PROV_SERVICE+1}" ]; then
  sed -i "s/{{PROV_SERVICE}}/${PROV_SERVICE}/g;" /etc/nginx/conf.d/prov.conf
  sed -i "s/#provservice# //g" /etc/nginx/conf.d/prov.conf
fi

# If the CERT_SERVICE_HOST_ENV_NAME and CERT_SERVICE_PORT_ENV_NAME vars
# are provided, they point to the env vars set by Kubernetes that contain the
# actual target address and port of the encryption service. Override the
# default with them.
if [ -n "${CERT_SERVICE_HOST_ENV_NAME+1}" ]; then
  CERT_SERVICE=${!CERT_SERVICE_HOST_ENV_NAME}
fi
if [ -n "${CERT_SERVICE_PORT_ENV_NAME+1}" ]; then
  CERT_SERVICE="$CERT_SERVICE:${!CERT_SERVICE_PORT_ENV_NAME}"
fi

if [ -n "${CERT_SERVICE+1}" ]; then
    # Tell nginx the address and port of the certification service.
    sed -i "s/{{CERT_SERVICE}}/${CERT_SERVICE}/g;" /etc/nginx/conf.d/proxy.conf
    sed -i "s/#letsencrypt# //g;" /etc/nginx/conf.d/proxy.conf
fi

if [ -n "${WEB_SOCKETS+1}" ]; then
    sed -i "s/#websockets# //g;" /etc/nginx/conf.d/proxy.conf
fi

# Tell nginx the address and port of the service to proxy to
sed -i "s|{{TARGET_SERVICE}}|${TARGET_SERVICE}|" /etc/nginx/conf.d/proxy.conf

# Tell nginx the name of the service
sed -i "s/{{SERVER_NAME}}/${SERVER_NAME}/g;" /etc/nginx/conf.d/proxy.conf

echo "Listing /etc/nginx/conf.d"
ls -al /etc/nginx/conf.d
cat /etc/nginx/conf.d/prov.conf
echo "Starting nginx..."
nginx -g 'daemon off;'
