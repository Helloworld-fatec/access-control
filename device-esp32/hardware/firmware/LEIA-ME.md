# Firmware de bancada

Versao derivada do sketch integrado do Wokwi, sem coordenadas GPS ficticias. RC522 desativado por padrao (`ATIVAR_RFID 0`) enquanto aguarda revisao de solda. A autorizacao funciona por L/N no monitor serial. Apos revisar o leitor, e possivel habilitar `ATIVAR_RFID 1`; o UID autorizado de demonstracao permanece 01:02:03:04.

Esta revisao foi preparada para a montagem atual e ainda precisa de validacao fisica com a pinagem integrada (OLED SCL13; RC522 RST22). Os testes fisicos anteriores dos componentes nao validam automaticamente esta revisao de firmware.

