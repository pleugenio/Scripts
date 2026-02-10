#!/bin/bash
set -e

##############################################
# VARIÁVEIS
##############################################
ZABBIX_SERVERS="10.20.13.136,10.20.13.138,10.20.13.139,10.20.13.168,10.20.13.179,10.20.13.180"
ZABBIX_SERVER_ACTIVE="10.20.13.136"

##############################################

echo "================================================="
echo " Instalando Zabbix Agent 7 - Oracle Linux 9"
echo "================================================="

# Garantir Oracle Linux 9.x
if ! grep -q "^Oracle Linux Server release 9" /etc/oracle-release; then
	  echo "ERRO: Script válido apenas para Oracle Linux 9.x"
	    exit 1
fi

# Remover agente antigo (se existir)
echo "🔹 Removendo versões antigas (se houver)..."
systemctl stop zabbix-agent 2>/dev/null || true
dnf remove -y zabbix-agent zabbix-agent2 zabbix-release || true

rm -rf /etc/zabbix /var/log/zabbix || true

# Instalar repositório Zabbix 7
echo "🔹 Instalando repositório Zabbix 7..."
dnf install -y https://repo.zabbix.com/zabbix/7.0/oracle/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm

# Limpar cache dnf
dnf clean all

# Instalar Zabbix Agent
echo "🔹 Instalando zabbix-agent..."
dnf install -y zabbix-agent

# Criar diretório de log
mkdir -p /var/log/zabbix
chown zabbix:zabbix /var/log/zabbix

# Criar configuração do agente
echo "🔹 Criando zabbix_agentd.conf..."
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
	  echo "🔹 Liberando porta 10050 no firewalld..."
	    firewall-cmd --permanent --add-port=10050/tcp
	      firewall-cmd --reload
fi

# Habilitar e iniciar serviço
echo "🔹 Habilitando e iniciando Zabbix Agent..."
systemctl enable zabbix-agent
systemctl restart zabbix-agent

# Status final
systemctl status zabbix-agent --no-pager

echo "================================================="
echo " Zabbix Agent 7 instalado e configurado!"
echo "================================================="

