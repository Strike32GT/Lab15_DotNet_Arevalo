namespace Restaurante.Entidades.DTOs;

/// <summary>
/// DTO de salida con el token JWT y su fecha de expiración.
/// </summary>
public class TokenDto
{
    public string Token { get; set; } = string.Empty;

    public DateTime Expira { get; set; }
}
