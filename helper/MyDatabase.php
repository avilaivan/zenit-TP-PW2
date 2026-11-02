<?php
/**
 * Acceso a MySQL con PDO.
 *
 * Todas las consultas son PREPARADAS (los valores van como parámetros "?"),
 * así no hay riesgo de SQL injection.
 */
class MyDatabase
{
    private PDO $conexion;

    public function __construct(string $host, string $usuario, string $clave, string $base)
    {
        $this->conexion = new PDO(
            "mysql:host=$host;dbname=$base;charset=utf8mb4",
            $usuario,
            $clave,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]
        );
    }

    /** Devuelve una fila o null. */
    public function queryOne(string $sql, array $parametros = []): ?array
    {
        $fila = $this->preparar($sql, $parametros)->fetch();
        return $fila === false ? null : $fila;
    }

    /** Devuelve todas las filas. */
    public function queryAll(string $sql, array $parametros = []): array
    {
        return $this->preparar($sql, $parametros)->fetchAll();
    }

    /** INSERT / UPDATE / DELETE. Devuelve las filas afectadas. */
    public function execute(string $sql, array $parametros = []): int
    {
        return $this->preparar($sql, $parametros)->rowCount();
    }

    public function lastInsertId(): int
    {
        return (int) $this->conexion->lastInsertId();
    }

    private function preparar(string $sql, array $parametros): PDOStatement
    {
        $sentencia = $this->conexion->prepare($sql);
        $sentencia->execute($parametros);
        return $sentencia;
    }
}
