// Duración por defecto de una noticia. Debe coincidir con Noticias:MesesVigencia del backend (6).
export const MESES_VIGENCIA_DEFAULT = 6;

const pad = (numero) => String(numero).padStart(2, "0");

const aISO = (fecha) =>
  `${fecha.getFullYear()}-${pad(fecha.getMonth() + 1)}-${pad(fecha.getDate())}`;

// Fecha de hoy (yyyy-mm-dd) en hora LOCAL.
// toISOString() usa UTC y, por la noche en México, devolvería la fecha de mañana.
export const hoyISO = () => aISO(new Date());

// Suma meses a una fecha yyyy-mm-dd cuidando los meses cortos
// (31 de agosto + 6 meses = 28 de febrero, no 3 de marzo).
export const sumarMesesISO = (iso, meses) => {
  const [anio, mes, dia] = iso.split("-").map(Number);

  const destino = new Date(anio, mes - 1 + meses, 1);
  const ultimoDia = new Date(destino.getFullYear(), destino.getMonth() + 1, 0).getDate();
  destino.setDate(Math.min(dia, ultimoDia));

  return aISO(destino);
};

export const vigenciaPorDefecto = (desde = hoyISO()) =>
  sumarMesesISO(desde, MESES_VIGENCIA_DEFAULT);
