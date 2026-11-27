using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AutoMapper;
using Microsoft.IdentityModel.Tokens;
using Restaurante.Datos.Interfaces;
using Restaurante.Entidades;
using Restaurante.Entidades.DTOs;
using Restaurante.Negocio.Configuracion;
using Restaurante.Negocio.Excepciones;
using Restaurante.Negocio.Interfaces;

namespace Restaurante.Negocio.Servicios;

public class AuthServicio : IAuthServicio
{
    private readonly IUsuarioRepositorio _repositorio;
    private readonly JwtSettings _jwtSettings;
    private readonly IMapper _mapper;

    public AuthServicio(
        IUsuarioRepositorio repositorio,
        JwtSettings jwtSettings,
        IMapper mapper)
    {
        _repositorio = repositorio;
        _jwtSettings = jwtSettings;
        _mapper = mapper;
    }

    public async Task<UsuarioDto> RegistrarAsync(RegistroDto dto)
    {
        var correo = dto.Correo.Trim().ToLowerInvariant();

        // Regla de negocio: el correo identifica al usuario y es único.
        if (await _repositorio.BuscarPorCorreoAsync(correo) is not null)
        {
            throw new ReglaNegocioException(
                $"Ya existe un usuario registrado con el correo '{correo}'.");
        }

        var usuario = new Usuario
        {
            Correo = correo,
            ClaveHash = BCrypt.Net.BCrypt.HashPassword(dto.Clave),
            // El rol lo decide el servidor: todo registro nuevo entra como Mesero.
            Rol = Roles.Mesero
        };

        await _repositorio.AgregarAsync(usuario);
        await _repositorio.GuardarAsync();

        return _mapper.Map<UsuarioDto>(usuario);
    }

    public async Task<TokenDto?> LoginAsync(LoginDto dto)
    {
        var correo = dto.Correo.Trim().ToLowerInvariant();
        var usuario = await _repositorio.BuscarPorCorreoAsync(correo);

        // La misma respuesta para correo inexistente y clave incorrecta.
        if (usuario is null || !BCrypt.Net.BCrypt.Verify(dto.Clave, usuario.ClaveHash))
        {
            return null;
        }

        var expiracion = DateTime.UtcNow.AddMinutes(_jwtSettings.MinutosVida);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, usuario.UsuarioId.ToString()),
            new(JwtRegisteredClaimNames.Email, usuario.Correo),
            new("rol", usuario.Rol)
        };

        var clave = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_jwtSettings.Clave));

        var credenciales = new SigningCredentials(
            clave,
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwtSettings.Emisor,
            audience: _jwtSettings.Audiencia,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expiracion,
            signingCredentials: credenciales);

        return new TokenDto
        {
            Token = new JwtSecurityTokenHandler().WriteToken(token),
            Expira = expiracion
        };
    }
}
