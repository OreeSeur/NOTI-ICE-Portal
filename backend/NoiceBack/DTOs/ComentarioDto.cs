using System;

namespace PortalNoticiasAPI.DTOs
{
    public class ComentarioDto
    {
        public int IdComentario { get; set; }
        public string ComentarioTexto { get; set; } = string.Empty;
        public DateTime FechaPublicacion { get; set; }
        public int IdUsuario { get; set; }
        public string? AutorNombre { get; set; }
    }

    // Lo que el frontend manda para publicar un comentario en una noticia.
    // No incluye IdUsuario: el autor se toma del JWT, no del cuerpo de la petición.
    public class ComentarioCreateDto
    {
        public int IdNoticia { get; set; }
        public string ComentarioTexto { get; set; } = string.Empty;
    }
}
