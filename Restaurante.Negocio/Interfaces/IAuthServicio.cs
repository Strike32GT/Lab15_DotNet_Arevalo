using Restaurante.Entidades.DTOs;

namespace Restaurante.Negocio.Interfaces;

/// <summary>
/// Reglas de negocio de autenticación.
/// </summary>
public interface IAuthServicio
{
    /// <summary>
    /// Registra un usuario con clave cifrada y rol asignado por el servidor.
    /// </summary>
    Task<UsuarioDto> RegistrarAsync(RegistroDto dto);

    /// <summary>
    /// Devuelve el token cuando las credenciales son válidas; null en caso contrario.
    /// </summary>
    Task<TokenDto?> LoginAsync(LoginDto dto);
}
