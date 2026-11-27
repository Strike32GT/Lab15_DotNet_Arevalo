namespace Restaurante.Entidades;

/// <summary>
/// Usuario de la API. La clave nunca se guarda en texto: solo su hash BCrypt.
/// </summary>
public partial class Usuario
{
    public int UsuarioId { get; set; }

    public string Correo { get; set; } = null!;

    public string ClaveHash { get; set; } = null!;

    public string Rol { get; set; } = null!;
}
