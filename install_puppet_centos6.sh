#!/bin/bash
set -e

##############################################
# VARIÁVEIS
##############################################
PUPPET_SERVER="srv-br-foreman-proxy-01.corp.folha.com.br"
CA_SERVER="srv-br-foreman-proxy-01.corp.folha.com.br"
ENVIRONMENT="production"
CERTNAME="$(hostname -f)"

##############################################

echo "================================================="
echo " Instalando Puppet Agent 6 - CentOS 6.10"
echo " Certname:     $CERTNAME"
echo " Puppet/CA:    $PUPPET_SERVER"
echo " Environment:  $ENVIRONMENT"
echo "================================================="

# Validar CentOS 6
grep -q "CentOS release 6" /etc/centos-release || {
  echo "ERRO: Script válido apenas para CentOS 6"
  exit 1
}

# Parar serviço antigo se existir
service puppet stop 2>/dev/null || true

# Remover Puppet antigo
yum remove -y puppet puppet-agent puppetlabs-release-pc1 puppet6-release puppet7-release || true

# Limpeza TOTAL
rm -rf \
  /etc/puppet \
  /etc/puppetlabs \
  /opt/puppetlabs \
  /var/lib/puppet \
  /var/log/puppet \
  /var/log/puppetlabs \
  /var/cache/puppet

# Instalar repo Puppet 6 (pc1)
rpm -Uvh https://yum.puppet.com/puppet6-release-el-6.noarch.rpm

# Instalar Puppet Agent
yum install -y puppet-agent

# PATH global
cat <<EOF >/etc/profile.d/puppet.sh
export PATH=/opt/puppetlabs/bin:\$PATH
EOF
chmod +x /etc/profile.d/puppet.sh

# Criar puppet.conf
mkdir -p /etc/puppetlabs/puppet

cat <<EOF >/etc/puppetlabs/puppet/puppet.conf
[main]
certname = $CERTNAME
environment = $ENVIRONMENT
ca_server = $CA_SERVER
reports = log, foreman

[agent]
server = $PUPPET_SERVER
environment = $ENVIRONMENT
daemonize = true
report = true
runinterval = 300
waitforcert = 0
EOF

# Habilitar serviço
chkconfig puppet on
service puppet start

echo "================================================="
echo " Puppet Agent 6 INSTALADO (cert ainda NÃO gerado)"
echo "================================================="
echo ""
echo "➡️ Próximo passo MANUAL:"
echo "   puppet agent -t"
echo ""
echo "➡️ Depois assinar no Foreman:"
echo "   puppetserver ca sign --certname $CERTNAME"
