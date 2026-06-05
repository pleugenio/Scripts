#!/bin/bash
set -e

##############################################
# VARIÁVEIS
##############################################
ZABBIX_SERVERS="10.20.13.136,10.20.13.138,10.20.13.139,10.20.13.168,10.20.13.179,10.20.13.180"
ZABBIX_SERVER_ACTIVE="10.20.13.136"

##############################################

echo "================================================="
echo " Instalando Zabbix Agent 7 - XCP-ng 8.2 (EL7)"
echo "================================================="

# Remover agente antigo (se existir)
echo "Removendo versoes antigas (se houver)..."
systemctl stop zabbix-agent 2>/dev/null || true
yum remove -y zabbix-agent zabbix-agent2 zabbix-release 2>/dev/null || true
rm -rf /etc/zabbix /var/log/zabbix 2>/dev/null || true

# Instalar repositório Zabbix 7 para EL7
echo "Instalando repositorio Zabbix 7..."
yum install -y https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-7.0-1.el7.noarch.rpm

# Limpar cache yum
yum clean all

# Instalar dependência pcre2 (requerida pelo zabbix-agent 7.x no EL7)
echo "Instalando dependencia pcre2..."
if ! yum install -y pcre2 2>/dev/null; then
    echo "pcre2 nao encontrado no repo base, instalando via EPEL..."
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 2>/dev/null || true
    yum install -y pcre2
fi

# Instalar Zabbix Agent
echo "Instalando zabbix-agent..."
yum install -y zabbix-agent

# Criar diretório de log
mkdir -p /var/log/zabbix
chown zabbix:zabbix /var/log/zabbix

# Criar configuração do agente
echo "Criando zabbix_agentd.conf..."
cat <<EOF >/etc/zabbix/zabbix_agentd.conf
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=1024
DebugLevel=3

ListenPort=10050

Server=$ZABBIX_SERVERS
ServerActive=$ZABBIX_SERVER_ACTIVE

HostnameItem=system.hostname
RefreshActiveChecks=60
Timeout=30
HostMetadataItem=system.uname

Include=/etc/zabbix/zabbix_agentd.d/*.conf
EOF

# Garantir permissões
chown zabbix:zabbix /etc/zabbix/zabbix_agentd.conf
chmod 640 /etc/zabbix/zabbix_agentd.conf

# Firewall (se existir)
if systemctl is-active firewalld &>/dev/null; then
    echo "Liberando porta 10050 no firewalld..."
    firewall-cmd --permanent --add-port=10050/tcp
    firewall-cmd --reload
fi

# Habilitar e iniciar serviço
echo "Habilitando e iniciando Zabbix Agent..."
systemctl enable zabbix-agent
systemctl restart zabbix-agent

# Status final
systemctl status zabbix-agent --no-pager

echo "================================================="
echo " Zabbix Agent 7 instalado e configurado!"
echo "================================================="
