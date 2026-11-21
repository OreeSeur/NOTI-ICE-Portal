using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PortalNoticiasAPI.Data;
using PortalNoticiasAPI.DTOs;
using PortalNoticiasAPI.Models;
using PortalNoticiasAPI.Services;

namespace PortalNoticiasAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ComentariosController : ControllerBase
    {
        private readonly PortalNoticiasContext _context;
        private readonly AudienciaAccesoService _audiencias;
        public ComentariosController(PortalNoticiasContext context, AudienciaAccesoService audiencias)
        {
            _context = context;
            _audiencias = audiencias;
        }

        private const int MaxCaracteres = 1000; // columna comentarios.Comentario es VARCHAR(1000)

        private int? GetUserId() =>
            int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;

        // Mismo criterio que NoticiasController: audiencia, o ser el autor de la noticia.
        private bool PuedeVerNoticia(Noticia n, Usuario? usuario) =>
            (usuario is not null && n.IdUsuario == usuario.IdUsuario) ||
            _audiencias.PuedeVer(n.AudienciaJson, usuario);

        // Una noticia expirada (y sus comentarios) solo la ven el Administrador y su autor.
        private bool PuedeVerExpirada(Noticia n, Usuario? usuario) =>
            User.IsInRole("Administrador") || (usuario is not null && n.IdUsuario == usuario.IdUsuario);

        [HttpGet("porNoticia/{idNoticia}")]
        public async Task<ActionResult<IEnumerable<ComentarioDto>>> GetComentariosPorNoticia(int idNoticia)
        {
            var noticia = await _context.Noticias.FirstOrDefaultAsync(n => n.IdNoticia == idNoticia && n.Activo);
            var usuario = await _audiencias.UsuarioActualAsync(User);
            if (noticia == null || !PuedeVerNoticia(noticia, usuario))
                return NotFound();
            if (!VigenciaNoticias.EsVigente(noticia, VigenciaNoticias.Hoy()) && !PuedeVerExpirada(noticia, usuario))
                return NotFound();

            var comentarios = await _context.NoticiasComentarios
                .AsNoTracking()
                .Where(nc => nc.IdNoticia == idNoticia && nc.Activo && nc.Comentario!.Activo)
                .OrderBy(nc => nc.Comentario!.FechaPublicacion)
                .ThenBy(nc => nc.Comentario!.IdComentario)
                .Select(nc => new ComentarioDto
                {
                    IdComentario = nc.Comentario!.IdComentario,
                    ComentarioTexto = nc.Comentario.ComentarioTexto,
                    FechaPublicacion = nc.Comentario.FechaPublicacion,
                    IdUsuario = nc.Comentario.IdUsuario,
                    AutorNombre = nc.Comentario.Usuario!.Nombre
                })
                .ToListAsync();

            return Ok(comentarios);
        }

        // Cualquier usuario con sesión (Administrador, Docente o Alumno) que vea la noticia puede comentar.
        [HttpPost]
        [Authorize]
        public async Task<ActionResult<ComentarioDto>> CrearComentario(ComentarioCreateDto dto)
        {
            var noticia = await _context.Noticias.FirstOrDefaultAsync(n => n.IdNoticia == dto.IdNoticia && n.Activo);
            if (noticia == null || !PuedeVerNoticia(noticia, await _audiencias.UsuarioActualAsync(User)))
                return NotFound(new { mensaje = "La noticia no está disponible" });

            if (!VigenciaNoticias.EsVigente(noticia, VigenciaNoticias.Hoy()))
                return BadRequest(new { mensaje = "La noticia ya no está vigente y no admite comentarios" });

            var texto = (dto.ComentarioTexto ?? string.Empty).Trim();
            if (texto.Length == 0)
                return BadRequest(new { mensaje = "El comentario no puede estar vacío" });
            if (texto.Length > MaxCaracteres)
                return BadRequest(new { mensaje = $"El comentario no puede tener más de {MaxCaracteres} caracteres" });

            // La identidad del autor se obtiene del JWT, nunca del cuerpo enviado por el cliente.
            var idUsuario = GetUserId();
            if (idUsuario == null)
                return Unauthorized(new { mensaje = "No se pudo identificar al usuario autenticado" });

            var autorNombre = await _context.Usuarios
                .Where(u => u.IdUsuario == idUsuario && u.Activo)
                .Select(u => u.Nombre)
                .FirstOrDefaultAsync();
            if (autorNombre == null)
                return Unauthorized(new { mensaje = "El usuario autenticado no existe o está inactivo" });

            // Comentario y relación se guardan en un solo SaveChanges (una transacción):
            // así no puede quedar un comentario sin noticia asociada.
            var ahora = DateTime.Now;
            var comentario = new Comentario
            {
                ComentarioTexto = texto,
                FechaPublicacion = ahora,
                IdUsuario = idUsuario.Value,
                FechaAlta = ahora,
                Activo = true,
                NoticiasComentarios = new List<NoticiaComentario>
                {
                    new NoticiaComentario { IdNoticia = dto.IdNoticia, FechaAlta = ahora, Activo = true }
                }
            };
            _context.Comentarios.Add(comentario);
            await _context.SaveChangesAsync();

            return StatusCode(StatusCodes.Status201Created, new ComentarioDto
            {
                IdComentario = comentario.IdComentario,
                ComentarioTexto = comentario.ComentarioTexto,
                FechaPublicacion = comentario.FechaPublicacion,
                IdUsuario = comentario.IdUsuario,
                AutorNombre = autorNombre
            });
        }

        // El Administrador puede borrar cualquier comentario; los demás, solo los suyos (decisión 14 nov. 2026).
        [HttpDelete("{id}")]
        [Authorize]
        public async Task<IActionResult> EliminarComentario(int id)
        {
            var comentario = await _context.Comentarios.FindAsync(id);
            if (comentario == null || !comentario.Activo)
                return NotFound(new { mensaje = $"No se encontró el comentario con id {id}" });

            if (!User.IsInRole("Administrador") && comentario.IdUsuario != GetUserId())
                return StatusCode(403, new { mensaje = "Solo puedes eliminar tus propios comentarios" });

            comentario.Activo = false;
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
