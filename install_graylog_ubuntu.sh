#!/bin/bash
#
# Instala Graylog Sidecar 1.5.x em Debian / Ubuntu
# Método validado em ambiente corporativo (proxy / SSL inspection)
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
echo " Instalando Graylog Sidecar 1.5.x"
echo " Host: $(hostname)"
echo "=========================================================="

### PASSO 1: Atualiza APT ###
echo "[1/9] Atualizando índices do APT..."
apt-get update -y


### PASSO 2: Chave + Repositório Elastic (Filebeat 7.x) ###
echo "[2/9] Configurando repositório Elastic 7.x..."

if [ ! -f /usr/share/keyrings/elastic-archive-keyring.gpg ]; then
  curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg
fi

cat >/etc/apt/sources.list.d/elastic-7.x.list <<EOF
deb [signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main
EOF

apt-get update -y


### PASSO 3: Remove resíduos de Sidecar antigo ###
echo "[3/9] Removendo Sidecar antigo (se existir)..."
systemctl stop graylog-collector-sidecar.service 2>/dev/null || true
apt-get remove -y collector-sidecar 2>/dev/null || true
pkill -f graylog-collector-sidecar 2>/dev/null || true
pkill -f filebeat 2>/dev/null || true


### PASSO 4: Instala Filebeat ###
echo "[4/9] Instalando Filebeat..."
apt-get install -y filebeat


### PASSO 5: Instala repositório do Graylog Sidecar (FORMA CORRETA) ###
echo "[5/9] Instalando repositório do Graylog Sidecar..."

SIDECAR_REPO_DEB="/tmp/graylog-sidecar-repository_1-5_all.deb"

if ! dpkg -l | grep -q graylog-sidecar-repository; then
  wget -O "$SIDECAR_REPO_DEB" \
    https://packages.graylog2.org/repo/packages/graylog-sidecar-repository_1-5_all.deb

  dpkg -i "$SIDECAR_REPO_DEB" || apt-get install -f -y
fi

apt-get update -y


### PASSO 6: Instala Graylog Sidecar ###
echo "[6/9] Instalando Graylog Sidecar..."
apt-get install -y graylog-sidecar


### PASSO 7: Gera configuração do Sidecar ###
echo "[7/9] Gerando /etc/graylog/sidecar/sidecar.yml..."

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


### PASSO 8: Ativa e inicia serviço ###
echo "[8/9] Ativando e iniciando Graylog Sidecar..."
graylog-sidecar -service install
systemctl daemon-reload
systemctl enable graylog-sidecar
systemctl restart graylog-sidecar


### PASSO 9: Validação ###
echo "[9/9] Verificando serviço..."
systemctl --no-pager --full status graylog-sidecar || true

echo
echo "=========================================================="
echo " ✔ Graylog Sidecar instalado com sucesso"
echo " ✔ Node ID: ${NODE_ID}"
echo " ✔ Verifique em: Graylog → System → Sidecars"
echo "=========================================================="
