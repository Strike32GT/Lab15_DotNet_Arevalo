namespace Reservas.Api.Configuracion;

/// <summary>
/// Datos de configuración del token JWT para el microservicio de reservas.
/// </summary>
public class JwtSettings
{
    public string Clave { get; set; } = string.Empty;

    public string Emisor { get; set; } = string.Empty;

    public string Audiencia { get; set; } = string.Empty;
}
