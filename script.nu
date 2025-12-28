# script.nu - Procesamiento de Datos de Educación Superior
# Desarrollado para: Análisis de Matrículas 2020-2024

print "1. Cargando y filtrando datos (Motor Nushell)..."
# Abrimos el CSV original
let raw = (open "estudio_mercado_ordenado.csv")

# Filtramos: Solo Pregrado, carreras de Datos/Estadística y excluimos Postgrados/Otros
let filtrado = ($raw 
    | where "NIVEL GLOBAL" == "Pregrado" 
    | where { |it| $it."NOMBRE CARRERA" =~ "(?i)estad|dato" }
    | where { |it| 
        $it."NOMBRE CARRERA" !~ "(?i)master|diploma|sociedad|derecho|profesor|pedagogia|licenciatura|magister|doctorado|postitulo|regularizacion|salud|redes|comunicacion de datos|base de datos|registros" 
    }
)

print "2. Limpiando tipos de datos y preparando métricas..."
# Transformamos las columnas: quitamos prefijos al año y convertimos textos a números
let limpio = ($filtrado | each { |it| 
    {
        "NOMBRE INSTITUCIÓN": $it."NOMBRE INSTITUCIÓN",
        "NOMBRE SEDE": $it."NOMBRE SEDE",
        "NOMBRE CARRERA": $it."NOMBRE CARRERA",
        "AÑO": ($it."AÑO" | str replace "MAT_" "" | into int),
        "T": (if ($it."TOTAL MATRICULADOS" == "") {0} else {$it."TOTAL MATRICULADOS" | into int}),
        "P": (if ($it."TOTAL MATRICULADOS PRIMER AÑO" == "") {0} else {$it."TOTAL MATRICULADOS PRIMER AÑO" | into int})
    }
})

print "3. Agrupando y Pivoteando (Motor Polars)..."
# Usamos Polars para sumar duplicados (diurnos/vespertinos) y pivotear por año
let final = (
    $limpio 
    | polars into-df 
    | polars group-by ["NOMBRE INSTITUCIÓN" "NOMBRE SEDE" "NOMBRE CARRERA" "AÑO"]
    | polars agg [
        (polars col "T" | polars sum | polars as "T")
        (polars col "P" | polars sum | polars as "P")
    ]
    | polars pivot --index ["NOMBRE INSTITUCIÓN" "NOMBRE SEDE" "NOMBRE CARRERA"] --on ["AÑO"] --values ["T" "P"]
    | polars select [
        "NOMBRE INSTITUCIÓN" "NOMBRE SEDE" "NOMBRE CARRERA"
        "T_2020" "T_2021" "T_2022" "T_2023" "T_2024"
        "P_2020" "P_2021" "P_2022" "P_2023" "P_2024"
    ]
)

print "4. Guardando en ies_last_5_years_data.csv..."
# Convertimos de vuelta a Nushell para asegurar la escritura en disco
$final | polars into-nu | save -f "ies_last_5_years_data.csv"

print "¡PROCESO TERMINADO EXITOSAMENTE!"
