using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Reservas.Api.Datos;
using Reservas.Api.Modelos;

namespace Reservas.Api.Controllers;

/// <summary>
/// Microservicio 2: reservas de mesa del restaurante.
/// Todos los endpoints exigen un token JWT válido, emitido por la API S14
/// con la misma clave, emisor y audiencia.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
[Authorize]
public class ReservasController : ControllerBase
{
    /// <summary>
    /// Lista las reservas. Permite filtrar por estado y por fecha.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Reserva>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<IEnumerable<Reserva>> ObtenerTodas(
        [FromQuery] string? estado,
        [FromQuery] DateOnly? fecha)
    {
        var reservas = ReservasEnMemoria.Todas.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(estado))
        {
            reservas = reservas.Where(r =>
                r.Estado.Equals(estado, StringComparison.OrdinalIgnoreCase));
        }

        if (fecha is not null)
        {
            reservas = reservas.Where(r => r.Fecha == fecha);
        }

        return Ok(reservas);
    }

    /// <summary>
    /// Obtiene una reserva por su identificador.
    /// </summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(Reserva), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<Reserva> ObtenerPorId(int id)
    {
        var reserva = ReservasEnMemoria.Todas.FirstOrDefault(r => r.Id == id);

        if (reserva is null)
        {
            return NotFound(new { mensaje = $"No existe la reserva con id {id}." });
        }

        return Ok(reserva);
    }
}
