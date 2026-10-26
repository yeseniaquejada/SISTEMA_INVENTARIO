using CapaDatos;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Authorization;

var builder = WebApplication.CreateBuilder(args);

Conexion.Cadena = builder.Configuration.GetConnectionString("CadenaSQL")
    ?? throw new InvalidOperationException("Falta la cadena de conexión 'CadenaSQL' en appsettings.json");

builder.Services.AddControllersWithViews(opciones =>
{
    // Todas las páginas requieren iniciar sesión (salvo las marcadas con [AllowAnonymous])
    opciones.Filters.Add(new AuthorizeFilter(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build()));
    // Protección CSRF para todas las peticiones POST
    opciones.Filters.Add(new AutoValidateAntiforgeryTokenAttribute());
});

builder.Services.AddAntiforgery(o => o.HeaderName = "RequestVerificationToken");

// Las claves que cifran la sesión y los formularios se guardan en disco: en hosting compartido el sitio
// se reinicia seguido y, sin esto, cada reinicio cerraría la sesión de todos.
builder.Services.AddDataProtection()
    .SetApplicationName("InventarioComidas")
    .PersistKeysToFileSystem(new DirectoryInfo(
        builder.Configuration["ProteccionDatos:Carpeta"] ?? Path.Combine(builder.Environment.ContentRootPath, "App_Data", "claves")));

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.LoginPath = "/Acceso/Login";
        o.AccessDeniedPath = "/Acceso/Denegado";
        o.ExpireTimeSpan = TimeSpan.FromHours(10);
        o.SlidingExpiration = true;
    });

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.Use(async (context, next) => {
    Conexion.UsuarioAuditoria.Value = int.TryParse(context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var usuario) ? usuario : null;
    Conexion.SedeAuditoria.Value = int.TryParse(context.User.FindFirst("IdSede")?.Value, out var sede) ? sede : null;
    try { await next(); } finally { Conexion.UsuarioAuditoria.Value=null; Conexion.SedeAuditoria.Value=null; }
});

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
