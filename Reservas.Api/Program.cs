using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Reservas.Api.Configuracion;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// ------------------------------------------------------------
// Configuración del token JWT
// Misma clave, emisor y audiencia que la API de la S14 y el gateway.
// Se leen de appsettings o de variables de entorno.
// ------------------------------------------------------------
var jwtSettings = builder.Configuration
    .GetSection("Jwt")
    .Get<JwtSettings>()
    ?? throw new InvalidOperationException(
        "Falta la sección Jwt en la configuración de Reservas.Api.");

if (string.IsNullOrWhiteSpace(jwtSettings.Clave) || jwtSettings.Clave.Length < 32)
{
    throw new InvalidOperationException(
        "La clave JWT de Reservas.Api debe tener al menos 32 caracteres. " +
        "Configúrela en appsettings.Development.json o en la variable Jwt__Clave.");
}

if (string.IsNullOrWhiteSpace(jwtSettings.Emisor) ||
    string.IsNullOrWhiteSpace(jwtSettings.Audiencia))
{
    throw new InvalidOperationException(
        "La configuración Jwt de Reservas.Api debe incluir emisor y audiencia.");
}

builder.Services.AddSingleton(jwtSettings);

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // Conserva los nombres originales de los claims: sub, email y rol.
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtSettings.Emisor,
            ValidateAudience = true,
            ValidAudience = jwtSettings.Audiencia,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtSettings.Clave)),
            ClockSkew = TimeSpan.Zero,
            NameClaimType = "sub",
            RoleClaimType = "rol"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// ------------------------------------------------------------
// Pipeline HTTP
// En local se usa HTTP; en la nube el proveedor termina TLS y
// reenvía la solicitud, por eso no se fuerza UseHttpsRedirection.
// ------------------------------------------------------------
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
