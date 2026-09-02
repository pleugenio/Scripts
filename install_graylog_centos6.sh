#!/bin/bash
#
# Instala Graylog Sidecar 1.5.x em CentOS 6.x
# Compatível com ambientes legados (Upstart + yum)
#
# CORRIGIDO: nao cria mais /etc/init.d/graylog-sidecar manual nem chkconfig on.
# O pacote graylog-sidecar.x86_64 ja registra seu proprio job Upstart
# (/etc/init/graylog-sidecar.conf, com respawn automatico) - criar um
# segundo mecanismo por cima disso e' o que causava dois processos
# brigando pelo mesmo binario apos cada boot/respawn.
#

### CONFIGURAÇÕES EDITÁVEIS ###
API_TOKEN="1mmcmemahqs1l2iokb7dhrl3hvacc9gnr4qdbr9fv5u67bdlhdm8"
GRAYLOG_URL="http://logapp-new.corp.folha.com.br:9000/api/"

# Remove prefixo srv- e remove todo domínio após o primeiro ponto
CLEAN_HOST=$(hostname | sed 's/^srv-//' | sed 's/\..*$//')
NODE_ID="graylog-collector-sidecar-${CLEAN_HOST}"


### VERIFICAÇÕES ###
if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute como root."
    exit 1
fi

echo "=== Instalação do Graylog Sidecar 1.5.x para CentOS 6.x ==="
sleep 1

### IMPORTA CHAVE DO ELASTIC ###
echo "[1/7] Importando chave GPG do Elasticsearch..."
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

### INSTALA REPO DO SIDECAR ###
echo "[2/7] Instalando repositório Graylog Sidecar..."
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-sidecar-repository-1-5.noarch.rpm

### REMOVE SIDECAR ANTIGO ###
echo "[3/7] Removendo Sidecar antigo (se houver)..."
yum remove collector-sidecar -y >/dev/null 2>&1
initctl stop graylog-sidecar >/dev/null 2>&1
pkill -f /usr/bin/graylog-collector-sidecar 2>/dev/null
pkill -f /usr/bin/filebeat 2>/dev/null

### CONFIGURA REPO DO ELASTIC 7.x ###
echo "[4/7] Configurando repo Elastic 7.x..."
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
yum install filebeat -y

### INSTALA SIDECAR NOVO ###
echo "[6/7] Instalando Graylog Sidecar (ja registra o job Upstart proprio)..."
yum install graylog-sidecar.x86_64 -y

### CONFIGURA SIDECAR.YML ###
echo "[7/7] Gerando /etc/graylog/sidecar/sidecar.yml…"

cat >/etc/graylog/sidecar/sidecar.yml <<EOF
server_url: ${GRAYLOG_URL}
server_api_token: ${API_TOKEN}
update_interval: 10
tls_skip_verify: true
send_status: true
node_id: ${NODE_ID}
collector_id: file:/etc/graylog/collector-sidecar/collector-id
cache_path: /var/cache/graylog/collector-sidecar
log_path: /var/log/graylog/collector-sidecar
log_rotation_time: 86400
log_max_age: 604800
backends:
  - name: filebeat
    enabled: true
    binary_path: /usr/bin/filebeat
    configuration_path: /var/lib/graylog-sidecar/generated/
EOF

### INICIA SERVIÇO (via Upstart do proprio pacote, sem init.d manual) ###
initctl start graylog-sidecar 2>&1 || initctl restart graylog-sidecar 2>&1

echo
echo "=========================================================="
echo " Sidecar instalado com sucesso!"
echo " Node ID configurado como: ${NODE_ID}"
echo " Gerenciado via Upstart (initctl start/stop/status graylog-sidecar)"
echo " Verifique em:"
echo "   Graylog → System → Sidecars → Online"
echo "=========================================================="
initctl status graylog-sidecar
