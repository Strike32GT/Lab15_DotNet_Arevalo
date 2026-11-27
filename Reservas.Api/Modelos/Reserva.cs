namespace Reservas.Api.Modelos;

/// <summary>
/// Reserva de mesa del restaurante. Es un dato en memoria: este
/// microservicio no comparte base de datos ni clases con la API S14.
/// </summary>
public sealed record Reserva(
    int Id,
    string Cliente,
    string Telefono,
    DateOnly Fecha,
    string Hora,
    int Personas,
    int Mesa,
    string Estado);
