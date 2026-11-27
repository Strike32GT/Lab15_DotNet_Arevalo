namespace Restaurante.Entidades.DTOs;

/// <summary>
/// DTO de salida con los datos públicos de un usuario registrado.
/// Nunca incluye la clave ni su hash.
/// </summary>
public class UsuarioDto
{
    public int UsuarioId { get; set; }

    public string Correo { get; set; } = string.Empty;

    public string Rol { get; set; } = string.Empty;
}
