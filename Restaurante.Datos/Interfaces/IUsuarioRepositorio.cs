using Restaurante.Entidades;

namespace Restaurante.Datos.Interfaces;

/// <summary>
/// Contrato de acceso a datos para los usuarios.
/// </summary>
public interface IUsuarioRepositorio
{
    Task<Usuario?> BuscarPorCorreoAsync(string correo);

    Task AgregarAsync(Usuario usuario);

    Task GuardarAsync();
}
