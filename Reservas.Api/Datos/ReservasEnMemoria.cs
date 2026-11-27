using Reservas.Api.Modelos;

namespace Reservas.Api.Datos;

/// <summary>
/// Almacén en memoria del microservicio de reservas. No usa Entity Framework
/// ni SQL Server: su objetivo es demostrar un segundo servicio independiente
/// detrás del gateway.
/// </summary>
public static class ReservasEnMemoria
{
    public static readonly IReadOnlyList<Reserva> Todas = new List<Reserva>
    {
        new(1, "Lucía Ramírez",   "987654321", new DateOnly(2026, 11, 25), "19:30", 4, 7,  "Confirmada"),
        new(2, "Jorge Salazar",   "986112233", new DateOnly(2026, 11, 25), "20:00", 2, 3,  "Confirmada"),
        new(3, "María Fernández", "955443322", new DateOnly(2026, 11, 25), "20:30", 6, 12, "Pendiente"),
        new(4, "Carlos Mendoza",  "944556677", new DateOnly(2026, 11, 26), "13:00", 3, 5,  "Confirmada"),
        new(5, "Ana Torres",      "933221100", new DateOnly(2026, 11, 26), "13:30", 2, 2,  "Cancelada"),
        new(6, "Luis Paredes",    "922334455", new DateOnly(2026, 11, 26), "19:00", 8, 15, "Confirmada"),
        new(7, "Rosa Chávez",     "911223344", new DateOnly(2026, 11, 27), "20:00", 4, 8,  "Pendiente"),
        new(8, "Diego Herrera",   "900112233", new DateOnly(2026, 11, 27), "21:00", 2, 1,  "Confirmada")
    };
}
