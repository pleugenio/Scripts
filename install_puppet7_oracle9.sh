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

echo " Instalando Puppet Agent 7 - Oracle Linux 9.5"

echo " Certname:     $CERTNAME"

echo " Puppet/CA:    $PUPPET_SERVER"

echo " Environment:  $ENVIRONMENT"

echo "================================================="



if ! grep -q "^Oracle Linux Server release 9" /etc/oracle-release; then

	  echo "ERRO: Script válido apenas para Oracle Linux 9.x"

	    exit 1

fi



# Parar serviço se existir

systemctl stop puppet 2>/dev/null || true



# Remover Puppet antigo (se existir)

dnf remove -y \

	  puppet \

	    puppet-agent \

	      puppetlabs-release \

	        puppet6-release \

		  puppet7-release || true



		# Limpeza TOTAL

		rm -rf \

			  /etc/puppetlabs \

			    /opt/puppetlabs \

			      /var/lib/puppet \

			        /var/log/puppetlabs \

				  /var/cache/puppet



				# Instalar repo Puppet 7

				dnf install -y https://yum.puppet.com/puppet7-release-el-9.noarch.rpm



				# Instalar Puppet Agent

				dnf install -y puppet-agent



				# PATH global

				cat <<EOF >/etc/profile.d/puppet.sh

export PATH=/opt/puppetlabs/bin:\$PATH

EOF

chmod +x /etc/profile.d/puppet.sh



# Criar puppet.conf LIMPO

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



# Habilitar serviço (SEM forçar execução do agent)

systemctl enable puppet

systemctl start puppet



echo "================================================="

echo " Puppet Agent INSTALADO (cert ainda NÃO gerado)"

echo "================================================="

echo ""

echo "➡️ Próximo passo MANUAL:"

echo "   puppet agent -t"

echo ""

echo "➡️ Depois assinar no Foreman:"

echo "   puppetserver ca sign --certname $CERTNAME"




