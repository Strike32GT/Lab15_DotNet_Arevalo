using Microsoft.EntityFrameworkCore;
using Restaurante.Datos.Interfaces;
using Restaurante.Entidades;

namespace Restaurante.Datos.Repositorios;

public class UsuarioRepositorio : IUsuarioRepositorio
{
    private readonly RestauranteContext _contexto;

    public UsuarioRepositorio(RestauranteContext contexto)
    {
        _contexto = contexto;
    }

    public async Task<Usuario?> BuscarPorCorreoAsync(string correo)
    {
        return await _contexto.Usuarios
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Correo == correo);
    }

    public async Task AgregarAsync(Usuario usuario)
    {
        await _contexto.Usuarios.AddAsync(usuario);
    }

    public async Task GuardarAsync()
    {
        await _contexto.SaveChangesAsync();
    }
}
