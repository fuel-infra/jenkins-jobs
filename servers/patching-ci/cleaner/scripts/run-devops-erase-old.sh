#!/bin/bash

for VENV_PATH in $VENV_LIST ;
do
  if [ -f "${VENV_PATH}"/bin/dos.py ] ; then

    echo "======================="
    echo "Processing ${VENV_PATH}"
    echo "======================="
    source "${VENV_PATH}"/bin/activate
      dos.py list-old "${ENV_LIFETIME}"
      if [ $? -eq 0 ] ; then
        dos.py erase-old "${ENV_LIFETIME}" --force-cleanup
      else
        echo "Devops in ${VENV_PATH} does not support cleanup commands, please update it."
      fi
    deactivate
  fi
done
