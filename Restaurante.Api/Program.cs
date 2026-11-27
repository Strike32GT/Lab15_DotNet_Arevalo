using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Restaurante.Datos;
using Restaurante.Datos.Interfaces;
using Restaurante.Datos.Repositorios;
using Restaurante.Negocio.Configuracion;
using Restaurante.Negocio.Interfaces;
using Restaurante.Negocio.Mapeos;
using Restaurante.Negocio.Servicios;

var builder = WebApplication.CreateBuilder(args);

// ------------------------------------------------------------
// Servicios de la API
// ------------------------------------------------------------
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "API Restaurante",
        Version = "v1",
        Description = "Menú del restaurante protegido con autenticación JWT."
    });

    // Esquema Bearer para que Swagger muestre el botón Authorize.
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Escriba el token JWT. Swagger agrega el prefijo Bearer."
    });

    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = new List<string>()
    });
});

// ------------------------------------------------------------
// Entity Framework Core
// ------------------------------------------------------------
builder.Services.AddDbContext<RestauranteContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("RestauranteDB")));

// ------------------------------------------------------------
// Repositorios (capa de datos)
// ------------------------------------------------------------
builder.Services.AddScoped<ICategoriaRepositorio, CategoriaRepositorio>();
builder.Services.AddScoped<IPlatoRepositorio, PlatoRepositorio>();
builder.Services.AddScoped<IUsuarioRepositorio, UsuarioRepositorio>();

// ------------------------------------------------------------
// Servicios de negocio
// ------------------------------------------------------------
builder.Services.AddScoped<ICategoriaServicio, CategoriaServicio>();
builder.Services.AddScoped<IPlatoServicio, PlatoServicio>();
builder.Services.AddScoped<IAuthServicio, AuthServicio>();

// ------------------------------------------------------------
// Configuración del token JWT
// ------------------------------------------------------------
var jwtSettings = builder.Configuration
    .GetSection("Jwt")
    .Get<JwtSettings>()
    ?? throw new InvalidOperationException(
        "Falta la sección Jwt en la configuración de la aplicación.");

if (string.IsNullOrWhiteSpace(jwtSettings.Clave) || jwtSettings.Clave.Length < 32)
{
    throw new InvalidOperationException(
        "La clave JWT debe tener al menos 32 caracteres.");
}

if (string.IsNullOrWhiteSpace(jwtSettings.Emisor) ||
    string.IsNullOrWhiteSpace(jwtSettings.Audiencia) ||
    jwtSettings.MinutosVida <= 0)
{
    throw new InvalidOperationException(
        "La configuración Jwt debe incluir emisor, audiencia y minutos de vida.");
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

// ------------------------------------------------------------
// AutoMapper: un único perfil en la capa de Negocio
// ------------------------------------------------------------
builder.Services.AddAutoMapper(
    configuracion => { },
    typeof(MappingProfile).Assembly);

var app = builder.Build();

// ------------------------------------------------------------
// Pipeline HTTP
// ------------------------------------------------------------
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "API Restaurante v1");
        options.RoutePrefix = "swagger";
    });

    // En local se puede forzar HTTPS. En la nube el proveedor termina TLS y
    // reenvía HTTP al contenedor: redirigir aquí rompería las llamadas del gateway.
    app.UseHttpsRedirection();
}

// La autenticación se ejecuta antes de la autorización.
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
