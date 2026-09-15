#!/usr/bin/env bash

# astra hardware check - Verifica hardware completo (ESP, sensores, USB)

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

info "Verificando hardware completo..."

# 1. Detectar ESP
info "1/4 Detectando dispositivos ESP..."
if detect_esp_serial; then
    ok "Dispositivos ESP detectados"
else
    warn "No se detectaron dispositivos ESP8266/ESP32"
fi

# 2. Verificar conectividad ESP
info "2/4 Verificando conectividad ESP..."
if check_esp_connectivity; then
    ok "ESP respondiendo correctamente"
else
    warn "ESP no responde (puede necesitar firmware o estar en modo boot)"
fi

# 3. Verificar sensores si hay workspace
info "3/4 Verificando sensores..."
if workspace_find 2>/dev/null; then
    load_workspace
    # Check for nodes with sensors
    NODES=("$WORKSPACE/nodes/"*/)
    NODES=("${NODES[@]%/}")
    NODES=("${NODES[@]##*/}")
    
    if [ ${#NODES[@]} -gt 0 ]; then
        for node in "${NODES[@]}"; do
            info "Verificando sensores en nodo: $node"
            NODE_DIR="$WORKSPACE/nodes/$node"
            FIRMWARE_YAML="$NODE_DIR/firmware.yaml"
            
            if [ -f "$FIRMWARE_YAML" ]; then
                if grep -q "bmp581_i2c" "$FIRMWARE_YAML" 2>/dev/null; then
                    info "  BMP580 configurado en $node"
                    if grep -q "i2c:" "$FIRMWARE_YAML" 2>/dev/null; then
                        ok "    I2C configurado para BMP580"
                    else
                        warn "    I2C no configurado (requerido para BMP580)"
                    fi
                fi
                
                if grep -q "dallas_temp" "$FIRMWARE_YAML" 2>/dev/null; then
                    info "  DS18B20 configurado en $node"
                    if grep -q "one_wire:" "$FIRMWARE_YAML" 2>/dev/null; then
                        ok "    1-Wire configurado para DS18B20"
                    else
                        warn "    1-Wire no configurado (requerido para DS18B20)"
                    fi
                fi
            fi
        done
    else
        info "  No hay nodos configurados"
    fi
else
    info "  No hay workspace activo"
fi

# 4. Verificar almacenamiento USB
info "4/4 Verificando almacenamiento USB..."
if detect_usb_storage; then
    ok "Almacenamiento USB detectado"
    if test_usb_storage; then
        ok "Prueba de almacenamiento USB exitosa"
    fi
else
    info "No hay almacenamiento USB conectado"
fi

ok "Verificación de hardware completada"
