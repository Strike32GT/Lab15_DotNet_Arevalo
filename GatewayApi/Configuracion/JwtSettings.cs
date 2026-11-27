namespace GatewayApi.Configuracion;

/// <summary>
/// Datos que el gateway necesita para validar el mismo token JWT que emite
/// la API Restaurante. La clave, el emisor y la audiencia se leen de
/// appsettings o de variables de entorno (Jwt__Clave, Jwt__Emisor,
/// Jwt__Audiencia) y nunca se guardan en el repositorio.
/// </summary>
public class JwtSettings
{
    public string Clave { get; set; } = string.Empty;

    public string Emisor { get; set; } = string.Empty;

    public string Audiencia { get; set; } = string.Empty;
}
