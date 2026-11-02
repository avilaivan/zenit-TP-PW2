<?php

namespace app\service;

/**
 * Todas las reglas numéricas del modo individual en un solo lugar.
 * Cambiar el balance del juego = cambiar un número acá.
 */
final class ReglasJuego
{
    public const PALABRA = 'ZENIT';             // letras a recolectar, en orden

    public const VIDAS_INICIALES = 3;
    public const VIDAS_MAXIMAS = 5;             // tope al elegir corazón como premio

    public const PREGUNTAS_POR_RONDA = 3;       // ronda de categoría y ronda de letra
    public const OPCIONES_POR_PREGUNTA = 6;     // 1 correcta + 5 incorrectas
    public const MINIMO_ACIERTOS = 2;           // en ronda de categoría: menos de 2 → -1 vida
    public const RONDAS_PARA_LETRA = 3;         // rondas superadas seguidas → ronda de letra
    public const MINIMO_ACIERTOS_LETRA = 2;     // en ronda de letra: 2 de 3 → letra o corazón

    public const SEGUNDOS_POR_PREGUNTA = 20;
    public const SEGUNDOS_DE_GRACIA = 2;        // margen por la demora de la red

    // Categoría Z: muy poco probable; cada acierto la hace un poquito más probable.
    public const PROB_Z_BASE = 0.015;           // 1,5 %
    public const PROB_Z_POR_ACIERTO = 0.001;    // +0,1 % por respuesta correcta
    public const PROB_Z_MAXIMA = 0.05;          // nunca más de 5 %

    // Puntos (suman al "elo" del perfil)
    public const PUNTOS_ACIERTO = 10;
    public const PUNTOS_RONDA_SUPERADA = 20;
    public const PUNTOS_LETRA = 100;
    public const PUNTOS_VICTORIA = 500;
}
