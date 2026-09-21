
# Archivo donde se guardará la evidencia
mkdir -p evidence
OUT="evidence/e4_result.txt"

# Escritura con el clúster completo
echo "Escritura antes de la falla: $(date -Iseconds)" | tee "$OUT"
docker compose exec -T crdb-1 ./cockroach sql --insecure -e "
UPDATE ti4601_e4.public.e4_probe
SET version = version + 1, updated_at = now()
WHERE id = 1 RETURNING *;" | tee -a "$OUT"


# Se mide cuánto tarda en confirmarse otra escritura
inicio=$(date +%s%3N)
# Se detiene uno de los nodos
echo "Deteniendo crdb-2: $(date -Iseconds)" | tee -a "$OUT"
docker compose stop -t 0 crdb-2 | tee -a "$OUT"

until docker compose exec -T crdb-1 ./cockroach sql --insecure -e "
UPDATE ti4601_e4.public.e4_probe
SET version = version + 1, updated_at = now()
WHERE id = 1 RETURNING *;" >> "$OUT" 2>&1
do
    sleep 1
done

fin=$(date +%s%3N)
echo "RTO observado: $((fin-inicio)) ms" | tee -a "$OUT"

# Se consulta la fila para comprobar que no hubo pérdida de datos
docker compose exec -T crdb-1 ./cockroach sql --insecure -e "
SELECT * FROM ti4601_e4.public.e4_probe;" | tee -a "$OUT"

# Se vuelve a levantar el nodo
docker compose start crdb-2