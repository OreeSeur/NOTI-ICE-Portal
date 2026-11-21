import { get, post, put, remove } from "../api/apiClient";
import { ENDPOINTS } from "../api/endpoints";
import { normalizeAudience } from "../utils/audience";
import { hoyISO } from "../utils/vigencia";

// ---- Mapeo backend -> frontend ----
// El backend usa: idNoticia, titulo, contenido, fechaPublicacion, fechaExpiracion, vigente, audiencia{...}
// El frontend (formularios/páginas) usa: id, titulo, fecha, vigenteHasta, expirada, descripcion, audiencia{...}
const mapNoticiaFromApi = (n) => ({
  id: n.idNoticia,
  titulo: n.titulo,
  descripcion: n.contenido,
  fecha: n.fechaPublicacion ? n.fechaPublicacion.substring(0, 10) : "",
  vigenteHasta: n.fechaExpiracion ? n.fechaExpiracion.substring(0, 10) : "",
  expirada: n.vigente === false,
  autor: n.autorNombre,
  idUsuario: n.idUsuario,
  categoria: n.categoriaNombre,
  idCategoria: n.idCategoria,
  activo: n.activo,
  audiencia: normalizeAudience(n.audiencia),
  createdAt: n.fechaAlta,
});

// ---- Mapeo frontend -> backend ----
// Si vigenteHasta va vacío, el backend asigna 6 meses desde la publicación.
const mapNoticiaToApi = (n, idUsuario, fechaPublicacion) => ({
  titulo: n.titulo,
  contenido: n.descripcion,
  idUsuario,
  idCategoria: n.idCategoria ?? null,
  fechaPublicacion,
  fechaExpiracion: n.vigenteHasta || null,
  audiencia: normalizeAudience(n.audiencia),
});

// Por defecto trae solo las noticias vigentes (lo que ve el público).
// Con incluirExpiradas, un administrador recibe también las que ya vencieron.
export const obtenerNoticias = async ({ incluirExpiradas = false } = {}) => {
  const ruta = incluirExpiradas
    ? `${ENDPOINTS.noticias}?incluirExpiradas=true`
    : ENDPOINTS.noticias;

  const data = await get(ruta);
  return data.map(mapNoticiaFromApi);
};

// Un administrador puede abrir una noticia expirada para renovarla
export const obtenerNoticiaPorId = async (id) => {
  const data = await get(`${ENDPOINTS.noticias}/${id}`);
  return mapNoticiaFromApi(data);
};

// La fecha de publicación se asigna sola: es "ahora mismo", no la elige quien publica.
export const crearNoticiaApi = async (datosFormulario, idUsuario) => {
  const creada = await post(
    ENDPOINTS.noticias,
    mapNoticiaToApi(datosFormulario, idUsuario, hoyISO())
  );
  return mapNoticiaFromApi(creada);
};

// Al editar, se conserva la fecha de publicación original (fechaOriginal),
// porque el formulario ya no permite cambiarla. Cambiar "vigenteHasta" renueva la noticia.
export const editarNoticiaApi = async (id, datosFormulario, fechaOriginal) => {
  await put(`${ENDPOINTS.noticias}/${id}`, {
    titulo: datosFormulario.titulo,
    contenido: datosFormulario.descripcion,
    idCategoria: datosFormulario.idCategoria ?? null,
    fechaPublicacion: fechaOriginal,
    fechaExpiracion: datosFormulario.vigenteHasta || null,
    audiencia: normalizeAudience(datosFormulario.audiencia),
  });
};

export const eliminarNoticiaApi = async (id) => {
  await remove(`${ENDPOINTS.noticias}/${id}`);
};
