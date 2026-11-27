namespace Restaurante.Entidades.DTOs;

/// <summary>
/// DTO de salida del perfil. Se arma con los claims del token,
/// no con una consulta a la base de datos.
/// </summary>
public class PerfilDto
{
    public string Correo { get; set; } = string.Empty;

    public string Rol { get; set; } = string.Empty;
}
