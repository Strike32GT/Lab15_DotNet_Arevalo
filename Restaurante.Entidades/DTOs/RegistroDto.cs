using System.ComponentModel.DataAnnotations;

namespace Restaurante.Entidades.DTOs;

/// <summary>
/// DTO de entrada para registrar un usuario. No incluye el rol:
/// el servidor siempre asigna uno.
/// </summary>
public class RegistroDto
{
    [Required(ErrorMessage = "El correo es obligatorio.")]
    [EmailAddress(ErrorMessage = "El correo no tiene un formato válido.")]
    [StringLength(150, ErrorMessage = "El correo no puede superar los 150 caracteres.")]
    public string Correo { get; set; } = string.Empty;

    [Required(ErrorMessage = "La clave es obligatoria.")]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "La clave debe tener entre 8 y 100 caracteres.")]
    public string Clave { get; set; } = string.Empty;
}
