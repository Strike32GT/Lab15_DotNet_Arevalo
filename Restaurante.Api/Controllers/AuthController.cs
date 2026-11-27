using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Restaurante.Entidades.DTOs;
using Restaurante.Negocio.Excepciones;
using Restaurante.Negocio.Interfaces;

namespace Restaurante.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
[Authorize]
public class AuthController : ControllerBase
{
    private readonly IAuthServicio _authServicio;

    public AuthController(IAuthServicio authServicio)
    {
        _authServicio = authServicio;
    }

    /// <summary>
    /// Registra un usuario nuevo. El rol lo asigna el servidor.
    /// </summary>
    [HttpPost("registro")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(UsuarioDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UsuarioDto>> Registro([FromBody] RegistroDto dto)
    {
        try
        {
            var usuario = await _authServicio.RegistrarAsync(dto);

            return StatusCode(StatusCodes.Status201Created, usuario);
        }
        catch (ReglaNegocioException ex)
        {
            return Conflict(new { mensaje = ex.Message });
        }
    }

    /// <summary>
    /// Inicia sesión y devuelve el token JWT.
    /// </summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(TokenDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<TokenDto>> Login([FromBody] LoginDto dto)
    {
        var token = await _authServicio.LoginAsync(dto);

        if (token is null)
        {
            return Unauthorized(new { mensaje = "Credenciales inválidas." });
        }

        return Ok(token);
    }

    /// <summary>
    /// Devuelve el correo y el rol del token, sin consultar la base de datos.
    /// </summary>
    [HttpGet("perfil")]
    [ProducesResponseType(typeof(PerfilDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<PerfilDto> Perfil()
    {
        var correo = User.FindFirst(JwtRegisteredClaimNames.Email)?.Value ?? string.Empty;
        var rol = User.FindFirst("rol")?.Value ?? string.Empty;

        return Ok(new PerfilDto
        {
            Correo = correo,
            Rol = rol
        });
    }
}
