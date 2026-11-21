using PortalNoticiasAPI.Models;

namespace PortalNoticiasAPI.Services
{
    // Noticias temporales: una noticia se muestra hasta el final de su FechaExpiracion (inclusive).
    // FechaExpiracion = null significa "sin vencimiento" (noticias anteriores a esta función).
    public static class VigenciaNoticias
    {
        public const int MesesPorDefecto = 6;

        private static readonly TimeZoneInfo? ZonaPortal = BuscarZona();

        private static TimeZoneInfo? BuscarZona()
        {
            // El VPS corre en UTC: sin esto, desde las 18:00 de México ya contaría como "mañana".
            foreach (var id in new[] { "America/Mexico_City", "Central Standard Time (Mexico)" })
            {
                try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
                catch (TimeZoneNotFoundException) { }
                catch (InvalidTimeZoneException) { }
            }
            return null;
        }

        // Fecha de hoy en la zona del portal (America/Mexico_City); si no existe, la del servidor.
        public static DateTime Hoy() =>
            ZonaPortal is null
                ? DateTime.Today
                : TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, ZonaPortal).Date;

        // "Noticias": { "MesesVigencia": 6 } en la configuración; valores inválidos usan 6.
        public static int Meses(IConfiguration configuration)
        {
            var meses = configuration.GetValue<int?>("Noticias:MesesVigencia") ?? MesesPorDefecto;
            return meses > 0 ? meses : MesesPorDefecto;
        }

        public static bool EsVigente(Noticia n, DateTime hoy) =>
            n.FechaExpiracion == null || n.FechaExpiracion.Value.Date >= hoy;
    }
}
