import { get, post, remove } from "../api/apiClient";
import { ENDPOINTS } from "../api/endpoints";

// Backend (ComentarioDto) -> forma que usa el frontend
const mapComentarioFromApi = (c) => ({
  id: c.idComentario,
  texto: c.comentarioTexto,
  fecha: c.fechaPublicacion,
  idUsuario: c.idUsuario,
  autor: c.autorNombre || "Usuario",
});

export const obtenerComentarios = async (idNoticia) => {
  const data = await get(`${ENDPOINTS.comentarios}/porNoticia/${idNoticia}`);
  return data.map(mapComentarioFromApi);
};

// El autor NO se manda: el backend lo toma del token de la sesión
export const crearComentarioApi = async (idNoticia, texto) => {
  const creado = await post(ENDPOINTS.comentarios, {
    idNoticia: Number(idNoticia),
    comentarioTexto: texto,
  });
  return mapComentarioFromApi(creado);
};

export const eliminarComentarioApi = async (idComentario) => {
  await remove(`${ENDPOINTS.comentarios}/${idComentario}`);
};
