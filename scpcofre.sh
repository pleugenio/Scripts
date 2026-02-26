#!/bin/bash
# scpcofre - último recurso. lê senha AD de arquivo (inseguro).

DEST="$1"; shift
USER_PREFIX='lbvdc.lbv.org.br\TECPaulol@lbvdc.lbv.org.br\TECPaulol_PAM@'
USER="${USER_PREFIX}${DEST}"
PASSFILE="/root/.secrets/cofre_ad_pass"

if [ ! -f "$PASSFILE" ]; then
  echo "Arquivo de senha $PASSFILE nao encontrado. Crie com permissão 600."
  exit 1
fi

# garantir permissões restritas
chmod 600 "$PASSFILE"

export SSHPASS="$(< "$PASSFILE")"

# Uso:
# scpcofre destino origem arquivo
# Exemplo:
# scpcofre srv01 arquivo.txt /tmp/

if [ $# -lt 2 ]; then
  echo "Uso:"
  echo "  Enviar:   scpcofre <destino> <arquivo_local> <caminho_remoto>"
  echo "  Receber:  scpcofre <destino> <caminho_remoto> <arquivo_local>"
  exit 1
fi

scp -P 4422 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$@" \
  "${USER}@cofre.lbv.org.br:"

unset SSHPASS
