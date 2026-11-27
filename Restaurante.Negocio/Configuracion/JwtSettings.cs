namespace Restaurante.Negocio.Configuracion;

/// <summary>
/// Datos de configuración del token JWT. Se leen desde la sección Jwt
/// de appsettings y nunca se guardan en el repositorio.
/// </summary>
public class JwtSettings
{
    public string Clave { get; set; } = string.Empty;

    public string Emisor { get; set; } = string.Empty;

    public string Audiencia { get; set; } = string.Empty;

    public int MinutosVida { get; set; } = 60;
}
