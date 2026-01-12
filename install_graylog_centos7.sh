#!/bin/bash
#
# Instala Graylog Sidecar 1.5.x em CentOS 7
#

### CONFIGURAÇÕES ###
API_TOKEN="19mbsfghp14p6qfhumnn0j2gpd7ufrbd7j15ncccsk0n7lslmncv"
GRAYLOG_URL="http://logapp-new.corp.folha.com.br:9000/api/"

# Remove prefixo srv- e remove domínio
CLEAN_HOST=$(hostname | sed 's/^srv-//' | sed 's/\..*$//')
NODE_ID="graylog-collector-sidecar-${CLEAN_HOST}"

### VERIFICAÇÃO ###
if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute como root"
    exit 1
fi

echo "=== Instalando Graylog Sidecar 1.5.x no CentOS 7 ==="


### IMPORTA CHAVE ELASTICSEARCH ###
echo "[1/7] Importando chave GPG do Elasticsearch..."
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch


### INSTALA O REPO DO SIDECAR ###
echo "[2/7] Instalando repositório Graylog..."
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-sidecar-repository-1-5.noarch.rpm


### REMOVE SIDECAR ANTIGO ###
echo "[3/8] Removendo Sidecar antigo..."
yum remove collector-sidecar* -y >/dev/null 2>&1

pkill -f /usr/bin/graylog-collector-sidecar
pkill -f /usr/bin/filebeat


### CRIA O REPO DO ELASTIC 7.x ###
echo "[4/7] Configurando Elastic 7.x..."
cat >/etc/yum.repos.d/elastic-7.x.repo <<EOF
[elastic-7.x]
name=Elastic repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
enabled=1
autorefresh=1
type=rpm-md
EOF


### INSTALA FILEBEAT ###
echo "[5/7] Instalando Filebeat..."
yum install -y filebeat


### INSTALA SIDECAR ###
echo "[6/7] Instalando Graylog Sidecar..."
yum install -y graylog-sidecar


### GERA CONFIGURAÇÃO DO SIDECAR.YML ###
echo "[7/7] Gerando /etc/graylog/sidecar/sidecar.yml…"

mkdir -p /etc/graylog/sidecar

cat >/etc/graylog/sidecar/sidecar.yml <<EOF
server_url: ${GRAYLOG_URL}
server_api_token: ${API_TOKEN}
update_interval: 10
tls_skip_verify: false
send_status: true
node_id: ${NODE_ID}
collector_id: file:/etc/graylog/collector-sidecar/collector-id
cache_path: /var/cache/graylog/collector-sidecar
log_path: /var/log/graylog/collector-sidecar
log_rotation_time: 86400
log_max_age: 604800
tags:
  - k8s
backends:
  - name: filebeat
    enabled: true
    binary_path: /usr/bin/filebeat
    configuration_path: /var/lib/graylog-sidecar/generated/
EOF


### INSTALA O SERVIÇO SYSTEMD AUTOMATICAMENTE ###
echo "Instalando serviço systemd via graylog-sidecar..."
graylog-sidecar -service install


### ATIVA E INICIA ###
echo "Ativando e iniciando serviço..."
systemctl enable graylog-sidecar
systemctl restart graylog-sidecar


echo
echo "=========================================================="
echo " Sidecar instalado com sucesso!"
echo " Node ID usado: ${NODE_ID}"
echo " Servidor aparece no Graylog 7 em:"
echo "   System → Sidecars → Online"
echo "=========================================================="
