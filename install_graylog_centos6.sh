#!/bin/bash
#
# Instala Graylog Sidecar 1.5.1 em CentOS 6.x
# Compatível com ambientes legados (init.d + yum)
#

### CONFIGURAÇÕES EDITÁVEIS ###
API_TOKEN="19mbsfghp14p6qfhumnn0j2gpd7ufrbd7j15ncccsk0n7lslmncv"
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
echo "[1/8] Importando chave GPG do Elasticsearch..."
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

### INSTALA REPO DO SIDECAR ###
echo "[2/8] Instalando repositório Graylog Sidecar..."
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-sidecar-repository-1-5.noarch.rpm

### REMOVE SIDECAR ANTIGO ###
echo "[3/8] Removendo Sidecar antigo..."
yum remove collector-sidecar -y >/dev/null 2>&1

pkill -f /usr/bin/graylog-collector-sidecar
pkill -f /usr/bin/filebeat

### CONFIGURA REPO DO ELASTIC 7.x ###
echo "[4/8] Configurando repo Elastic 7.x..."
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
echo "[5/8] Instalando Filebeat..."
yum install filebeat -y

### INSTALA SIDECAR NOVO ###
echo "[6/8] Instalando Graylog Sidecar..."
yum install graylog-sidecar.x86_64 -y

### CRIA SERVIÇO INIT.D ###
echo "[7/8] Criando serviço /etc/init.d/graylog-sidecar..."

cat >/etc/init.d/graylog-sidecar <<'EOF'
#!/bin/bash
# chkconfig: 2345 95 05
# description: Graylog Sidecar 1.5.x service
# processname: graylog-sidecar
BIN="/usr/bin/graylog-sidecar"
PIDFILE="/var/run/graylog-sidecar.pid"
LOGFILE="/var/log/graylog-sidecar.log"

start() {
    echo "Starting Graylog Sidecar..."
    nohup $BIN -c /etc/graylog/sidecar/sidecar.yml >> $LOGFILE 2>&1 &
    echo $! > $PIDFILE
    echo "OK"
}

stop() {
    echo "Stopping Graylog Sidecar..."
    kill $(cat $PIDFILE) 2>/dev/null
    rm -f $PIDFILE
    echo "OK"
}

status() {
    if [ -f $PIDFILE ]; then
        echo "Running (PID $(cat $PIDFILE))"
    else
        echo "Not running"
        exit 1
    fi
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    status) status ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
EOF

chmod +x /etc/init.d/graylog-sidecar
chkconfig graylog-sidecar on

### CONFIGURA SIDECAR.YML ###
echo "[8/8] Gerando /etc/graylog/sidecar/sidecar.yml…"

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

### INICIA SERVIÇO ###
service graylog-sidecar restart

echo
echo "=========================================================="
echo " Sidecar instalado com sucesso!"
echo " Node ID configurado como: ${NODE_ID}"
echo " Verifique em:"
echo "   Graylog → System → Sidecars → Online"
echo "=========================================================="
