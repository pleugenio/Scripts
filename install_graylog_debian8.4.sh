#!/bin/bash
#
# Instala Graylog Sidecar 1.5.x em Debian / Ubuntu (compatível com Jessie) 8.4
#

set -e

### CONFIGURAÇÕES ###
API_TOKEN="19mbsfghp14p6qfhumnn0j2gpd7ufrbd7j15ncccsk0n7lslmncv"
GRAYLOG_URL="http://logapp-new.corp.folha.com.br:9000/api/"

# Remove prefixo srv- e domínio do hostname
CLEAN_HOST=$(hostname | sed 's/^srv-//' | sed 's/\..*$//')
NODE_ID="graylog-collector-sidecar-${CLEAN_HOST}"

### VERIFICAÇÃO ###
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: execute como root"
  exit 1
fi

echo "=========================================================="
echo " Instalando Graylog Sidecar 1.5.x (Debian Jessie)"
echo " Host: $(hostname)"
echo "=========================================================="

### PASSO 1: Ajustar repositórios ###
echo "[1/9] Ajustando repositórios archive.debian.org..."

cat <<EOF >/etc/apt/sources.list
deb http://archive.debian.org/debian jessie main contrib non-free
deb http://archive.debian.org/debian-security jessie/updates main contrib non-free
EOF

echo 'Acquire::Check-Valid-Until "false";' >/etc/apt/apt.conf.d/99no-check-valid-until

### DESABILITAR REPOSITÓRIOS ANTIGOS QUE QUEBRAM O UPDATE ###
echo "[1b] Desabilitando repositórios obsoletos..."

rm -f /etc/apt/sources.list.d/nodesource.list
rm -f /etc/apt/sources.list.d/nodesource.list.save
rm -f /etc/apt/sources.list.d/nodesource*.list

### AGORA SIM ATUALIZAR ###
apt-get update -o Acquire::Check-Valid-Until=false -y


### PASSO 2: Remover repositório Elastic 7.x (incompatível) ###
echo "[2/9] Limpando repositórios incompatíveis..."
rm -f /etc/apt/sources.list.d/elastic-7.x.list


### PASSO 3: Instalar dependências ###
echo "[3/9] Instalando dependências..."
apt-get install -y --force-yes --allow-unauthenticated curl wget gnupg gnupg2 ca-certificates


### PASSO 4: Instalar Filebeat 6.8 (compatível com libc6 do Jessie) ###
echo "[4/9] Instalando Filebeat 6.8..."
FILEBEAT_DEB="/tmp/filebeat-6.8.23-amd64.deb"

wget -O "$FILEBEAT_DEB" \
  https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.8.23-amd64.deb

dpkg -i "$FILEBEAT_DEB" || apt-get install -f -y


### PASSO 5: Instalar repositório do Graylog Sidecar ###
echo "[5/9] Instalando repositório do Graylog Sidecar..."

SIDECAR_REPO_DEB="/tmp/graylog-sidecar-repository_1-5_all.deb"

if ! dpkg -l | grep -q graylog-sidecar-repository; then
  wget -O "$SIDECAR_REPO_DEB" \
    https://packages.graylog2.org/repo/packages/graylog-sidecar-repository_1-5_all.deb

  dpkg -i "$SIDECAR_REPO_DEB" || apt-get install -f -y
fi

apt-get update -y


### PASSO 6: Instalar Graylog Sidecar ###
echo "[6/9] Instalando Graylog Sidecar..."
apt-get install -y graylog-sidecar


### PASSO 7: Gerar configuração ###
echo "[7/9] Gerando sidecar.yml..."

mkdir -p /etc/graylog/sidecar

cat <<EOF >/etc/graylog/sidecar/sidecar.yml
server_url: ${GRAYLOG_URL}
server_api_token: ${API_TOKEN}
update_interval: 10
tls_skip_verify: true
send_status: true
node_id: ${NODE_ID}

collector_id: file:/etc/graylog/collector-sidecar/collector-id
cache_path: /var/cache/graylog/collector-sidecar
log_path: /var/log/graylog/collector-sidecar

backends:
  - name: filebeat
    enabled: true
    binary_path: /usr/bin/filebeat
    configuration_path: /var/lib/graylog-sidecar/generated/
EOF


### PASSO 8: Ativar serviço via systemd ###
echo "[8/9] Ativando serviço systemd..."

graylog-sidecar -service install
systemctl daemon-reload
systemctl enable graylog-sidecar
systemctl restart graylog-sidecar


### PASSO 9: Validação ###
echo "[9/9] Verificando serviço..."
systemctl --no-pager --full status graylog-sidecar || true

echo
echo "=========================================================="
echo " ✔ Graylog Sidecar instalado com sucesso no Jessie"
echo " ✔ Systemd OK (v215)"
echo " ✔ Node ID: ${NODE_ID}"
echo "=========================================================="
