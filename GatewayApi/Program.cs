using System.Text;
using GatewayApi.Configuracion;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Ocelot.DependencyInjection;
using Ocelot.Middleware;

var builder = WebApplication.CreateBuilder(args);

// ------------------------------------------------------------
// ocelot.json: rutas, hosts de destino y BaseUrl del gateway.
// Se carga como una fuente más de configuración para que
// AddOcelot() la encuentre.
// ------------------------------------------------------------
builder.Configuration.AddJsonFile(
    "ocelot.json",
    optional: false,
    reloadOnChange: true);

// ------------------------------------------------------------
// Validación del JWT en el gateway
// Debe usar la misma clave, emisor y audiencia que la API S14
// y que el microservicio 2. El rol lo siguen exigiendo los
// servicios con [Authorize(Roles = ...)].
// ------------------------------------------------------------
var jwtSettings = builder.Configuration
    .GetSection("Jwt")
    .Get<JwtSettings>()
    ?? throw new InvalidOperationException(
        "Falta la sección Jwt en la configuración del gateway.");

if (string.IsNullOrWhiteSpace(jwtSettings.Clave) || jwtSettings.Clave.Length < 32)
{
    throw new InvalidOperationException(
        "La clave JWT del gateway debe tener al menos 32 caracteres. " +
        "Configúrela en appsettings.Development.json o en la variable Jwt__Clave.");
}

if (string.IsNullOrWhiteSpace(jwtSettings.Emisor) ||
    string.IsNullOrWhiteSpace(jwtSettings.Audiencia))
{
    throw new InvalidOperationException(
        "La configuración Jwt del gateway debe incluir emisor y audiencia.");
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

// Ocelot: el esquema "Bearer" registrado arriba es el que usan las
// rutas protegidas mediante AuthenticationOptions.AuthenticationProviderKey.
builder.Services.AddOcelot(builder.Configuration);

var app = builder.Build();

// ------------------------------------------------------------
// Pipeline HTTP: el gateway no expone endpoints propios.
// Todas las solicitudes pasan por Ocelot, que valida el token
// cuando la ruta lo exige y reenvía al microservicio destino.
// ------------------------------------------------------------
await app.UseOcelot();

app.Run();
