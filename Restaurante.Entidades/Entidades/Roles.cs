namespace Restaurante.Entidades;

/// <summary>
/// Roles propios del negocio del restaurante. El servidor los asigna;
/// el cliente no puede elegirlos en el registro.
/// </summary>
public static class Roles
{
    /// <summary>Gestiona categorías y platos del menú.</summary>
    public const string Chef = "Chef";

    /// <summary>Consulta el menú y sus propios datos de sesión.</summary>
    public const string Mesero = "Mesero";
}
